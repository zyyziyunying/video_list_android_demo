import 'package:flutter_test/flutter_test.dart';
import 'package:video_visibility/src/video_concurrency_manager.dart';

void main() {
  group('VideoConcurrencyManager', () {
    testWidgets('applies visibleStart/visibleStop hysteresis', (tester) async {
      const throttle = Duration(milliseconds: 1);
      final manager = VideoConcurrencyManager(
        maxActive: 1,
        visibleStart: 0.8,
        visibleStop: 0.2,
        recalcThrottle: throttle,
      );
      addTearDown(manager.dispose);

      manager.register('video_a');
      manager.updateVisibility('video_a', 0.79);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isFalse);

      manager.updateVisibility('video_a', 0.8);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isTrue);

      manager.updateVisibility('video_a', 0.21);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isTrue);

      manager.updateVisibility('video_a', 0.19);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isFalse);
    });

    testWidgets('replaces active slot when current active drops out', (
      tester,
    ) async {
      const throttle = Duration(milliseconds: 1);
      final manager = VideoConcurrencyManager(
        maxActive: 1,
        visibleStart: 0.8,
        visibleStop: 0.2,
        recalcThrottle: throttle,
      );
      addTearDown(manager.dispose);

      manager.register('video_a');
      manager.register('video_b');
      manager.updateVisibility('video_a', 1.0);
      manager.updateVisibility('video_b', 0.95);
      await tester.pump(throttle);

      expect(manager.isActive('video_a'), isTrue);
      expect(manager.isActive('video_b'), isFalse);

      manager.updateVisibility('video_a', 0.19);
      await tester.pump(throttle);

      expect(manager.isActive('video_a'), isFalse);
      expect(manager.isActive('video_b'), isTrue);
    });

    testWidgets('handles maxActive boundary values and runtime changes', (
      tester,
    ) async {
      const throttle = Duration(milliseconds: 1);
      final manager = VideoConcurrencyManager(
        maxActive: 0,
        visibleStart: 0.8,
        visibleStop: 0.2,
        recalcThrottle: throttle,
      );
      addTearDown(manager.dispose);

      manager.register('video_a');
      manager.register('video_b');
      manager.register('video_c');
      manager.updateVisibility('video_a', 1.0);
      manager.updateVisibility('video_b', 0.9);
      manager.updateVisibility('video_c', 0.85);
      await tester.pump(throttle);

      expect(manager.activeCount, 0);

      manager.maxActive = 1;
      expect(manager.activeCount, 1);
      expect(manager.isActive('video_a'), isTrue);
      expect(manager.isActive('video_b'), isFalse);

      manager.maxActive = 2;
      expect(manager.activeCount, 2);
      expect(manager.isActive('video_a'), isTrue);
      expect(manager.isActive('video_b'), isTrue);
      expect(manager.isActive('video_c'), isFalse);
    });
  });
}
