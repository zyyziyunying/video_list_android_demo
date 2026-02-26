# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains app code: `pages/` (screens), `widgets/` (reusable UI), `data/` (mock/sample datasets), `models/` (typed entities), and `utils/` (helpers).
- `packages/video_visibility/` is a local package for visibility + concurrency scheduling (`lib/src/` contains managers and item wiring).
- `test/` contains app-level Flutter tests and bootstrap config (`flutter_test_config.dart` with leak tracking).
- `packages/video_visibility/test/` contains package-level manager behavior tests.
- `assets/videos/` stores local MP4 fixtures used by demo playback; Android host config is under `android/`.
- `download_covers.py` is a local helper script for cover-image downloads from mock data; output goes to ignored `cover_images/`.

## Build, Test, and Development Commands
- `fvm flutter pub get` - install dependencies with the pinned SDK (`.fvmrc`, Flutter 3.41.2).
- `fvm flutter run` - run the demo on a connected device or emulator.
- `fvm flutter analyze` - run static analysis (`flutter_lints`).
- `fvm dart format lib test packages/video_visibility/lib packages/video_visibility/test` - format Dart source and tests.
- `fvm flutter test test` - run app-level tests.
- `fvm flutter test packages/video_visibility/test` - run local package tests.
- `fvm flutter test test packages/video_visibility/test --coverage` - run coverage when touching scheduling/visibility logic.
- `python download_covers.py` - optional utility command for refreshing cover images.

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` (inherits `package:flutter_lints/flutter.yaml`).
- Use 2-space indentation and keep trailing commas where formatter output benefits.
- Naming: `UpperCamelCase` for classes/widgets, `lowerCamelCase` for members, `lower_snake_case.dart` for filenames.
- Keep UI state localized in widgets; move reusable visibility/playback coordination into `packages/video_visibility`.
- Prefer small, focused files/functions and keep public API surface in `packages/video_visibility/lib/video_visibility.dart`.

## Testing Guidelines
- Primary framework is `flutter_test`; leak checks are enabled via `leak_tracker_flutter_testing` in `test/flutter_test_config.dart`.
- Name tests as `*_test.dart` and colocate by feature area (app tests in `test/`, package tests in `packages/video_visibility/test/`).
- When changing playback scheduling, cover visibility thresholds, hysteresis behavior, scroll start/end transitions, and active-limit enforcement.
- Add/adjust tests in both app and package layers when behavior crosses module boundaries (UI wiring + manager policy).

## Commit & Pull Request Guidelines
- Use short, imperative commit subjects (example: `Fix visibility manager reattach and add README`).
- Keep commits focused; do not mix behavior changes with unrelated refactors or asset churn.
- Include test evidence in PRs (`fvm flutter analyze`, relevant `fvm flutter test ...` commands).
- For UI/video behavior updates, include a screenshot or screen recording and mention device/emulator context.
