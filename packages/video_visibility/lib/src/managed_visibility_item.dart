import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'video_visibility_manager.dart';

/// 通用的可见性监听 item 组件
///
/// 自动处理 attach/detach、VisibilityDetector、isActive 监听，
/// 调用方只需通过 [builder] 根据 isActive 状态构建 UI。
///
/// ```dart
/// ManagedVisibilityItem(
///   id: 'video_1',
///   manager: manager,
///   onActiveChanged: (isActive) => print('active: $isActive'),
///   builder: (context, isActive) {
///     return isActive ? VideoPlayer(...) : Placeholder();
///   },
/// )
/// ```
class ManagedVisibilityItem extends StatefulWidget {
  const ManagedVisibilityItem({
    super.key,
    required this.id,
    required this.manager,
    required this.builder,
    this.onActiveChanged,
  });

  final String id;
  final VideoVisibilityManager manager;

  /// 状态变化时的回调，在 rebuild 之前触发
  final ValueChanged<bool>? onActiveChanged;

  /// 根据当前 isActive 状态构建子 Widget
  final Widget Function(BuildContext context, bool isActive) builder;

  @override
  State<ManagedVisibilityItem> createState() => _ManagedVisibilityItemState();
}

class _ManagedVisibilityItemState extends State<ManagedVisibilityItem> {
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    widget.manager.attach(widget.id);
    widget.manager.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ManagedVisibilityItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.id != widget.id;
    final managerChanged = oldWidget.manager != widget.manager;
    if (managerChanged) {
      oldWidget.manager.removeListener(_onChanged);
    }
    if (idChanged || managerChanged) {
      oldWidget.manager.detach(oldWidget.id);
      widget.manager.attach(widget.id);
    }
    if (managerChanged) {
      widget.manager.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onChanged);
    widget.manager.detach(widget.id);
    super.dispose();
  }

  void _onChanged() {
    final active = widget.manager.isActive(widget.id);
    if (_isActive != active) {
      _isActive = active;
      widget.onActiveChanged?.call(_isActive);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('managed-visibility-${widget.id}'),
      onVisibilityChanged: (info) {
        widget.manager.onVisibilityChanged(widget.id, info.visibleFraction);
      },
      child: widget.builder(context, _isActive),
    );
  }
}
