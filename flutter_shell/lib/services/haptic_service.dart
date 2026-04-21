import 'package:flutter/services.dart';

class HapticService {
  static Future<void> light()   => HapticFeedback.lightImpact();
  static Future<void> medium()  => HapticFeedback.mediumImpact();
  static Future<void> heavy()   => HapticFeedback.heavyImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> error()   => HapticFeedback.vibrate();

  /// Dispatch by tag string (from the JS bridge).
  static Future<void> byTag(String tag) {
    switch (tag) {
      case 'light':   return light();
      case 'medium':  return medium();
      case 'heavy':   return heavy();
      case 'success': return success();
      case 'error':   return error();
      default:        return light();
    }
  }
}
