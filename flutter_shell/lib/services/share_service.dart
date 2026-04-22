// ═══════════════════════════════════════════════════════════════
// Native share-sheet wrapper. Used by:
//   - window.flutter.shareSystem({text, url}) JS bridge
//   - Analytics "share" events
// Separate from WhatsAppShareButton which targets one app.
// ═══════════════════════════════════════════════════════════════

import 'package:share_plus/share_plus.dart';

import '../utils/logger.dart';

class ShareService {
  static Future<void> share({String? text, String? url, String? subject}) async {
    final body = [text, url].where((e) => e != null && e.isNotEmpty).join('\n');
    if (body.isEmpty) return;
    try {
      await Share.share(body, subject: subject);
    } catch (e) {
      Log.w('[share] failed: $e');
    }
  }
}
