import 'package:flutter/material.dart';

import 'pages/video_list_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoListApp());
}

class VideoListApp extends StatelessWidget {
  const VideoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video List Concurrency Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const VideoListPage(),
    );
  }
}
