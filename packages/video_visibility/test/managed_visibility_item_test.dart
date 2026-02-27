import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_visibility/video_visibility.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  late Duration originalVisibilityUpdateInterval;

  setUpAll(() {
    originalVisibilityUpdateInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalVisibilityUpdateInterval;
  });

  group('ManagedVisibilityItem', () {
    testWidgets('attaches on init and detaches on dispose', (tester) async {
      final manager = RecordingVideoVisibilityManager();
      addTearDown(manager.dispose);

      await tester.pumpWidget(_buildHarness(id: 'video_a', manager: manager));

      expect(manager.operations, <String>['attach:video_a']);
      expect(manager.addListenerCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(manager.operations, <String>['attach:video_a', 'detach:video_a']);
      expect(manager.removeListenerCalls, 1);
    });

    testWidgets('rebinds id on update and syncs active state', (tester) async {
      final manager = RecordingVideoVisibilityManager(
        seededActiveStates: <String, bool>{'video_b': true},
      );
      addTearDown(manager.dispose);
      final activeChanges = <bool>[];

      await tester.pumpWidget(
        _buildHarness(
          id: 'video_a',
          manager: manager,
          onActiveChanged: activeChanges.add,
        ),
      );
      expect(activeChanges, isEmpty);

      manager.resetOperations();
      await tester.pumpWidget(
        _buildHarness(
          id: 'video_b',
          manager: manager,
          onActiveChanged: activeChanges.add,
        ),
      );

      expect(manager.operations, <String>['detach:video_a', 'attach:video_b']);
      expect(activeChanges, <bool>[true]);
      expect(manager.addListenerCalls, 1);
      expect(manager.removeListenerCalls, 0);
    });

    testWidgets('rebinds manager on update', (tester) async {
      final oldManager = RecordingVideoVisibilityManager();
      final newManager = RecordingVideoVisibilityManager(
        seededActiveStates: <String, bool>{'video_a': true},
      );
      addTearDown(oldManager.dispose);
      addTearDown(newManager.dispose);
      final activeChanges = <bool>[];

      await tester.pumpWidget(
        _buildHarness(
          id: 'video_a',
          manager: oldManager,
          onActiveChanged: activeChanges.add,
        ),
      );

      await tester.pumpWidget(
        _buildHarness(
          id: 'video_a',
          manager: newManager,
          onActiveChanged: activeChanges.add,
        ),
      );

      expect(oldManager.operations, <String>[
        'attach:video_a',
        'detach:video_a',
      ]);
      expect(oldManager.addListenerCalls, 1);
      expect(oldManager.removeListenerCalls, 1);

      expect(newManager.operations, <String>['attach:video_a']);
      expect(newManager.addListenerCalls, 1);
      expect(newManager.removeListenerCalls, 0);

      expect(activeChanges, <bool>[true]);
    });

    testWidgets('forwards visibility changes to manager', (tester) async {
      final manager = RecordingVideoVisibilityManager();
      addTearDown(manager.dispose);

      await tester.pumpWidget(_buildHarness(id: 'video_a', manager: manager));

      final detector = tester.widget<VisibilityDetector>(
        find.byKey(const Key('managed-visibility-video_a')),
      );
      detector.onVisibilityChanged!(
        VisibilityInfo.fromRects(
          key: const Key('managed-visibility-video_a'),
          widgetBounds: const Rect.fromLTWH(0, 0, 100, 100),
          clipRect: const Rect.fromLTWH(0, 0, 50, 100),
        ),
      );

      expect(manager.visibilityUpdates, isNotEmpty);
      expect(manager.visibilityUpdates.last.$1, 'video_a');
      expect(manager.visibilityUpdates.last.$2, closeTo(0.5, 0.001));
    });

    testWidgets('onActiveChanged fires only when state changes', (
      tester,
    ) async {
      final manager = RecordingVideoVisibilityManager();
      addTearDown(manager.dispose);
      final activeChanges = <bool>[];

      await tester.pumpWidget(
        _buildHarness(
          id: 'video_a',
          manager: manager,
          onActiveChanged: activeChanges.add,
        ),
      );
      expect(activeChanges, isEmpty);

      manager.notifyChange();
      await tester.pump();
      expect(activeChanges, isEmpty);

      manager.setActive('video_a', true);
      await tester.pump();
      expect(activeChanges, <bool>[true]);

      manager.notifyChange();
      await tester.pump();
      expect(activeChanges, <bool>[true]);

      manager.setActive('video_a', true);
      await tester.pump();
      expect(activeChanges, <bool>[true]);

      manager.setActive('video_a', false);
      await tester.pump();
      expect(activeChanges, <bool>[true, false]);
    });
  });
}

Widget _buildHarness({
  required String id,
  required VideoVisibilityManager manager,
  ValueChanged<bool>? onActiveChanged,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ManagedVisibilityItem(
      id: id,
      manager: manager,
      onActiveChanged: onActiveChanged,
      builder: (context, isActive) => Text('active:$isActive'),
    ),
  );
}

class RecordingVideoVisibilityManager extends VideoVisibilityManager {
  RecordingVideoVisibilityManager({
    Map<String, bool> seededActiveStates = const <String, bool>{},
  }) : _activeStates = <String, bool>{...seededActiveStates},
       super(recalcThrottle: const Duration(milliseconds: 1));

  final Map<String, bool> _activeStates;

  final List<String> operations = <String>[];
  final List<(String, double)> visibilityUpdates = <(String, double)>[];
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }

  @override
  void attach(String id) {
    operations.add('attach:$id');
    _activeStates.putIfAbsent(id, () => false);
  }

  @override
  void detach(String id) {
    operations.add('detach:$id');
    _activeStates.remove(id);
  }

  @override
  void onVisibilityChanged(String id, double visibleFraction) {
    visibilityUpdates.add((id, visibleFraction));
  }

  @override
  bool isActive(String id) => _activeStates[id] ?? false;

  void resetOperations() {
    operations.clear();
  }

  void setActive(String id, bool isActive) {
    _activeStates[id] = isActive;
    notifyListeners();
  }

  void notifyChange() {
    notifyListeners();
  }
}
