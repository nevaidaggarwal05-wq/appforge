import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/logger.dart';
import '../models/remote_config_model.dart';

/// Offline-first cache for the last successful RemoteConfig fetch.
class CacheService {
  static const _kConfigKey = 'appforge.remote_config.v1';
  static const _kLastUrlKey = 'appforge.session.last_url';

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
}
