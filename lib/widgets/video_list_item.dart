import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../constants.dart';
import 'package:video_visibility/video_visibility.dart';

import '../models/video_item_data.dart';
import 'state_pill.dart';

typedef VideoItemControllerFactory =
    VideoItemController Function(VideoItemData data);

abstract class VideoItemController {
  bool get isInitialized;
  bool get isPlaying;
  Size get size;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> setLooping(bool looping);
  Future<void> setVolume(double volume);
  Future<void> dispose();

  Widget buildView();
}

class VideoPlayerItemController implements VideoItemController {
  VideoPlayerItemController(VideoItemData data)
    : _controller = data.isAsset
          ? VideoPlayerController.asset(
              data.source,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            )
          : VideoPlayerController.networkUrl(
              Uri.parse(data.source),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );

  final VideoPlayerController _controller;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  Size get size => _controller.value.size;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> setLooping(bool looping) => _controller.setLooping(looping);

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Widget buildView() => VideoPlayer(_controller);
}

VideoItemController _defaultVideoItemControllerFactory(VideoItemData data) {
  return VideoPlayerItemController(data);
}

class VideoListItem extends StatefulWidget {
  const VideoListItem({
    super.key,
    required this.data,
    required this.manager,
    this.useManagedVisibility = true,
    this.controllerFactory,
  });

  final VideoItemData data;
  final VideoVisibilityManager manager;
  final bool useManagedVisibility;
  final VideoItemControllerFactory? controllerFactory;

  @override
  State<VideoListItem> createState() => VideoListItemState();
}

class VideoListItemState extends State<VideoListItem> {
  VideoItemController? _controller;
  Timer? _disposeTimer;
  bool _isActive = false;
  bool _isInitializing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _disposeTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onActiveChanged(bool isActive) {
    if (_isActive == isActive) return;
    _isActive = isActive;
    if (_isActive) {
      _disposeTimer?.cancel();
      _ensureController();
    } else {
      _pauseAndScheduleDispose();
    }
  }

  @visibleForTesting
  void debugSetActive(bool isActive) {
    _onActiveChanged(isActive);
  }

  @visibleForTesting
  bool get debugIsActive => _isActive;

  Future<void> _ensureController() async {
    if (_controller != null || _isInitializing) {
      if (_controller != null && !_controller!.isPlaying) {
        await _controller!.play();
      }
      return;
    }
    _isInitializing = true;
    _errorMessage = null;

    final controller =
        (widget.controllerFactory ?? _defaultVideoItemControllerFactory)(
          widget.data,
        );

    try {
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.initialize();
    } catch (error) {
      _errorMessage = 'Init failed';
      _isInitializing = false;
      await controller.dispose();
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    if (!_isActive) {
      _isInitializing = false;
      await controller.dispose();
      if (mounted) setState(() {});
      return;
    }

    _controller = controller;
    _isInitializing = false;
    await controller.play();
    if (mounted) setState(() {});
  }

  void _pauseAndScheduleDispose() {
    _controller?.pause();
    _disposeTimer?.cancel();
    _disposeTimer = Timer(const Duration(milliseconds: 800), () async {
      final controller = _controller;
      _controller = null;
      if (controller != null) {
        await controller.dispose();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.useManagedVisibility) {
      return _buildBody(_isActive);
    }

    return ManagedVisibilityItem(
      id: widget.data.id,
      manager: widget.manager,
      onActiveChanged: _onActiveChanged,
      builder: (context, isActive) => _buildBody(isActive),
    );
  }

  Widget _buildBody(bool isActive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: kVideoAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildVideoContent(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              widget.data.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            StatePill(
              label: isActive ? 'ACTIVE' : 'IDLE',
              color: isActive ? Colors.green : Colors.grey,
            ),
            if (_isInitializing) const Text('Loading...'),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoContent() {
    final controller = _controller;
    if (controller == null || !controller.isInitialized) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_outline, size: 48),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.size.width,
        height: controller.size.height,
        child: controller.buildView(),
      ),
    );
  }
}
