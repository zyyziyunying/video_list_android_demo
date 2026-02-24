# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains app code: `pages/` for screens, `widgets/` for reusable UI, `data/` for mock/sample datasets, `models/` for typed entities, and `utils/` for helpers.
- `packages/video_visibility/` is a local Dart package for visibility + concurrency control (`lib/src/` contains core manager logic).
- `test/` holds Flutter tests and global test bootstrap (`flutter_test_config.dart`).
- `assets/videos/` stores local MP4 fixtures used by the demo UI.
- `android/` contains the Android host app and Gradle config.

## Build, Test, and Development Commands
- `fvm flutter pub get` - install dependencies using the pinned SDK (`.fvmrc`, Flutter 3.41.2).
- `fvm flutter run` - run the demo on a connected device/emulator.
- `fvm flutter analyze` - run static analysis with `flutter_lints`.
- `fvm dart format lib test packages/video_visibility/lib` - format Dart sources.
- `fvm flutter test` - execute unit/widget tests.
- `fvm flutter test --coverage` - generate coverage when changing manager or playback logic.

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` (`package:flutter_lints/flutter.yaml`).
- Use 2-space indentation and keep trailing commas where they improve formatter output.
- Naming: `UpperCamelCase` for classes/widgets, `lowerCamelCase` for members, `lower_snake_case.dart` for files.
- Keep UI state localized in widgets; move reusable visibility/playback logic into `packages/video_visibility`.

## Testing Guidelines
- Primary framework: `flutter_test`; leak checks are enabled via `leak_tracker_flutter_testing` in `test/flutter_test_config.dart`.
- Name tests as `*_test.dart` and colocate by feature area (for example, manager behavior tests under `test/`).
- Add tests for visibility thresholds, scroll start/end transitions, and active-limit behavior when touching playback scheduling.

## Commit & Pull Request Guidelines
- Use short, imperative commit subjects (history examples: `Fix visibility manager reattach and add README`).
- Keep commits focused; avoid mixing refactors, assets, and behavior changes in one commit.
- PRs should include: change summary, test evidence (`fvm flutter analyze` and `fvm flutter test`), linked issue/task, and a screenshot or screen recording for UI/video behavior updates.
