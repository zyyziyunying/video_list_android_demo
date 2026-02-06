import 'dart:async';

import 'package:flutter/material.dart';

import 'video_concurrency_manager.dart';

/// 视频可见性管理门面类
///
/// 在 [VideoConcurrencyManager] 之上封装更易用的 API，
/// 内部管理滚动状态和 Timer，调用方无需关心细节。
///
/// ```dart
/// final manager = VideoVisibilityManager(maxActive: 3);
///
/// // 挂载滚动监听
/// NotificationListener<ScrollNotification>(
///   onNotification: manager.createScrollListener(),
///   child: ListView(...),
/// )
///
/// // 注册/注销
/// manager.attach(id);
/// manager.detach(id);
///
/// // 上报可见性
/// manager.onVisibilityChanged(id, visibleFraction);
///
/// // 查询状态
/// manager.isActive(id);
/// manager.activeCount;
/// ```
class VideoVisibilityManager extends ChangeNotifier {
  VideoVisibilityManager({
    int maxActive = 3,
    double visibleStart = 0.6,
    double visibleStop = 0.2,
    Duration recalcThrottle = const Duration(milliseconds: 300),
    this.scrollEndDelay = const Duration(milliseconds: 250),
  }) : _core = VideoConcurrencyManager(
          maxActive: maxActive,
          visibleStart: visibleStart,
          visibleStop: visibleStop,
          recalcThrottle: recalcThrottle,
        ) {
    _core.addListener(_onCoreChanged);
  }

  final VideoConcurrencyManager _core;
  final Duration scrollEndDelay;
  Timer? _scrollEndTimer;

  int get maxActive => _core.maxActive;

  set maxActive(int value) => _core.maxActive = value;

  int get activeCount => _core.activeCount;

  /// 注册一个视频 item
  void attach(String id) => _core.register(id);

  /// 注销一个视频 item
  void detach(String id) => _core.unregister(id);

  /// 上报可见性变化，通常在 VisibilityDetector 回调中调用
  void onVisibilityChanged(String id, double visibleFraction) {
    _core.updateVisibility(id, visibleFraction);
  }

  /// 查询某个 item 是否处于活跃状态
  bool isActive(String id) => _core.isActive(id);

  /// 创建一个滚动监听回调，直接挂到 NotificationListener 上即可
  ///
  /// ```dart
  /// NotificationListener<ScrollNotification>(
  ///   onNotification: manager.createScrollListener(),
  ///   child: ...,
  /// )
  /// ```
  bool Function(ScrollNotification) createScrollListener() {
    return (ScrollNotification notification) {
      if (notification is ScrollStartNotification) {
        _scrollEndTimer?.cancel();
        _core.setScrolling(true);
      } else if (notification is ScrollEndNotification) {
        _scrollEndTimer?.cancel();
        _scrollEndTimer = Timer(scrollEndDelay, () {
          _core.setScrolling(false);
        });
      }
      return false;
    };
  }

  void _onCoreChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    _core.removeListener(_onCoreChanged);
    _core.dispose();
    super.dispose();
  }
}
