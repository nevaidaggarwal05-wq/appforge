import 'package:flutter/foundation.dart';

/// Thin wrapper so we can later swap in a real logger (and so our crash
/// reporter can hook in). In release builds `print` still goes to logcat,
/// but debug-level calls are elided.
class Log {
  static void d(Object? msg) {
    if (kDebugMode) debugPrint('[D] $msg');
  }

  static void i(Object? msg) {
    debugPrint('[I] $msg');
  }

  static void w(Object? msg) {
    debugPrint('[W] $msg');
  }

  static void e(Object? msg, [Object? error, StackTrace? stack]) {
    debugPrint('[E] $msg ${error ?? ''}');
    if (stack != null && kDebugMode) debugPrint(stack.toString());
  }
}
