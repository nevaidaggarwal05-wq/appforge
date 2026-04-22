import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/cache_service.dart';

/// Persists: last URL visited, session count, first-install timestamp.
class SessionService {
  static const _kSessionCount   = 'appforge.session.count';
  static const _kFirstOpenAt    = 'appforge.session.first_open_at';

  static Future<int> incrementAndGetCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kSessionCount) ?? 0;
    final next = current + 1;
    await prefs.setInt(_kSessionCount, next);
    if (!prefs.containsKey(_kFirstOpenAt)) {
      await prefs.setString(_kFirstOpenAt, DateTime.now().toIso8601String());
    }
    return next;
  }

  static Future<int> getCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSessionCount) ?? 0;
  }

  static Future<String?> getLastUrl() => CacheService.loadLastUrl();
  static Future<void>    saveLastUrl(String url) => CacheService.saveLastUrl(url);
  static Future<void>    clearLastUrl() => CacheService.clearLastUrl();

  static Future<DateTime?> getFirstOpenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kFirstOpenAt);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Wipes all session keys. Called by hard cache-clear.
  /// Intentionally preserves `_kFirstOpenAt` for analytics continuity.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await CacheService.clearLastUrl();
    await prefs.remove(_kSessionCount);
  }
}
