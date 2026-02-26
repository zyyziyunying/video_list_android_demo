import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:video_list_android_demo/models/video_item_data.dart';
import 'package:video_list_android_demo/widgets/video_list_item.dart';
import 'package:video_visibility/video_visibility.dart';

void main() {
  group('App-level concurrency churn', () {
    const throttle = Duration(milliseconds: 1);
    const scrollEndDelay = Duration(milliseconds: 10);

    final allItems = List<VideoItemData>.generate(
      12,
      (index) => VideoItemData(
        id: 'video_$index',
        title: 'Video $index',
        source: 'assets/videos/video_01.mp4',
        isAsset: true,
      ),
      growable: false,
    );
    final allIds = allItems.map((item) => item.id).toList(growable: false);

    late VideoVisibilityManager manager;
    late FakeVideoItemControllerFactory controllerFactory;
    late Map<String, GlobalKey<VideoListItemState>> itemKeys;

    Future<void> pumpHarness(
      WidgetTester tester,
      Set<String> mountedIds,
    ) async {
      final visibleItems = allItems
          .where((item) => mountedIds.contains(item.id))
          .toList(growable: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in visibleItems)
                  SizedBox(
                    width: 120,
                    child: VideoListItem(
                      key: itemKeys[item.id],
                      data: item,
                      manager: manager,
                      controllerFactory: controllerFactory.create,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    void assertInvariants(Set<String> mountedIds) {
      final activeIds = allIds.where(manager.isActive).toList(growable: false);
      expect(activeIds.length, manager.activeCount);
      expect(
        manager.activeCount <= manager.maxActive,
        isTrue,
        reason:
            'activeCount(${manager.activeCount}) > maxActive(${manager.maxActive})',
      );
      for (final id in activeIds) {
        expect(
          mountedIds.contains(id),
          isTrue,
          reason: 'active item must stay mounted: $id',
        );
      }

      final playingCount = controllerFactory.playingCount;
      expect(
        playingCount <= manager.maxActive,
        isTrue,
        reason: 'playingCount($playingCount) > maxActive(${manager.maxActive})',
      );

      for (final id in mountedIds) {
        final state = itemKeys[id]?.currentState;
        expect(state, isNotNull, reason: 'state should be mounted: $id');
        expect(state!.debugIsActive, manager.isActive(id));
      }
      for (final id in allIds.where((id) => !mountedIds.contains(id))) {
        expect(itemKeys[id]?.currentState, isNull);
      }
    }

    setUp(() {
      manager = VideoVisibilityManager(
        maxActive: 3,
        visibleStart: 0.8,
        visibleStop: 0.2,
        recalcThrottle: throttle,
        scrollEndDelay: scrollEndDelay,
        scrollNotificationStrategy: ScrollNotificationStrategy.all,
      );
      controllerFactory = FakeVideoItemControllerFactory();
      itemKeys = {
        for (final item in allItems) item.id: GlobalKey<VideoListItemState>(),
      };
    });

    tearDown(() {
      manager.dispose();
    });

    testWidgets(
      'never exceeds maxActive under app wiring churn',
      (tester) async {
        final random = math.Random(7);
        final mountedIds = <String>{...allIds.take(8)};
        await pumpHarness(tester, mountedIds);

        for (final id in mountedIds) {
          manager.onVisibilityChanged(id, 1.0);
        }
        await tester.pump(throttle);
        assertInvariants(mountedIds);

        final onScroll = manager.createScrollListener();
        final context = tester.element(find.byType(Scaffold));
        final metrics = FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 100,
          pixels: 10,
          viewportDimension: 50,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        );

        for (var step = 0; step < 220; step++) {
          switch (random.nextInt(7)) {
            case 0:
              if (mountedIds.isNotEmpty) {
                final id = mountedIds.elementAt(
                  random.nextInt(mountedIds.length),
                );
                manager.onVisibilityChanged(id, random.nextDouble());
              }
              break;
            case 1:
              manager.maxActive = 1 + random.nextInt(6);
              break;
            case 2:
              onScroll(
                ScrollStartNotification(metrics: metrics, context: context),
              );
              break;
            case 3:
              onScroll(
                ScrollEndNotification(metrics: metrics, context: context),
              );
              break;
            case 4:
              final id = allIds[random.nextInt(allIds.length)];
              if (mountedIds.contains(id)) {
                if (mountedIds.length > 2 && random.nextBool()) {
                  mountedIds.remove(id);
                  await pumpHarness(tester, mountedIds);
                } else {
                  manager.onVisibilityChanged(id, random.nextDouble());
                }
              } else {
                mountedIds.add(id);
                await pumpHarness(tester, mountedIds);
                manager.onVisibilityChanged(id, random.nextDouble());
              }
              break;
            case 5:
              if (mountedIds.isNotEmpty) {
                for (var i = 0; i < 3; i++) {
                  final id = mountedIds.elementAt(
                    random.nextInt(mountedIds.length),
                  );
                  manager.onVisibilityChanged(id, random.nextDouble());
                }
              }
              break;
            case 6:
              if (mountedIds.isNotEmpty) {
                for (final id in mountedIds.take(2)) {
                  manager.onVisibilityChanged(id, 1.0);
                }
              }
              break;
          }

          await tester.pump(throttle);
          assertInvariants(mountedIds);
        }

        await tester.pump(scrollEndDelay + throttle);
        assertInvariants(mountedIds);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        notDisposed: {'ContainerLayer': null},
      ),
    );
  });
}

class FakeVideoItemControllerFactory {
  final List<FakeVideoItemController> controllers = <FakeVideoItemController>[];

  FakeVideoItemController create(VideoItemData data) {
    final controller = FakeVideoItemController();
    controllers.add(controller);
    return controller;
  }

  int get playingCount =>
      controllers.where((controller) => controller.isPlaying).length;
}

class FakeVideoItemController implements VideoItemController {
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Size get size => const Size(320, 180);

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    _isPlaying = false;
  }

  @override
  Widget buildView() => const SizedBox.shrink();
}
