// Mirrors `RemoteConfigResponse` in admin_panel/lib/supabase/types.ts.
// See docs/API_CONTRACT.md — every field is a binding contract.

import '../../app_config.dart';

class SplashConfig {
  final bool enabled;
  final String color;
  final String text;
  final int durationMs;
  final String logoUrl;

  const SplashConfig({
    required this.enabled,
    required this.color,
    required this.text,
    required this.durationMs,
    required this.logoUrl,
  });

  factory SplashConfig.fromJson(Map<String, dynamic> j) => SplashConfig(
        enabled:    j['enabled']     as bool?   ?? true,
        color:      j['color']       as String? ?? AppConfig.fallbackThemeColor,
        text:       j['text']        as String? ?? '',
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? AppConfig.splashDurationMs,
        logoUrl:    j['logo_url']    as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'enabled':     enabled,
        'color':       color,
        'text':        text,
        'duration_ms': durationMs,
        'logo_url':    logoUrl,
      };
}

class ThemeConfig {
  final String primary;
  final String accent;

  const ThemeConfig({required this.primary, required this.accent});

  factory ThemeConfig.fromJson(Map<String, dynamic> j) => ThemeConfig(
        primary: j['primary'] as String? ?? AppConfig.fallbackThemeColor,
        accent:  j['accent']  as String? ?? AppConfig.fallbackAccent,
      );

  Map<String, dynamic> toJson() => {'primary': primary, 'accent': accent};
}

class FeatureFlags {
  final bool whatsappShare;
  final bool biometricAuth;
  final bool admob;
  final bool darkMode;
  final bool screenshotBlock;
  final bool rootBlock;
  final bool sessionPersistence;
  final bool networkDetection;
  final bool pinchToZoom;
  final bool pullToRefresh;

  const FeatureFlags({
    required this.whatsappShare,
    required this.biometricAuth,
    required this.admob,
    required this.darkMode,
    required this.screenshotBlock,
    required this.rootBlock,
    required this.sessionPersistence,
    required this.networkDetection,
    required this.pinchToZoom,
    required this.pullToRefresh,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> j) => FeatureFlags(
        whatsappShare:      j['whatsapp_share']      as bool? ?? false,
        biometricAuth:      j['biometric_auth']      as bool? ?? false,
        admob:              j['admob']               as bool? ?? false,
        darkMode:           j['dark_mode']           as bool? ?? true,
        screenshotBlock:    j['screenshot_block']    as bool? ?? true,
        rootBlock:          j['root_block']          as bool? ?? true,
        sessionPersistence: j['session_persistence'] as bool? ?? true,
        networkDetection:   j['network_detection']   as bool? ?? true,
        pinchToZoom:        j['pinch_to_zoom']       as bool? ?? true,
        pullToRefresh:      j['pull_to_refresh']     as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'whatsapp_share':      whatsappShare,
        'biometric_auth':      biometricAuth,
        'admob':               admob,
        'dark_mode':           darkMode,
        'screenshot_block':    screenshotBlock,
        'root_block':          rootBlock,
        'session_persistence': sessionPersistence,
        'network_detection':   networkDetection,
        'pinch_to_zoom':       pinchToZoom,
        'pull_to_refresh':     pullToRefresh,
      };

  static const fallback = FeatureFlags(
    whatsappShare: false,
    biometricAuth: false,
    admob: false,
    darkMode: true,
    screenshotBlock: true,
    rootBlock: true,
    sessionPersistence: true,
    networkDetection: true,
    pinchToZoom: true,
    pullToRefresh: true,
  );
}

class WhatsAppConfig {
  final String? number;
  final String message;
  const WhatsAppConfig({required this.number, required this.message});
  factory WhatsAppConfig.fromJson(Map<String, dynamic> j) => WhatsAppConfig(
        number:  j['number']  as String?,
        message: j['message'] as String? ?? 'Check out this app',
      );
  Map<String, dynamic> toJson() => {'number': number, 'message': message};
  static const fallback = WhatsAppConfig(number: null, message: 'Check out this app');
}

class AdMobConfig {
  final String position; // 'none' | 'top' | 'bottom'
  const AdMobConfig({required this.position});
  factory AdMobConfig.fromJson(Map<String, dynamic> j) => AdMobConfig(
        position: j['position'] as String? ?? 'none',
      );
  Map<String, dynamic> toJson() => {'position': position};
  static const fallback = AdMobConfig(position: 'none');
}

class CacheConfig {
  final DateTime? softClearAt;
  final DateTime? hardClearAt;
  const CacheConfig({required this.softClearAt, required this.hardClearAt});
  factory CacheConfig.fromJson(Map<String, dynamic> j) => CacheConfig(
        softClearAt: _parse(j['soft_clear_at']),
        hardClearAt: _parse(j['hard_clear_at']),
      );
  static DateTime? _parse(dynamic v) {
    if (v == null || v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
  Map<String, dynamic> toJson() => {
        'soft_clear_at': softClearAt?.toIso8601String(),
        'hard_clear_at': hardClearAt?.toIso8601String(),
      };
  static const fallback = CacheConfig(softClearAt: null, hardClearAt: null);
}

class UpdateConfig {
  final int minVersionCode;
  final String message;
  final String changelog;

  const UpdateConfig({
    required this.minVersionCode,
    required this.message,
    required this.changelog,
  });

  factory UpdateConfig.fromJson(Map<String, dynamic> j) => UpdateConfig(
        minVersionCode: (j['min_version_code'] as num?)?.toInt() ?? 0,
        message:        j['message']   as String? ?? '',
        changelog:      j['changelog'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'min_version_code': minVersionCode,
        'message':          message,
        'changelog':        changelog,
      };

  static const fallback = UpdateConfig(minVersionCode: 0, message: '', changelog: '');
}

class WebViewConfig {
  final String? userAgentSuffix;
  final bool edgeToEdge;
  final String statusBarStyle; // 'auto' | 'light' | 'dark'
  final bool longPressDisabled;
  final int pageLoadTimeoutMs;
  final List<String> extraAllowedHosts;
  final String themeColorSource; // 'admin' | 'meta' | 'system'

  const WebViewConfig({
    required this.userAgentSuffix,
    required this.edgeToEdge,
    required this.statusBarStyle,
    required this.longPressDisabled,
    required this.pageLoadTimeoutMs,
    required this.extraAllowedHosts,
    required this.themeColorSource,
  });

  factory WebViewConfig.fromJson(Map<String, dynamic> j) => WebViewConfig(
        userAgentSuffix:   j['user_agent_suffix']  as String?,
        edgeToEdge:        j['edge_to_edge']       as bool? ?? true,
        statusBarStyle:    j['status_bar_style']   as String? ?? 'auto',
        longPressDisabled: j['long_press_disabled'] as bool? ?? true,
        pageLoadTimeoutMs: (j['page_load_timeout_ms'] as num?)?.toInt() ?? 20000,
        extraAllowedHosts: ((j['extra_allowed_hosts'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        themeColorSource:  j['theme_color_source'] as String? ?? 'admin',
      );

  Map<String, dynamic> toJson() => {
        'user_agent_suffix':    userAgentSuffix,
        'edge_to_edge':         edgeToEdge,
        'status_bar_style':     statusBarStyle,
        'long_press_disabled':  longPressDisabled,
        'page_load_timeout_ms': pageLoadTimeoutMs,
        'extra_allowed_hosts':  extraAllowedHosts,
        'theme_color_source':   themeColorSource,
      };

  static const fallback = WebViewConfig(
    userAgentSuffix: null,
    edgeToEdge: true,
    statusBarStyle: 'auto',
    longPressDisabled: true,
    pageLoadTimeoutMs: 20000,
    extraAllowedHosts: [],
    themeColorSource: 'admin',
  );
}

class PermissionsConfig {
  final bool geolocation;
  final bool scanner;
  final bool fileUpload;
  final bool downloads;

  const PermissionsConfig({
    required this.geolocation,
    required this.scanner,
    required this.fileUpload,
    required this.downloads,
  });

  factory PermissionsConfig.fromJson(Map<String, dynamic> j) => PermissionsConfig(
        geolocation: j['geolocation'] as bool? ?? false,
        scanner:     j['scanner']     as bool? ?? false,
        fileUpload:  j['file_upload'] as bool? ?? true,
        downloads:   j['downloads']   as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'geolocation': geolocation,
        'scanner':     scanner,
        'file_upload': fileUpload,
        'downloads':   downloads,
      };

  static const fallback = PermissionsConfig(
    geolocation: false,
    scanner: false,
    fileUpload: true,
    downloads: true,
  );
}

class UploadConfig {
  final int maxImageKb;
  final int imageQuality;

  const UploadConfig({required this.maxImageKb, required this.imageQuality});

  factory UploadConfig.fromJson(Map<String, dynamic> j) => UploadConfig(
        maxImageKb:   (j['max_image_kb']  as num?)?.toInt() ?? 1024,
        imageQuality: (j['image_quality'] as num?)?.toInt() ?? 80,
      );

  Map<String, dynamic> toJson() => {
        'max_image_kb':  maxImageKb,
        'image_quality': imageQuality,
      };

  static const fallback = UploadConfig(maxImageKb: 1024, imageQuality: 80);
}

class OAuthConfig {
  final String? customScheme;
  final List<String> hosts;

  const OAuthConfig({required this.customScheme, required this.hosts});

  factory OAuthConfig.fromJson(Map<String, dynamic> j) => OAuthConfig(
        customScheme: j['custom_scheme'] as String?,
        hosts: ((j['hosts'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'custom_scheme': customScheme,
        'hosts':         hosts,
      };

  static const fallback = OAuthConfig(
    customScheme: null,
    hosts: ['accounts.google.com', 'appleid.apple.com', 'login.microsoftonline.com'],
  );
}

class NotifConfig {
  final bool badgeEnabled;
  const NotifConfig({required this.badgeEnabled});
  factory NotifConfig.fromJson(Map<String, dynamic> j) =>
      NotifConfig(badgeEnabled: j['badge_enabled'] as bool? ?? true);
  Map<String, dynamic> toJson() => {'badge_enabled': badgeEnabled};
  static const fallback = NotifConfig(badgeEnabled: true);
}

class LocaleConfig {
  final String defaultLocale; // 'en' | 'hi'
  const LocaleConfig({required this.defaultLocale});
  factory LocaleConfig.fromJson(Map<String, dynamic> j) =>
      LocaleConfig(defaultLocale: j['default'] as String? ?? 'en');
  Map<String, dynamic> toJson() => {'default': defaultLocale};
  static const fallback = LocaleConfig(defaultLocale: 'en');
}

class RemoteConfig {
  final String appUrl;
  final SplashConfig splash;
  final ThemeConfig theme;
  final FeatureFlags features;
  final WhatsAppConfig whatsapp;
  final AdMobConfig admob;
  final CacheConfig cache;
  final WebViewConfig webview;
  final PermissionsConfig permissions;
  final UploadConfig upload;
  final OAuthConfig oauth;
  final NotifConfig notif;
  final LocaleConfig locale;
  final UpdateConfig forceUpdate;
  final UpdateConfig softUpdate;
  final Map<String, dynamic> custom;
  final DateTime fetchedAt;

  const RemoteConfig({
    required this.appUrl,
    required this.splash,
    required this.theme,
    required this.features,
    required this.whatsapp,
    required this.admob,
    required this.cache,
    required this.webview,
    required this.permissions,
    required this.upload,
    required this.oauth,
    required this.notif,
    required this.locale,
    required this.forceUpdate,
    required this.softUpdate,
    required this.custom,
    required this.fetchedAt,
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j, {DateTime? fetchedAt}) => RemoteConfig(
        appUrl:      j['app_url'] as String? ?? '',
        splash:      SplashConfig.fromJson((j['splash'] ?? {}) as Map<String, dynamic>),
        theme:       ThemeConfig.fromJson((j['theme']  ?? {}) as Map<String, dynamic>),
        features:    FeatureFlags.fromJson((j['features'] ?? {}) as Map<String, dynamic>),
        whatsapp:    WhatsAppConfig.fromJson((j['whatsapp'] ?? {}) as Map<String, dynamic>),
        admob:       AdMobConfig.fromJson((j['admob']    ?? {}) as Map<String, dynamic>),
        cache:       CacheConfig.fromJson((j['cache']    ?? {}) as Map<String, dynamic>),
        webview:     WebViewConfig.fromJson((j['webview'] ?? {}) as Map<String, dynamic>),
        permissions: PermissionsConfig.fromJson((j['permissions'] ?? {}) as Map<String, dynamic>),
        upload:      UploadConfig.fromJson((j['upload'] ?? {}) as Map<String, dynamic>),
        oauth:       OAuthConfig.fromJson((j['oauth']  ?? {}) as Map<String, dynamic>),
        notif:       NotifConfig.fromJson((j['notif']  ?? {}) as Map<String, dynamic>),
        locale:      LocaleConfig.fromJson((j['locale'] ?? {}) as Map<String, dynamic>),
        forceUpdate: UpdateConfig.fromJson((j['force_update'] ?? {}) as Map<String, dynamic>),
        softUpdate:  UpdateConfig.fromJson((j['soft_update']  ?? {}) as Map<String, dynamic>),
        custom:      Map<String, dynamic>.from((j['custom'] ?? {}) as Map),
        fetchedAt:   fetchedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'app_url':      appUrl,
        'splash':       splash.toJson(),
        'theme':        theme.toJson(),
        'features':     features.toJson(),
        'whatsapp':     whatsapp.toJson(),
        'admob':        admob.toJson(),
        'cache':        cache.toJson(),
        'webview':      webview.toJson(),
        'permissions':  permissions.toJson(),
        'upload':       upload.toJson(),
        'oauth':        oauth.toJson(),
        'notif':        notif.toJson(),
        'locale':       locale.toJson(),
        'force_update': forceUpdate.toJson(),
        'soft_update':  softUpdate.toJson(),
        'custom':       custom,
        '_fetched_at':  fetchedAt.toIso8601String(),
      };

  factory RemoteConfig.fallback() => RemoteConfig(
        appUrl: AppConfig.fallbackUrl,
        splash: SplashConfig(
          enabled: AppConfig.splashShowText,
          color: AppConfig.fallbackThemeColor,
          text: AppConfig.appName,
          durationMs: AppConfig.splashDurationMs,
          logoUrl: '',
        ),
        theme: const ThemeConfig(
          primary: AppConfig.fallbackThemeColor,
          accent:  AppConfig.fallbackAccent,
        ),
        features:    FeatureFlags.fallback,
        whatsapp:    WhatsAppConfig.fallback,
        admob:       AdMobConfig.fallback,
        cache:       CacheConfig.fallback,
        webview:     WebViewConfig.fallback,
        permissions: PermissionsConfig.fallback,
        upload:      UploadConfig.fallback,
        oauth:       OAuthConfig.fallback,
        notif:       NotifConfig.fallback,
        locale:      LocaleConfig.fallback,
        forceUpdate: UpdateConfig.fallback,
        softUpdate:  UpdateConfig.fallback,
        custom: const {},
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
}
