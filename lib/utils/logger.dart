import 'dart:developer' as developer;

/// 简单日志工具，基于 dart:developer log 封装
/// 使用 ANSI 转义码渲染颜色
class Log {
  static const String _reset = '\x1B[0m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';
  static const String _cyan = '\x1B[36m';

  /// 基础信息日志 (绿色)
  static void info(String message, {String? tag}) {
    final t = tag ?? 'INFO';
    final output = '$_green[$t] ===$message$_reset';
    developer.log(output, name: t);
  }

  /// 临时调试日志 (青色)
  static void tmp(String message, {String? tag}) {
    final t = tag ?? 'TMP';
    final output = '$_cyan[$t] ===$message$_reset';
    developer.log(output, name: t);
  }

  /// 警告日志 (黄色)
  static void warning(String message, {String? tag}) {
    final t = tag ?? 'WARNING';
    final output = '$_yellow[$t] ===$message$_reset';
    developer.log(output, name: t);
  }

  /// 错误日志 (红色)
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final t = tag ?? 'ERROR';
    final output = '$_red[$t] ===$message$_reset';
    developer.log(output, name: t, error: error, stackTrace: stackTrace);
  }
}
