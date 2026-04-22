// ═══════════════════════════════════════════════════════════════
// Clipboard helpers for the JS bridge:
//   window.flutter.copyText(str)    → writes to clipboard
//   window.flutter.readClipboard()  → returns current text (or '')
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/services.dart';

import '../utils/logger.dart';

class ClipboardService {
  static Future<void> copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      Log.w('[clipboard] copy failed: $e');
    }
  }

  static Future<String> read() async {
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      return d?.text ?? '';
    } catch (e) {
      Log.w('[clipboard] read failed: $e');
      return '';
    }
  }
}
