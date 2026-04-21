import '../../utils/logger.dart';
import '../errors/app_exceptions.dart';
import '../models/remote_config_model.dart';
import 'api_client.dart';

/// Typed wrapper around the three public endpoints Flutter calls:
///   GET  /api/config/:appId
///   POST /api/apps/:id/analytics-event
///   POST /api/apps/:id/crash
class ConfigApi {
  final ApiClient _client;
  ConfigApi(this._client);

  Future<RemoteConfig> fetch(
    String appId, {
    String? fcmToken,
    String? platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
  }) async {
    final query = <String, dynamic>{
      if (fcmToken    != null && fcmToken.isNotEmpty)    'fcm_token':    fcmToken,
      if (platform    != null && platform.isNotEmpty)    'platform':     platform,
      if (deviceModel != null && deviceModel.isNotEmpty) 'device_model': deviceModel,
      if (osVersion   != null && osVersion.isNotEmpty)   'os_version':   osVersion,
      if (appVersion  != null && appVersion.isNotEmpty)  'app_version':  appVersion,
    };
    final res = await _client.get<Map<String, dynamic>>(
      '/api/config/$appId',
      query: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data == null) {
      throw ApiException(res.statusCode ?? 0, 'Empty config body');
    }
    return RemoteConfig.fromJson(data);
  }

  Future<void> logEvent(
    String appId, {
    required String eventName,
    Map<String, dynamic>? properties,
    String? userId,
    String? deviceId,
    String? platform,
    String? appVersion,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/api/apps/$appId/analytics-event',
        data: {
          'event_name':  eventName,
          if (properties  != null) 'properties':  properties,
          if (userId      != null) 'user_id':     userId,
          if (deviceId    != null) 'device_id':   deviceId,
          if (platform    != null) 'platform':    platform,
          if (appVersion  != null) 'app_version': appVersion,
        },
      );
    } catch (e) {
      Log.w('[analytics] send failed: $e');
    }
  }

  Future<void> reportCrash(
    String appId, {
    required String error,
    String? stackTrace,
    Map<String, dynamic>? deviceInfo,
    String? appVersion,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/api/apps/$appId/crash',
        data: {
          'error':       error,
          if (stackTrace != null) 'stack_trace': stackTrace,
          if (deviceInfo != null) 'device_info': deviceInfo,
          if (appVersion != null) 'app_version': appVersion,
        },
      );
    } catch (e) {
      Log.w('[crash] send failed: $e');
    }
  }
}
