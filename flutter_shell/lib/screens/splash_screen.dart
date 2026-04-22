import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../app_config.dart';
import '../services/analytics_service.dart';
import '../services/device_info_service.dart';
import '../services/intent_bridge_service.dart';
import '../services/network_quality_service.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';
import '../services/security_service.dart';
import '../services/session_service.dart';
import '../utils/color_utils.dart';
import '../utils/logger.dart';
import 'force_update_screen.dart';
import 'no_internet_screen.dart';
import 'root_detected_screen.dart';
import 'webview_screen.dart';

/// Merged splash + bootstrap. Shows the splash visual while running the
/// minimum-viable-boot checks, then pushes WebViewScreen as fast as
/// possible. Anything that isn't strictly required to decide "which
/// screen should the user see first" runs in the background.
///
/// Critical-path work (awaited):
///   • DeviceInfoService.load() — needed for force-update + analytics ids
///   • SessionService.incrementAndGetCount() — session counter
///   • NetworkQualityService.isOnline() — decides NoInternet vs WebView
///   • RemoteConfigService.initialize() — returns immediately when we
///     have cache; blocks only on first-ever launch
///
/// Background work (fire-and-forget):
///   • NotificationService.initialize() — FCM topic subs + token fetch
///     (was previously 1-4 s on the critical path)
///   • RemoteConfigService.refresh() once FCM token is ready so the
///     backend learns about this device
///   • SecurityService.isRooted() — if rooted, we swap to the block
///     screen over the WebView (no one's actually paid anything by
///     then, so there's no real UX cost)
///   • AnalyticsService.log('session_start')
///   • InAppUpdate.checkForUpdate() — Play Store flexible update
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // Critical-path reads — all in parallel.
    final deviceF   = DeviceInfoService.load();
    final sessionsF = SessionService.incrementAndGetCount();
    final onlineF   = NetworkQualityService.isOnline();
    final configF   = RemoteConfigService.initialize(
      // No FCM token on the first pass. The background task below
      // refreshes with a token once FCM finishes initializing.
      fcmToken:    null,
      platform:    null,
      deviceModel: null,
      osVersion:   null,
      appVersion:  null,
    );

    final device    = await deviceF;
    final sessions  = await sessionsF;
    final online    = await onlineF;
    final hasConfig = await configF;

    AnalyticsService.deviceId   = device.deviceId;
    AnalyticsService.appVersion = device.appVersion;

    // Apply admin-panel screenshot block (FLAG_SECURE). Off by
    // default, flipped here only if the `screenshot_block` flag is
    // true in remote config. Done BEFORE pushing the WebView so the
    // flag is in effect the moment any authenticated content paints.
    unawaited(
      IntentBridgeService.setSecureFlag(RemoteConfigService.screenshotBlock),
    );

    // ── Background work — nothing here blocks the WebView ─────────
    unawaited(_initFcmAndPushToken(device));
    unawaited(AnalyticsService.log('session_start', {'session_count': sessions}));
    unawaited(_checkInAppUpdate());
    if (RemoteConfigService.rootBlock) {
      unawaited(_enforceRootBlock());
    }

    if (!mounted) return;

    // Fresh install + offline → can't load anything, show offline screen.
    if (!hasConfig && !online) {
      _go(const NoInternetScreen());
      return;
    }

    // Force update — cached config is authoritative enough here.
    final minCode = RemoteConfigService.forceUpdateVersion;
    if (minCode > 0 && device.buildNumber < minCode) {
      _go(const ForceUpdateScreen());
      return;
    }

    // Normal path. WebView handles its own network errors.
    Log.i('[splash] → webview');
    _go(const WebViewScreen());
  }

  /// FCM is initialized off the critical path — its topic-subscribe calls
  /// are several network round-trips each. Once it finishes and we have
  /// a token, push it to the backend via a config refresh so the server
  /// can target pushes to this install.
  Future<void> _initFcmAndPushToken(DeviceSnapshot device) async {
    try {
      await NotificationService.initialize();
      final token = NotificationService.fcmToken;
      if (token != null && token.isNotEmpty) {
        await RemoteConfigService.refresh(
          fcmToken:    token,
          platform:    device.platform,
          deviceModel: device.deviceModel,
          osVersion:   device.osVersion,
          appVersion:  device.appVersion,
        );
      }
    } catch (e) {
      Log.w('[splash] fcm bg task failed: $e');
    }
  }

  Future<void> _enforceRootBlock() async {
    try {
      final rooted = await SecurityService.isRooted();
      if (rooted && mounted) {
        _go(const RootDetectedScreen());
      }
    } catch (_) {}
  }

  Future<void> _checkInAppUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      Log.i('[in_app_update] skipped: $e');
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // ── Visual (splash look) ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = ColorUtils.fromHexOr(
      RemoteConfigService.splashColor,
      ColorUtils.fromHexOr(AppConfig.fallbackThemeColor, Colors.black),
    );
    final textLight = _isDark(bg);

    final label = RemoteConfigService.splashText;
    final logo  = RemoteConfigService.splashLogoUrl;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (logo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  logo,
                  width: 96,
                  height: 96,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (RemoteConfigService.splashEnabled) ...[
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  color: textLight ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  textLight ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDark(Color c) {
    // Flutter >=3.24: Color.r/g/b are 0..1 doubles.
    final y = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return y < 0.627;
  }
}
