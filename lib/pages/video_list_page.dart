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
  late final List<List<VideoItemData>> _rows;

  @override
  void initState() {
    super.initState();
    _manager = VideoVisibilityManager(maxActive: 3);
    _rows = _buildRows();
  }

  List<List<VideoItemData>> _buildRows() {
    final random = math.Random(42);
    final rows = <List<VideoItemData>>[];
    int index = 0;
    while (index < _items.length) {
      final rowCount = 5 + random.nextInt(6); // 5-10 items per row
      final end = math.min(index + rowCount, _items.length);
      rows.add(_items.sublist(index, end));
      index = end;
    }
    return rows;
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
                const horizontalPadding = 8.0;
                const itemSpacing = 12.0;
                final itemWidth = constraints.maxWidth / 3;
                final itemHeight =
                    itemWidth / kVideoAspectRatio + kItemFooterHeight;
                return NotificationListener<ScrollNotification>(
                  onNotification: _manager.createScrollListener(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    itemCount: _rows.length,
                    itemBuilder: (context, rowIndex) {
                      final rowItems = _rows[rowIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: SizedBox(
                          height: itemHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            itemCount: rowItems.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index < rowItems.length - 1
                                      ? itemSpacing
                                      : 0,
                                ),
                                child: SizedBox(
                                  width: itemWidth,
                                  child: VideoListItem(
                                    data: rowItems[index],
                                    manager: _manager,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
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
