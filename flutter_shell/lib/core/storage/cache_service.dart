import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/logger.dart';
import '../models/remote_config_model.dart';

/// Offline-first cache for the last successful RemoteConfig fetch.
class CacheService {
  static const _kConfigKey       = 'appforge.remote_config.v1';
  static const _kLastUrlKey      = 'appforge.session.last_url';
  static const _kSoftClearAppliedKey = 'appforge.cache.soft_clear_applied_at';
  static const _kHardClearAppliedKey = 'appforge.cache.hard_clear_applied_at';

  static Future<RemoteConfig?> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kConfigKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.tryParse(decoded['_fetched_at'] as String? ?? '');
      return RemoteConfig.fromJson(decoded, fetchedAt: fetchedAt);
    } catch (e) {
      Log.w('[cache] loadConfig failed: $e');
      return null;
    }
  }

  static Future<void> saveConfig(RemoteConfig c) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kConfigKey, jsonEncode(c.toJson()));
    } catch (e) {
      Log.w('[cache] saveConfig failed: $e');
    }
  }

  static Future<String?> loadLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastUrlKey);
  }

  static Future<void> saveLastUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastUrlKey, url);
  }

  static Future<void> clearLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastUrlKey);
  }

  // ── Cache-clear timestamp tracking (migration 002) ────────────────
  // The Flutter shell records the timestamp of the last soft/hard clear it
  // actually applied. On every boot it compares against the server-provided
  // cache.soft_clear_at / cache.hard_clear_at. If the server's is newer,
  // it runs the clear and then records the new timestamp.

  static Future<DateTime?> lastSoftClearApplied() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSoftClearAppliedKey);
    return (raw == null) ? null : DateTime.tryParse(raw);
  }

  static Future<DateTime?> lastHardClearApplied() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHardClearAppliedKey);
    return (raw == null) ? null : DateTime.tryParse(raw);
  }

  static Future<void> recordSoftClearApplied(DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSoftClearAppliedKey, when.toIso8601String());
  }

  static Future<void> recordHardClearApplied(DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHardClearAppliedKey, when.toIso8601String());
  }
}
