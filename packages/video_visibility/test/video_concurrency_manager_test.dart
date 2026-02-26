import 'dart:math' as math;

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

    testWidgets('never exceeds maxActive under churn operations', (
      tester,
    ) async {
      const throttle = Duration(milliseconds: 1);
      final manager = VideoConcurrencyManager(
        maxActive: 3,
        visibleStart: 0.8,
        visibleStop: 0.2,
        recalcThrottle: throttle,
      );
      addTearDown(manager.dispose);

      final ids = List<String>.generate(12, (index) => 'video_$index');
      final registered = <String>{...ids.take(8)};
      for (final id in registered) {
        manager.register(id);
        manager.updateVisibility(id, 1.0);
      }
      await tester.pump(throttle);

      void assertInvariant() {
        final activeIds = ids.where(manager.isActive).toList(growable: false);
        expect(activeIds.length, manager.activeCount);
        expect(
          manager.activeCount <= manager.maxActive,
          isTrue,
          reason:
              'activeCount(${manager.activeCount}) > maxActive(${manager.maxActive})',
        );
        for (final id in activeIds) {
          expect(
            registered.contains(id),
            isTrue,
            reason: 'active id should remain registered: $id',
          );
        }
      }

      assertInvariant();
      final random = math.Random(42);
      for (var step = 0; step < 220; step++) {
        switch (random.nextInt(5)) {
          case 0:
            if (registered.isNotEmpty) {
              final id = registered.elementAt(random.nextInt(registered.length));
              manager.updateVisibility(id, random.nextDouble());
            }
            break;
          case 1:
            manager.setScrolling(random.nextBool());
            break;
          case 2:
            manager.maxActive = random.nextInt(7);
            break;
          case 3:
            final id = ids[random.nextInt(ids.length)];
            if (registered.contains(id)) {
              if (registered.length > 1 && random.nextBool()) {
                manager.unregister(id);
                registered.remove(id);
              } else {
                manager.updateVisibility(id, random.nextDouble());
              }
            } else {
              manager.register(id);
              registered.add(id);
              manager.updateVisibility(id, random.nextDouble());
            }
            break;
          case 4:
            if (registered.isNotEmpty) {
              for (var i = 0; i < 3; i++) {
                final id = registered.elementAt(random.nextInt(registered.length));
                manager.updateVisibility(id, random.nextDouble());
              }
            }
            break;
        }

        if (random.nextBool()) {
          await tester.pump(throttle);
        }
        assertInvariant();
      }

      await tester.pump(throttle);
      assertInvariant();
    });
  });
}
