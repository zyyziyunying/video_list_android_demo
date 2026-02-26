import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:video_list_android_demo/models/video_item_data.dart';
import 'package:video_list_android_demo/widgets/video_list_item.dart';
import 'package:video_visibility/video_visibility.dart';

void main() {
  group('VideoListItem controller lifecycle', () {
    const disposeDelay = Duration(milliseconds: 800);

    late VideoVisibilityManager manager;
    late GlobalKey<VideoListItemState> itemKey;
    late FakeVideoItemControllerFactory controllerFactory;

    const data = VideoItemData(
      id: 'video_test',
      title: 'Video Test',
      source: 'assets/videos/video_01.mp4',
      isAsset: true,
    );

    Future<void> pumpItem(WidgetTester tester) async {
      itemKey = GlobalKey<VideoListItemState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                child: VideoListItem(
                  key: itemKey,
                  data: data,
                  manager: manager,
                  useManagedVisibility: false,
                  controllerFactory: controllerFactory.create,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> setActive(WidgetTester tester, bool isActive) async {
      final state = itemKey.currentState!;
      state.debugSetActive(isActive);
      expect(state.debugIsActive, isActive);
      await tester.pump();
    }

    Future<void> removeItem(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    setUp(() {
      manager = VideoVisibilityManager(maxActive: 1);
      controllerFactory = FakeVideoItemControllerFactory();
    });

    tearDown(() {
      manager.dispose();
    });

    testWidgets(
      'disposes controller after inactive grace period',
      (tester) async {
        await pumpItem(tester);

        await setActive(tester, true);
        expect(controllerFactory.createdCount, 1);
        final controller = controllerFactory.lastCreated;
        expect(controller.isInitialized, isTrue);
        expect(controller.isPlaying, isTrue);

        await setActive(tester, false);
        expect(controller.pauseCallCount, greaterThan(0));

        await tester.pump(const Duration(milliseconds: 799));
        expect(controller.disposeCallCount, 0);

        await tester.pump(const Duration(milliseconds: 1));
        expect(controller.disposeCallCount, 1);
        expect(controller.isDisposed, isTrue);

        await removeItem(tester);
      },
      experimentalLeakTesting: LeakTesting.settings,
    );

    testWidgets(
      'reactivation before grace period cancels delayed dispose',
      (tester) async {
        await pumpItem(tester);

        await setActive(tester, true);
        expect(controllerFactory.createdCount, 1);
        final controller = controllerFactory.lastCreated;

        await setActive(tester, false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.disposeCallCount, 0);

        await setActive(tester, true);
        expect(controllerFactory.createdCount, 1);

        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.disposeCallCount, 0);
        expect(controller.isPlaying, isTrue);

        await removeItem(tester);
        expect(controller.disposeCallCount, 1);
      },
      experimentalLeakTesting: LeakTesting.settings,
    );

    testWidgets(
      'disposing widget clears live controller immediately',
      (tester) async {
        await pumpItem(tester);

        await setActive(tester, true);
        final controller = controllerFactory.lastCreated;
        expect(controller.isPlaying, isTrue);

        await setActive(tester, false);
        await tester.pump(const Duration(milliseconds: 200));
        expect(controller.disposeCallCount, 0);

        await removeItem(tester);
        expect(controller.disposeCallCount, 1);

        await tester.pump(disposeDelay + const Duration(milliseconds: 50));
        expect(controller.disposeCallCount, 1);
      },
      experimentalLeakTesting: LeakTesting.settings,
    );
  });
}

class FakeVideoItemControllerFactory {
  int createdCount = 0;
  final List<FakeVideoItemController> controllers = <FakeVideoItemController>[];

  FakeVideoItemController create(VideoItemData data) {
    createdCount++;
    final controller = FakeVideoItemController();
    controllers.add(controller);
    return controller;
  }

  FakeVideoItemController get lastCreated => controllers.last;
}

class FakeVideoItemController implements VideoItemController {
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool isDisposed = false;

  int playCallCount = 0;
  int pauseCallCount = 0;
  int disposeCallCount = 0;

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
    playCallCount++;
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
    _isPlaying = false;
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    isDisposed = true;
    _isPlaying = false;
  }

  @override
  Widget buildView() => const SizedBox.shrink();
}
