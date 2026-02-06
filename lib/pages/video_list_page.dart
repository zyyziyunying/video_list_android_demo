import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/sample_videos.dart';
import '../managers/video_concurrency_manager.dart';
import '../models/video_item_data.dart';
import '../widgets/video_list_item.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  late final VideoConcurrencyManager _manager;
  final List<VideoItemData> _items = buildSampleVideos();
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    _manager = VideoConcurrencyManager(maxActive: 7);
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    _manager.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _scrollEndTimer?.cancel();
      _manager.setScrolling(true);
    } else if (notification is ScrollEndNotification) {
      _scrollEndTimer?.cancel();
      _scrollEndTimer = Timer(const Duration(milliseconds: 250), () {
        _manager.setScrolling(false);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video List (Concurrency Demo)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Max Active'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _manager.maxActive,
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('4')),
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 6, child: Text('6')),
                    DropdownMenuItem(value: 7, child: Text('7')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _manager.maxActive = value;
                      });
                    }
                  },
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _manager,
                  builder: (context, _) {
                    return Text('Active: ${_manager.activeCount}');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                itemCount: (_items.length / kVideosPerRow).ceil(),
                itemBuilder: (context, rowIndex) {
                  final startIndex = rowIndex * kVideosPerRow;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: List.generate(kVideosPerRow, (columnIndex) {
                        final itemIndex = startIndex + columnIndex;
                        if (itemIndex >= _items.length) {
                          return const Expanded(child: SizedBox.shrink());
                        }
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: VideoListItem(
                              data: _items[itemIndex],
                              manager: _manager,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
