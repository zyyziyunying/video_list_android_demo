import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/sample_videos.dart';
import 'package:video_visibility/video_visibility.dart';
import '../models/video_item_data.dart';
import '../widgets/video_list_item.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  late final VideoVisibilityManager _manager;
  final List<VideoItemData> _items = buildSampleVideos();

  @override
  void initState() {
    super.initState();
    _manager = VideoVisibilityManager(maxActive: 3);
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
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
                    DropdownMenuItem(value: 3, child: Text('3')),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const horizontalPadding = 8.0;
                const verticalPadding = 12.0;
                const crossAxisSpacing = 12.0;
                const mainAxisSpacing = 12.0;
                final itemWidth = constraints.maxWidth / 3;
                final itemHeight = itemWidth / kVideoAspectRatio + kItemFooterHeight;
                final childAspectRatio = itemWidth / itemHeight;
                final gridWidth = horizontalPadding * 2 +
                    crossAxisCount * itemWidth +
                    crossAxisSpacing * (crossAxisCount - 1);
                return NotificationListener<ScrollNotification>(
                  onNotification: _manager.createScrollListener(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(gridWidth, constraints.maxWidth),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          vertical: verticalPadding,
                          horizontal: horizontalPadding,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: crossAxisSpacing,
                          mainAxisSpacing: mainAxisSpacing,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          return VideoListItem(
                            data: _items[index],
                            manager: _manager,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
