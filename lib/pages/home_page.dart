import 'package:flutter/material.dart';

import '../utils/logger.dart';
import 'video_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<String> _tabLabels = const ['视频列表', '页面A', '页面B'];

  void _onTabChanged(int index) {
    Log.info('切换到 tab: ${_tabLabels[index]} (index=$index)', tag: 'HomePage');
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const VideoListPage(),
          _buildPlaceholder('页面 A'),
          _buildPlaceholder('页面 B'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: '视频列表',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: '页面A',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '页面B',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}
