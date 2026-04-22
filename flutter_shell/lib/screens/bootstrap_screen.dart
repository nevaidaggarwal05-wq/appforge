import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../services/analytics_service.dart';
import '../services/device_info_service.dart';
import '../services/network_quality_service.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';
import '../services/security_service.dart';
import '../services/session_service.dart';
import '../utils/logger.dart';
import 'force_update_screen.dart';
import 'no_internet_screen.dart';
import 'root_detected_screen.dart';
import 'webview_screen.dart';

/// Invisible router — runs all the app-open checks in parallel then
/// swaps to the appropriate screen.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // Parallel: device info, FCM init, session count
    final device   = await DeviceInfoService.load();
    await NotificationService.initialize();
    final sessions = await SessionService.incrementAndGetCount();

    AnalyticsService.deviceId   = device.deviceId;
    AnalyticsService.appVersion = device.appVersion;

    // Connectivity
    final online = await NetworkQualityService.isOnline();

    // Fetch fresh config (will fall back to cache if offline)
    await RemoteConfigService.initialize(
      fcmToken:    NotificationService.fcmToken,
      platform:    device.platform,
      deviceModel: device.deviceModel,
      osVersion:   device.osVersion,
      appVersion:  device.appVersion,
    );

    if (!mounted) return;

    // Rooted + blocked?
    if (RemoteConfigService.rootBlock) {
      final rooted = await SecurityService.isRooted();
      if (rooted) {
        _go(const RootDetectedScreen());
        return;
      }
    }

    // Force update (hard block — shown before anything else).
    final minCode = RemoteConfigService.forceUpdateVersion;
    if (minCode > 0 && device.buildNumber < minCode) {
      _go(const ForceUpdateScreen());
      return;
    }

    // Offline?
    if (!online) {
      _go(const NoInternetScreen());
      return;
    }

    // Play Store in-app update — non-blocking check. If an immediate update
    // is available we still let the user through (only soft_update / force_update
    // gates are blocking); this just triggers the native "UPDATE AVAILABLE" UI.
    _checkInAppUpdate();

    // Fire a session_start event (non-blocking)
    AnalyticsService.log('session_start', {'session_count': sessions});

    Log.i('[bootstrap] ready — opening webview');
    _go(const WebViewScreen());
  }

  Future<void> _checkInAppUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Prefer flexible — user keeps using the app while download happens
        // in the background, then we prompt to install on next tap.
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        } else if (info.immediateUpdateAllowed) {
          // Only for critical releases flagged by the Play Console
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      // Non-Android platforms throw — fine, log + move on.
      Log.i('[in_app_update] skipped: $e');
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the splash look while bootstrapping
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
