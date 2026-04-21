import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../core/api/api_client.dart';
import '../core/api/config_api.dart';

/// Custom events sent to our backend (replaces Firebase Analytics).
/// Fires are fire-and-forget from the caller's perspective; internally
/// the ConfigApi swallows network errors to avoid interrupting the UI.
class AnalyticsService {
  static late final ConfigApi _api =
      ConfigApi(ApiClient(baseUrl: AppConfig.appforgeApiBaseUrl));

  static String? userId;
  static String? deviceId;
  static String? appVersion;

  static String? get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return null;
  }

  static Future<void> log(String eventName, [Map<String, dynamic>? props]) {
    return _api.logEvent(
      AppConfig.appId,
      eventName:  eventName,
      properties: props,
      userId:     userId,
      deviceId:   deviceId,
      platform:   _platform,
      appVersion: appVersion,
    );
  }

  static Future<void> pageView(String path) => log('page_view', {'path': path});
  static Future<void> buttonClick(String id) => log('button_click', {'button_id': id});
}
