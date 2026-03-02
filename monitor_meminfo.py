#!/usr/bin/env python3
"""Periodically collect `adb shell dumpsys meminfo` and emit analyzable reports."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import re
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

DEFAULT_PACKAGE = "com.example.video_list_android_demo"


@dataclass
class Sample:
    index: int
    timestamp: str
    total_pss_kb: int
    total_rss_kb: int
    total_swap_pss_kb: int
    java_heap_kb: int
    native_heap_kb: int
    graphics_kb: int


@dataclass
class LeakCheck:
    verdict: str
    reason: str
    pss_slope_overall_mb_per_min: float
    pss_slope_tail_mb_per_min: float
    rss_slope_overall_mb_per_min: float
    rss_slope_tail_mb_per_min: float
    pss_delta_mb: float
    rss_delta_mb: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Collect memory metrics from `adb shell dumpsys meminfo` at fixed intervals."
        ),
    )
    parser.add_argument(
        "-p",
        "--package",
        default=DEFAULT_PACKAGE,
        help=f"Android package name (default: {DEFAULT_PACKAGE}).",
    )
    parser.add_argument(
        "-i",
        "--interval",
        type=float,
        default=5.0,
        help="Sampling interval in seconds (default: 5).",
    )
    parser.add_argument(
        "-n",
        "--samples",
        type=int,
        default=120,
        help="Number of samples to collect (default: 120, set 0 to disable sample limit).",
    )
    parser.add_argument(
        "-d",
        "--duration",
        type=float,
        default=None,
        help="Optional total duration in seconds. Stops at whichever limit comes first.",
    )
    parser.add_argument(
        "-s",
        "--serial",
        default=None,
        help="Optional adb device serial (`adb -s <serial>`).",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        default="meminfo_reports",
        help="Directory used to store generated reports (default: meminfo_reports).",
    )
    parser.add_argument(
        "--pss-slope-threshold",
        type=float,
        default=1.5,
        help="Suspected leak threshold for PSS slope in MB/min (default: 1.5).",
    )
    parser.add_argument(
        "--rss-slope-threshold",
        type=float,
        default=2.0,
        help="Suspected leak threshold for RSS slope in MB/min (default: 2.0).",
    )
    parser.add_argument(
        "--min-delta-mb",
        type=float,
        default=25.0,
        help="Minimum last-first growth in MB before leak verdict (default: 25).",
    )
    parser.add_argument(
        "--min-samples-for-leak-check",
        type=int,
        default=12,
        help="Minimum samples required for leak trend check (default: 12).",
    )
    parser.add_argument(
        "--min-duration-min-for-leak-check",
        type=float,
        default=3.0,
        help="Minimum duration in minutes required for leak trend check (default: 3).",
    )
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("--interval must be greater than 0.")
    if args.samples < 0:
        parser.error("--samples cannot be negative.")
    if args.duration is not None and args.duration <= 0:
        parser.error("--duration must be greater than 0.")
    if args.samples == 0 and args.duration is None:
        parser.error("Set --samples > 0, --duration, or both.")
    if args.pss_slope_threshold < 0 or args.rss_slope_threshold < 0:
        parser.error("Slope thresholds cannot be negative.")
    if args.min_delta_mb < 0:
        parser.error("--min-delta-mb cannot be negative.")
    if args.min_samples_for_leak_check < 3:
        parser.error("--min-samples-for-leak-check must be >= 3.")
    if args.min_duration_min_for_leak_check <= 0:
        parser.error("--min-duration-min-for-leak-check must be greater than 0.")
    return args


def run_meminfo(package: str, serial: str | None) -> str:
    cmd = ["adb"]
    if serial:
        cmd.extend(["-s", serial])
    cmd.extend(["shell", "dumpsys", "meminfo", package])
    completed = subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        stderr = completed.stderr.strip()
        raise RuntimeError(f"adb command failed ({completed.returncode}): {stderr}")
    if "No process found for:" in completed.stdout:
        raise RuntimeError(
            "Target process is not running. Launch the app first, then retry.",
        )
    return completed.stdout


def find_kb(text: str, label: str) -> int:
    pattern = re.compile(rf"{re.escape(label)}:\s+(\d+)", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        raise ValueError(f"Could not find `{label}` in meminfo output.")
    return int(match.group(1))


def parse_sample(index: int, raw: str) -> Sample:
    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    return Sample(
        index=index,
        timestamp=timestamp,
        total_pss_kb=find_kb(raw, "TOTAL PSS"),
        total_rss_kb=find_kb(raw, "TOTAL RSS"),
        total_swap_pss_kb=find_kb(raw, "TOTAL SWAP PSS"),
        java_heap_kb=find_kb(raw, "Java Heap"),
        native_heap_kb=find_kb(raw, "Native Heap"),
        graphics_kb=find_kb(raw, "Graphics"),
    )


def kb_to_mb(kb: float) -> float:
    return kb / 1024.0


def linear_slope(x_values: list[float], y_values: list[float]) -> float:
    n = len(x_values)
    if n < 2:
        return 0.0
    sum_x = sum(x_values)
    sum_y = sum(y_values)
    sum_xy = sum(x * y for x, y in zip(x_values, y_values))
    sum_xx = sum(x * x for x in x_values)
    denominator = (n * sum_xx) - (sum_x * sum_x)
    if abs(denominator) < 1e-9:
        return 0.0
    return ((n * sum_xy) - (sum_x * sum_y)) / denominator


def build_leak_check(
    samples: list[Sample],
    elapsed_sec: float,
    *,
    interval_sec: float,
    pss_slope_threshold: float,
    rss_slope_threshold: float,
    min_delta_mb: float,
    min_samples_for_leak_check: int,
    min_duration_min_for_leak_check: float,
) -> LeakCheck:
    first = samples[0]
    last = samples[-1]
    pss_delta_mb = kb_to_mb(last.total_pss_kb - first.total_pss_kb)
    rss_delta_mb = kb_to_mb(last.total_rss_kb - first.total_rss_kb)

    if len(samples) < 2:
        return LeakCheck(
            verdict="insufficient_data",
            reason="Need longer sampling window.",
            pss_slope_overall_mb_per_min=0.0,
            pss_slope_tail_mb_per_min=0.0,
            rss_slope_overall_mb_per_min=0.0,
            rss_slope_tail_mb_per_min=0.0,
            pss_delta_mb=pss_delta_mb,
            rss_delta_mb=rss_delta_mb,
        )

    if elapsed_sec > 0 and len(samples) > 1:
        step_min = (elapsed_sec / (len(samples) - 1)) / 60.0
    else:
        step_min = interval_sec / 60.0
    if step_min <= 0:
        step_min = interval_sec / 60.0

    x_minutes = [index * step_min for index in range(len(samples))]
    pss_mb = [kb_to_mb(item.total_pss_kb) for item in samples]
    rss_mb = [kb_to_mb(item.total_rss_kb) for item in samples]
    pss_slope_overall = linear_slope(x_minutes, pss_mb)
    rss_slope_overall = linear_slope(x_minutes, rss_mb)

    tail_count = max((len(samples) + 1) // 2, 6)
    tail_count = min(tail_count, len(samples))
    x_tail = [index * step_min for index in range(tail_count)]
    pss_tail = pss_mb[-tail_count:]
    rss_tail = rss_mb[-tail_count:]
    pss_slope_tail = linear_slope(x_tail, pss_tail)
    rss_slope_tail = linear_slope(x_tail, rss_tail)

    total_duration_min = elapsed_sec / 60.0
    if (
        len(samples) < min_samples_for_leak_check
        or total_duration_min < min_duration_min_for_leak_check
    ):
        return LeakCheck(
            verdict="insufficient_data",
            reason="Increase samples or duration for reliable trend detection.",
            pss_slope_overall_mb_per_min=pss_slope_overall,
            pss_slope_tail_mb_per_min=pss_slope_tail,
            rss_slope_overall_mb_per_min=rss_slope_overall,
            rss_slope_tail_mb_per_min=rss_slope_tail,
            pss_delta_mb=pss_delta_mb,
            rss_delta_mb=rss_delta_mb,
        )

    pss_rising = (
        pss_slope_overall >= pss_slope_threshold
        and pss_slope_tail >= pss_slope_threshold * 0.8
        and pss_delta_mb >= min_delta_mb
    )
    rss_rising = (
        rss_slope_overall >= rss_slope_threshold
        and rss_slope_tail >= rss_slope_threshold * 0.8
        and rss_delta_mb >= min_delta_mb
    )
    if pss_rising or rss_rising:
        verdict = "suspected_leak"
        reason = "Slope and delta both exceed thresholds."
    else:
        verdict = "no_clear_leak"
        reason = "No sustained upward trend above configured thresholds."

    return LeakCheck(
        verdict=verdict,
        reason=reason,
        pss_slope_overall_mb_per_min=pss_slope_overall,
        pss_slope_tail_mb_per_min=pss_slope_tail,
        rss_slope_overall_mb_per_min=rss_slope_overall,
        rss_slope_tail_mb_per_min=rss_slope_tail,
        pss_delta_mb=pss_delta_mb,
        rss_delta_mb=rss_delta_mb,
    )


def write_summary(
    report_dir: Path,
    package: str,
    samples: list[Sample],
    elapsed_sec: float,
    leak_check: LeakCheck,
    *,
    pss_slope_threshold: float,
    rss_slope_threshold: float,
    min_delta_mb: float,
    min_samples_for_leak_check: int,
    min_duration_min_for_leak_check: float,
) -> None:
    pss_values = [item.total_pss_kb for item in samples]
    rss_values = [item.total_rss_kb for item in samples]
    graphics_values = [item.graphics_kb for item in samples]
    swap_values = [item.total_swap_pss_kb for item in samples]

    def stats_line(name: str, values: list[int]) -> str:
        return (
            f"{name} (MB): min={kb_to_mb(min(values)):.1f}, "
            f"avg={kb_to_mb(statistics.mean(values)):.1f}, "
            f"max={kb_to_mb(max(values)):.1f}"
        )

    lines = [
        "Memory Sampling Summary",
        f"package: {package}",
        f"samples: {len(samples)}",
        f"elapsed_sec: {elapsed_sec:.1f}",
        stats_line("TOTAL PSS", pss_values),
        stats_line("TOTAL RSS", rss_values),
        stats_line("Graphics", graphics_values),
        stats_line("TOTAL SWAP PSS", swap_values),
        f"PSS delta (last-first): {leak_check.pss_delta_mb:.1f} MB",
        f"RSS delta (last-first): {leak_check.rss_delta_mb:.1f} MB",
        "",
        "Leak Check",
        f"verdict: {leak_check.verdict}",
        f"reason: {leak_check.reason}",
        (
            "config: pss_slope>={pss}MB/min rss_slope>={rss}MB/min "
            "min_delta>={delta}MB min_samples>={samples} min_duration>={duration}min"
        ).format(
            pss=pss_slope_threshold,
            rss=rss_slope_threshold,
            delta=min_delta_mb,
            samples=min_samples_for_leak_check,
            duration=min_duration_min_for_leak_check,
        ),
        f"PSS slope overall: {leak_check.pss_slope_overall_mb_per_min:.2f} MB/min",
        f"PSS slope tail: {leak_check.pss_slope_tail_mb_per_min:.2f} MB/min",
        f"RSS slope overall: {leak_check.rss_slope_overall_mb_per_min:.2f} MB/min",
        f"RSS slope tail: {leak_check.rss_slope_tail_mb_per_min:.2f} MB/min",
    ]
    (report_dir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    session_name = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    report_dir = Path(args.output_dir) / f"{args.package}_{session_name}"
    report_dir.mkdir(parents=True, exist_ok=True)

    csv_path = report_dir / "metrics.csv"
    raw_log_path = report_dir / "raw_meminfo.log"

    samples: list[Sample] = []
    started = time.monotonic()

    with csv_path.open("w", newline="", encoding="utf-8") as csv_file, raw_log_path.open(
        "w",
        encoding="utf-8",
    ) as raw_log:
        writer = csv.writer(csv_file)
        writer.writerow(
            [
                "index",
                "timestamp",
                "total_pss_kb",
                "total_rss_kb",
                "total_swap_pss_kb",
                "java_heap_kb",
                "native_heap_kb",
                "graphics_kb",
            ],
        )

        index = 1
        try:
            while True:
                elapsed = time.monotonic() - started
                if args.duration is not None and elapsed > args.duration:
                    break
                if args.samples > 0 and index > args.samples:
                    break

                try:
                    raw = run_meminfo(args.package, args.serial)
                    sample = parse_sample(index, raw)
                except Exception as exc:  # noqa: BLE001
                    print(f"[{index}] collect failed: {exc}", file=sys.stderr)
                    return 1

                samples.append(sample)
                writer.writerow(
                    [
                        sample.index,
                        sample.timestamp,
                        sample.total_pss_kb,
                        sample.total_rss_kb,
                        sample.total_swap_pss_kb,
                        sample.java_heap_kb,
                        sample.native_heap_kb,
                        sample.graphics_kb,
                    ],
                )
                csv_file.flush()

                raw_log.write(f"===== sample {sample.index} @ {sample.timestamp} =====\n")
                raw_log.write(raw.rstrip() + "\n\n")
                raw_log.flush()

                print(
                    f"[{sample.index:03d}] {sample.timestamp} "
                    f"PSS={kb_to_mb(sample.total_pss_kb):6.1f}MB "
                    f"RSS={kb_to_mb(sample.total_rss_kb):6.1f}MB "
                    f"GFX={kb_to_mb(sample.graphics_kb):6.1f}MB "
                    f"SWAP={kb_to_mb(sample.total_swap_pss_kb):5.1f}MB",
                )

                index += 1
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nInterrupted by user. Finalizing reports...")

    if not samples:
        print("No samples were collected.", file=sys.stderr)
        return 1

    elapsed = time.monotonic() - started
    leak_check = build_leak_check(
        samples,
        elapsed,
        interval_sec=args.interval,
        pss_slope_threshold=args.pss_slope_threshold,
        rss_slope_threshold=args.rss_slope_threshold,
        min_delta_mb=args.min_delta_mb,
        min_samples_for_leak_check=args.min_samples_for_leak_check,
        min_duration_min_for_leak_check=args.min_duration_min_for_leak_check,
    )
    write_summary(
        report_dir,
        args.package,
        samples,
        elapsed,
        leak_check,
        pss_slope_threshold=args.pss_slope_threshold,
        rss_slope_threshold=args.rss_slope_threshold,
        min_delta_mb=args.min_delta_mb,
        min_samples_for_leak_check=args.min_samples_for_leak_check,
        min_duration_min_for_leak_check=args.min_duration_min_for_leak_check,
    )
    print(f"\nDone. Report directory: {report_dir}")
    print(f"- metrics: {csv_path}")
    print(f"- raw logs: {raw_log_path}")
    print(f"- summary: {report_dir / 'summary.txt'}")
    print(f"- leak verdict: {leak_check.verdict}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
