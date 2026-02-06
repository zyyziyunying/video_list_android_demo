import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../constants.dart';
import 'package:video_visibility/video_visibility.dart';

import '../models/video_item_data.dart';
import 'state_pill.dart';

class VideoListItem extends StatefulWidget {
  const VideoListItem({
    super.key,
    required this.data,
    required this.manager,
  });

  final VideoItemData data;
  final VideoVisibilityManager manager;

  @override
  State<VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends State<VideoListItem> {
  VideoPlayerController? _controller;
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

  Future<void> _ensureController() async {
    if (_controller != null || _isInitializing) {
      if (_controller != null && !_controller!.value.isPlaying) {
        await _controller!.play();
      }
      return;
    }
    _isInitializing = true;
    _errorMessage = null;

    final controller = widget.data.isAsset
        ? VideoPlayerController.asset(
            widget.data.source,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(widget.data.source),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
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
    return ManagedVisibilityItem(
      id: widget.data.id,
      manager: widget.manager,
      onActiveChanged: _onActiveChanged,
      builder: (context, isActive) {
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
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoContent() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_outline, size: 48),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
