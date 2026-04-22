import '../app_config.dart';
import '../core/api/api_client.dart';
import '../core/api/config_api.dart';
import '../core/errors/app_exceptions.dart';
import '../core/models/remote_config_model.dart';
import '../core/storage/cache_service.dart';
import '../utils/logger.dart';

/// Offline-first config. On `initialize()`:
///   1. Load last cached config immediately (for fast UI boot)
///   2. Fetch fresh from /api/config/:appId in parallel
///   3. If fetch succeeds, swap to fresh + persist
///   4. If fetch fails, keep cache (or fallback if no cache)
class RemoteConfigService {
  static RemoteConfig _current = RemoteConfig.fallback();
  static RemoteConfig get current => _current;
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<bool> initialize({
    String? fcmToken,
    String? platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
  }) async {
    // 1. Load cache first — this is the FAST path. If we have a cached
    //    config we proceed immediately and refresh in the background so
    //    cold start is not blocked on a network round-trip.
    final cached = await CacheService.loadConfig();
    if (cached != null) {
      _current = cached;
      _initialized = true;
      Log.i('[config] cache hit (${cached.fetchedAt.toIso8601String()}) — refreshing in background');

      // Fire-and-forget background refresh.
      // Awaited upsert/save still happens inside _refresh; just not awaited here.
      // ignore: unawaited_futures
      _refresh(
        fcmToken: fcmToken,
        platform: platform,
        deviceModel: deviceModel,
        osVersion: osVersion,
        appVersion: appVersion,
      );
      return true;
    }

    // 2. No cache → must block on fresh fetch.
    return _refresh(
      fcmToken: fcmToken,
      platform: platform,
      deviceModel: deviceModel,
      osVersion: osVersion,
      appVersion: appVersion,
    );
  }

  static Future<bool> _refresh({
    String? fcmToken,
    String? platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
  }) async {
    try {
      final api = ConfigApi(ApiClient(baseUrl: AppConfig.appforgeApiBaseUrl));
      final fresh = await api.fetch(
        AppConfig.appId,
        fcmToken:    fcmToken,
        platform:    platform,
        deviceModel: deviceModel,
        osVersion:   osVersion,
        appVersion:  appVersion,
      );
      _current = fresh;
      _initialized = true;
      await CacheService.saveConfig(fresh);
      Log.i('[config] Fetched fresh config');
      return true;
    } on NetworkException catch (e) {
      Log.w('[config] network: ${e.message} — using cache/fallback');
      _initialized = true;
      return false;
    } on ApiException catch (e) {
      Log.w('[config] API error ${e.statusCode}: ${e.message}');
      _initialized = true;
      return false;
    } catch (e) {
      Log.e('[config] unexpected error: $e');
      _initialized = true;
      return false;
    }
  }

  // Typed accessors
  static String  get appUrl             => _current.appUrl.isNotEmpty ? _current.appUrl : AppConfig.fallbackUrl;
  static String  get themeColor         => _current.theme.primary;
  static String  get accentColor        => _current.theme.accent;
  static String  get splashColor        => _current.splash.color;
  static String  get splashText         => _current.splash.text.isNotEmpty ? _current.splash.text : AppConfig.appName;
  static int     get splashDuration     => _current.splash.durationMs;
  static bool    get splashEnabled      => _current.splash.enabled;
  static String  get splashLogoUrl      => _current.splash.logoUrl;
  static bool    get whatsappEnabled    => _current.features.whatsappShare;
  static bool    get admobEnabled       => _current.features.admob;
  static bool    get biometricEnabled   => _current.features.biometricAuth;
  static bool    get darkModeEnabled    => _current.features.darkMode;
  static bool    get screenshotBlock    => _current.features.screenshotBlock;
  static bool    get rootBlock          => _current.features.rootBlock;
  static bool    get sessionPersistence => _current.features.sessionPersistence;
  static bool    get networkDetection   => _current.features.networkDetection;
  static int     get forceUpdateVersion => _current.forceUpdate.minVersionCode;
  static int     get softUpdateVersion  => _current.softUpdate.minVersionCode;
  static String  get forceUpdateMessage => _current.forceUpdate.message;
  static String  get softUpdateMessage  => _current.softUpdate.message;
  static String  get updateChangelog    => _current.forceUpdate.changelog;
  static Map<String, dynamic> get custom => _current.custom;

  // Migration 002 additions
  static bool      get pinchToZoom         => _current.features.pinchToZoom;
  static bool      get pullToRefresh       => _current.features.pullToRefresh;
  static String?   get whatsappNumber      => _current.whatsapp.number;
  static String    get whatsappMessage     => _current.whatsapp.message;
  static String    get admobPosition       => _current.admob.position; // 'none'|'top'|'bottom'
  static DateTime? get cacheSoftClearAt    => _current.cache.softClearAt;
  static DateTime? get cacheHardClearAt    => _current.cache.hardClearAt;

  // Migration 003 additions
  static String?      get userAgentSuffix    => _current.webview.userAgentSuffix;
  static bool         get edgeToEdge         => _current.webview.edgeToEdge;
  static String       get statusBarStyle     => _current.webview.statusBarStyle;
  static bool         get longPressDisabled  => _current.webview.longPressDisabled;
  static int          get pageLoadTimeoutMs  => _current.webview.pageLoadTimeoutMs;
  static List<String> get extraAllowedHosts  => _current.webview.extraAllowedHosts;
  static String       get themeColorSource   => _current.webview.themeColorSource;

  static bool   get geolocationEnabled => _current.permissions.geolocation;
  static bool   get scannerEnabled     => _current.permissions.scanner;
  static bool   get fileUploadEnabled  => _current.permissions.fileUpload;
  static bool   get downloadsEnabled   => _current.permissions.downloads;

  static int    get uploadMaxImageKb   => _current.upload.maxImageKb;
  static int    get uploadImageQuality => _current.upload.imageQuality;

  static String?       get oauthCustomScheme => _current.oauth.customScheme;
  static List<String>  get oauthHosts        => _current.oauth.hosts;

  static bool   get notifBadgeEnabled  => _current.notif.badgeEnabled;
  static String get defaultLocale      => _current.locale.defaultLocale;
}
