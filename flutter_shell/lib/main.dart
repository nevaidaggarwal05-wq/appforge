import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'firebase_options.dart';
import 'core/api/api_client.dart';
import 'core/api/config_api.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'utils/color_utils.dart';
import 'utils/logger.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Firebase (core + crashlytics + messaging)
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // Forward Flutter errors to both Crashlytics and our backend
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
        _reportCrashToBackend(details.exceptionAsString(), details.stack);
      };
    } catch (e) {
      Log.e('[main] Firebase init failed: $e');
    }

    // Background FCM handler must be registered before runApp
    NotificationService.registerBackgroundHandler();

    runApp(const AppTemplateApp());
  }, (error, stack) {
    Log.e('[main] Uncaught zone error: $error');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    _reportCrashToBackend(error.toString(), stack);
  });
}

Future<void> _reportCrashToBackend(String error, StackTrace? stack) async {
  try {
    final api = ConfigApi(ApiClient(baseUrl: AppConfig.appforgeApiBaseUrl));
    await api.reportCrash(
      AppConfig.appId,
      error: error,
      stackTrace: stack?.toString(),
      appVersion: null,
    );
  } catch (e) {
    if (kDebugMode) Log.w('[crash] backend report failed: $e');
  }
}

class AppTemplateApp extends StatelessWidget {
  const AppTemplateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.fromHexOr(AppConfig.fallbackThemeColor, const Color(0xFF1A1A2E));
    final accent  = ColorUtils.fromHexOr(AppConfig.fallbackAccent, const Color(0xFFE94560));

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary, secondary: accent),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
