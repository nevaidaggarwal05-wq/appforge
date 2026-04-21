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

  const FeatureFlags({
    required this.whatsappShare,
    required this.biometricAuth,
    required this.admob,
    required this.darkMode,
    required this.screenshotBlock,
    required this.rootBlock,
    required this.sessionPersistence,
    required this.networkDetection,
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
  );
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

class RemoteConfig {
  final String appUrl;
  final SplashConfig splash;
  final ThemeConfig theme;
  final FeatureFlags features;
  final UpdateConfig forceUpdate;
  final UpdateConfig softUpdate;
  final Map<String, dynamic> custom;
  final DateTime fetchedAt;

  const RemoteConfig({
    required this.appUrl,
    required this.splash,
    required this.theme,
    required this.features,
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
        features: FeatureFlags.fallback,
        forceUpdate: UpdateConfig.fallback,
        softUpdate:  UpdateConfig.fallback,
        custom: const {},
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
}
