// ═══════════════════════════════════════════════════════════════
// flutter_secure_storage wrapper for biometric-gated tokens.
// Exposed via JS:
//   window.flutter.secureSet(key, value)
//   window.flutter.secureGet(key)  → returns value or null
//   window.flutter.secureDel(key)
// Storage is encrypted by Android Keystore (hardware-backed on most
// devices) and iOS Keychain.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/logger.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> set(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      Log.w('[secure] write failed: $e');
    }
  }

  static Future<String?> get(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      Log.w('[secure] read failed: $e');
      return null;
    }
  }

  static Future<void> del(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      Log.w('[secure] delete failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
