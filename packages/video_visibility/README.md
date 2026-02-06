# video_visibility

A Flutter helper package for managing video visibility and concurrency in
scrolling lists. It wraps `visibility_detector` and provides a higher-level
manager that decides which items should be active based on visibility,
scrolling state, and a max active limit.

## Features
- Track per-item visibility and active state.
- Limit concurrent active videos (`maxActive`).
- Smooth behavior during scroll with throttled recalculation.

## Installation
Add to your `pubspec.yaml`:

```yaml
dependencies:
  video_visibility:
    path: packages/video_visibility
```

## Usage

```dart
final manager = VideoVisibilityManager(maxActive: 2);

NotificationListener<ScrollNotification>(
  onNotification: manager.createScrollListener(),
  child: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final id = 'video_$index';
      return ManagedVisibilityItem(
        id: id,
        manager: manager,
        onActiveChanged: (isActive) {
          // Start/stop video based on isActive.
        },
        builder: (context, isActive) {
          return isActive ? VideoPlayer(...) : Placeholder();
        },
      );
    },
  ),
);
```

## API
- `VideoVisibilityManager`: Core manager.
  - `maxActive`, `activeCount`, `createScrollListener()`,
    `onVisibilityChanged()`, `isActive()`
- `ManagedVisibilityItem`: Widget that wires a list item to the manager.

## Notes
- Each item must have a stable, unique `id`.
- If you swap `manager` or `id` for a `ManagedVisibilityItem`, it will
  re-attach automatically.
