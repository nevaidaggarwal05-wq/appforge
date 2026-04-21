import 'dart:io' show Platform, File, Directory;

import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

/// Lightweight root/jailbreak heuristic. Not bulletproof — a determined
/// attacker will bypass any client-side check — but good enough to nudge
/// casual rooted-device users when `root_block` is enabled.
class SecurityService {
  static Future<bool> isRooted() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) return _isAndroidRooted();
      if (Platform.isIOS)     return _isIosJailbroken();
    } catch (e) {
      Log.w('[security] root check failed: $e');
    }
    return false;
  }

  static bool _isAndroidRooted() {
    const paths = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/system/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
      '/system/app/SuperSU.apk',
      '/system/app/Magisk.apk',
    ];
    for (final p in paths) {
      try {
        if (File(p).existsSync()) return true;
      } catch (_) {}
    }
    return false;
  }

  static bool _isIosJailbroken() {
    const paths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/Applications/Sileo.app',
    ];
    for (final p in paths) {
      try {
        if (File(p).existsSync()) return true;
        if (Directory(p).existsSync()) return true;
      } catch (_) {}
    }
    return false;
  }
}
