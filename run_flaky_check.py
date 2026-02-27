#!/usr/bin/env python3
"""Repeat key flutter test suites to catch flaky/timing issues."""

from __future__ import annotations

import argparse
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass, field

DEFAULT_COMMANDS = (
    "fvm flutter test test",
    "fvm flutter test packages/video_visibility/test",
)


@dataclass
class CommandStats:
    command: str
    durations: list[float] = field(default_factory=list)
    passes: int = 0
    failures: int = 0

    def add(self, *, passed: bool, duration: float) -> None:
        self.durations.append(duration)
        if passed:
            self.passes += 1
        else:
            self.failures += 1

    @property
    def has_failure(self) -> bool:
        return self.failures > 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run one or more test commands repeatedly and summarize stability.",
    )
    parser.add_argument(
        "-n",
        "--iterations",
        type=int,
        default=10,
        help="How many times to run each command (default: 10).",
    )
    parser.add_argument(
        "--stop-on-failure",
        action="store_true",
        help="Stop immediately when a command fails.",
    )
    parser.add_argument(
        "commands",
        nargs="*",
        help="Commands to run. Defaults to the two key flutter test suites.",
    )
    args = parser.parse_args()
    if args.iterations <= 0:
        parser.error("--iterations must be greater than 0.")
    return args


def run_command(command: str) -> tuple[int, float]:
    started = time.perf_counter()
    completed = subprocess.run(command, shell=True)
    elapsed = time.perf_counter() - started
    return completed.returncode, elapsed


def print_summary(stats: list[CommandStats]) -> None:
    print("\n=== Flaky Check Summary ===")
    for item in stats:
        min_s = min(item.durations)
        max_s = max(item.durations)
        avg_s = statistics.mean(item.durations)
        print(f"- {item.command}")
        print(
            "  passes={passes} failures={failures} min={min_s:.2f}s "
            "max={max_s:.2f}s avg={avg_s:.2f}s".format(
                passes=item.passes,
                failures=item.failures,
                min_s=min_s,
                max_s=max_s,
                avg_s=avg_s,
            ),
        )


def main() -> int:
    args = parse_args()
    commands = tuple(args.commands) if args.commands else DEFAULT_COMMANDS
    stats = [CommandStats(command=command) for command in commands]

    overall_failed = False
    for index in range(1, args.iterations + 1):
        print(f"\n=== Iteration {index}/{args.iterations} ===")
        for command_stats in stats:
            print(f"\n$ {command_stats.command}")
            exit_code, elapsed = run_command(command_stats.command)
            passed = exit_code == 0
            command_stats.add(passed=passed, duration=elapsed)
            print(
                f"-> {'PASS' if passed else 'FAIL'} "
                f"(exit={exit_code}, {elapsed:.2f}s)",
            )
            if not passed:
                overall_failed = True
                if args.stop_on_failure:
                    print_summary(stats)
                    return 1

    print_summary(stats)
    if overall_failed:
        print("Detected flaky-check failures.")
        return 1
    print("All repeated runs passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
