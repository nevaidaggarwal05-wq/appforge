import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../utils/logger.dart';
import 'session_service.dart';

class RatingService {
  static const _kPromptedKey = 'appforge.rating.prompted_at';

  static Future<bool> shouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kPromptedKey)) return false;
    final sessions = await SessionService.getCount();
    return sessions >= AppConfig.ratingPromptAfterSessions;
  }

  static Future<void> maybePrompt() async {
    if (!await shouldPrompt()) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPromptedKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      Log.w('[rating] prompt failed: $e');
    }
  }

  static Future<void> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing(
        appStoreId: null,
        microsoftStoreId: null,
      );
    } catch (e) {
      Log.w('[rating] openStoreListing failed: $e');
    }
  }
}
