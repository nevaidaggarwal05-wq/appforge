import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Native Android bridge for things `url_launcher` can't do:
///
///   • `launchIntent(url)` — resolves `intent://…#Intent;…;end` URIs
///     via `Intent.parseUri(url, Intent.URI_INTENT_SCHEME)` and hands
///     them off with `startActivity`. This is the only correct way to
///     dispatch GPay / PhonePe / UPI intents emitted by Razorpay and
///     other payment gateways — `url_launcher` can't parse that scheme
///     and silently returns false, which is why UPI app handoff was
///     broken. Includes built-in fallback to `S.browser_fallback_url`
///     (Play Store link) when the target app isn't installed.
///
///   • `setSecureFlag(enabled)` — toggles Android's `FLAG_SECURE`,
///     which blocks screenshots / screen-recording and hides the app
///     from the recent-apps thumbnail. Driven from the admin-panel
///     `screenshot_block` remote flag; called once after remote config
///     loads during boot.
///
/// Channel name `appforge/native` is stable across every white-label
/// app — each per-app `MainActivity.kt` registers the same channel
/// name, so shell-side Dart code doesn't need to know the package id.
class IntentBridgeService {
  static const MethodChannel _ch = MethodChannel('appforge/native');

  /// Dispatch an `intent://` URI. Returns true if an activity was
  /// launched (including a browser-fallback or Play Store redirect).
  /// Returns false only when every fallback exhausted.
  static Future<bool> launchIntent(String url) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final ok = await _ch.invokeMethod<bool>('launchIntent', {'url': url});
      return ok ?? false;
    } on PlatformException catch (e) {
      Log.w('[intent_bridge] launchIntent PlatformException: $e');
      return false;
    } on MissingPluginException {
      // Happens only on iOS or if the per-app MainActivity is missing
      // the channel registration. Shell-side callers should fall back
      // to url_launcher in that case.
      return false;
    }
  }

  /// Apply or clear `FLAG_SECURE`. Driven by remote config's
  /// `screenshot_block` boolean. Idempotent — safe to call repeatedly.
  static Future<void> setSecureFlag(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _ch.invokeMethod('setSecureFlag', {'enabled': enabled});
    } catch (e) {
      Log.w('[intent_bridge] setSecureFlag failed: $e');
    }
  }
}
