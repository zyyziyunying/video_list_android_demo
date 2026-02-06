import 'dart:async';

import 'package:flutter/foundation.dart';

class VideoConcurrencyManager extends ChangeNotifier {
  VideoConcurrencyManager({
    int maxActive = 2,
    this.visibleStart = 0.6,
    this.visibleStop = 0.2,
    this.recalcThrottle = const Duration(milliseconds: 300),
  }) : _maxActive = maxActive;

  static const double _fullVisibilityThreshold = 0.999;

  final double visibleStart;
  final double visibleStop;
  final Duration recalcThrottle;

  final Map<String, _Entry> _entries = {};
  final Set<String> _active = {};
  Timer? _recalcTimer;
  bool _isScrolling = false;
  int _maxActive;

  int get maxActive => _maxActive;
  int get activeCount => _active.length;

  set maxActive(int value) {
    if (_maxActive == value) {
      return;
    }
    _maxActive = value;
    _scheduleRecalculate(immediate: true);
  }

  void register(String id) {
    _entries.putIfAbsent(id, _Entry.new);
    _scheduleRecalculate();
  }

  void unregister(String id) {
    _entries.remove(id);
    if (_active.remove(id)) {
      notifyListeners();
    }
  }

  void updateVisibility(String id, double visibleFraction) {
    final entry = _entries[id];
    if (entry == null) {
      return;
    }
    entry.visible = visibleFraction;
    entry.lastUpdated = DateTime.now();
    _scheduleRecalculate();
  }

  void setScrolling(bool isScrolling) {
    if (_isScrolling == isScrolling) {
      return;
    }
    _isScrolling = isScrolling;
    _scheduleRecalculate(immediate: true);
  }

  bool isActive(String id) => _active.contains(id);

  void _scheduleRecalculate({bool immediate = false}) {
    if (immediate) {
      _recalcTimer?.cancel();
      _recalculate();
      return;
    }
    if (_recalcTimer?.isActive ?? false) {
      return;
    }
    _recalcTimer = Timer(recalcThrottle, _recalculate);
  }

  void _recalculate() {
    final candidates = <_Candidate>[];
    _entries.forEach((id, entry) {
      final isCurrentlyActive = _active.contains(id);
      final eligible = _isScrolling
          ? entry.visible >= _fullVisibilityThreshold
          : entry.visible >= visibleStart ||
              (isCurrentlyActive && entry.visible >= visibleStop);
      if (!eligible) {
        return;
      }
      candidates.add(_Candidate(
        id: id,
        visible: entry.visible,
        isActive: isCurrentlyActive,
        lastUpdated: entry.lastUpdated,
      ));
    });

    if (candidates.isEmpty) {
      _setActive(<String>{});
      return;
    }

    candidates.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }
      final visibleCompare = b.visible.compareTo(a.visible);
      if (visibleCompare != 0) {
        return visibleCompare;
      }
      return b.lastUpdated.compareTo(a.lastUpdated);
    });

    final nextActive = <String>{};
    for (final candidate in candidates) {
      if (nextActive.length >= _maxActive) {
        break;
      }
      nextActive.add(candidate.id);
    }
    _setActive(nextActive);
  }

  void _setActive(Set<String> nextActive) {
    if (_setEquals(_active, nextActive)) {
      return;
    }
    _active
      ..clear()
      ..addAll(nextActive);
    notifyListeners();
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }
}

class _Entry {
  double visible = 0;
  DateTime lastUpdated = DateTime.fromMillisecondsSinceEpoch(0);
}

class _Candidate {
  _Candidate({
    required this.id,
    required this.visible,
    required this.isActive,
    required this.lastUpdated,
  });

  final String id;
  final double visible;
  final bool isActive;
  final DateTime lastUpdated;
}
