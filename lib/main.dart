import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';

import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _enableLeakTrackingIfNeeded();
  runApp(const VideoListApp());
}

void _enableLeakTrackingIfNeeded() {
  if (kReleaseMode) {
    return;
  }

  FlutterMemoryAllocations.instance.addListener(
    (ObjectEvent event) => LeakTracking.dispatchObjectEvent(event.toMap()),
  );
  LeakTracking.start();
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
      home: const HomePage(),
    );
  }
}
