import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_visibility/video_visibility.dart';

void main() {
  group('VideoVisibilityManager', () {
    const throttle = Duration(milliseconds: 1);
    const endDelay = Duration(milliseconds: 50);
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 100,
      pixels: 10,
      viewportDimension: 50,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    Future<BuildContext> pumpContext(WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );
      return tester.element(find.byType(SizedBox));
    }

    testWidgets('switches scrolling state and honors scrolling threshold', (
      tester,
    ) async {
      final context = await pumpContext(tester);

      final manager = VideoVisibilityManager(
        maxActive: 1,
        visibleStart: 0.8,
        visibleStop: 0.2,
        recalcThrottle: throttle,
        scrollEndDelay: endDelay,
      );
      addTearDown(manager.dispose);

      manager.attach('video_a');
      manager.onVisibilityChanged('video_a', 0.9);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isTrue);

      final onScroll = manager.createScrollListener();
      onScroll(ScrollStartNotification(metrics: metrics, context: context));
      expect(manager.isScrolling, isTrue);
      expect(manager.isActive('video_a'), isFalse);

      manager.onVisibilityChanged('video_a', 1.0);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isTrue);

      onScroll(ScrollEndNotification(metrics: metrics, context: context));
      await tester.pump(const Duration(milliseconds: 49));
      expect(manager.isScrolling, isTrue);

      await tester.pump(const Duration(milliseconds: 1));
      expect(manager.isScrolling, isFalse);
      expect(manager.isActive('video_a'), isTrue);
    });

    testWidgets('primaryOnly strategy ignores nested scroll notifications', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final manager = VideoVisibilityManager(
        maxActive: 1,
        recalcThrottle: throttle,
        scrollEndDelay: endDelay,
      );
      addTearDown(manager.dispose);

      manager.attach('video_a');
      manager.onVisibilityChanged('video_a', 0.9);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isTrue);

      final onScroll = manager.createScrollListener();
      onScroll(
        _DepthAwareScrollStartNotification(
          depthValue: 1,
          metrics: metrics,
          context: context,
        ),
      );
      await tester.pump();

      expect(manager.isScrolling, isFalse);
      expect(manager.isActive('video_a'), isTrue);
    });

    testWidgets('all strategy handles nested scroll notifications', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final manager = VideoVisibilityManager(
        maxActive: 1,
        recalcThrottle: throttle,
        scrollEndDelay: endDelay,
        scrollNotificationStrategy: ScrollNotificationStrategy.all,
      );
      addTearDown(manager.dispose);

      manager.attach('video_a');
      manager.onVisibilityChanged('video_a', 0.9);
      await tester.pump(throttle);
      expect(manager.isActive('video_a'), isTrue);

      final onScroll = manager.createScrollListener();
      onScroll(
        _DepthAwareScrollStartNotification(
          depthValue: 1,
          metrics: metrics,
          context: context,
        ),
      );
      expect(manager.isScrolling, isTrue);
      expect(manager.isActive('video_a'), isFalse);

      onScroll(
        _DepthAwareScrollEndNotification(
          depthValue: 1,
          metrics: metrics,
          context: context,
        ),
      );
      await tester.pump(const Duration(milliseconds: 49));
      expect(manager.isScrolling, isTrue);

      await tester.pump(const Duration(milliseconds: 1));
      expect(manager.isScrolling, isFalse);
    });
  });
}

class _DepthAwareScrollStartNotification extends ScrollStartNotification {
  _DepthAwareScrollStartNotification({
    required this.depthValue,
    required super.metrics,
    required super.context,
  });

  final int depthValue;

  @override
  int get depth => depthValue;
}

class _DepthAwareScrollEndNotification extends ScrollEndNotification {
  _DepthAwareScrollEndNotification({
    required this.depthValue,
    required super.metrics,
    required super.context,
  });

  final int depthValue;

  @override
  int get depth => depthValue;
}
