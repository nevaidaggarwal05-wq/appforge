import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_config.dart';
import 'firebase_options.dart';
import 'core/api/api_client.dart';
import 'core/api/config_api.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/remote_config_service.dart';
import 'utils/color_utils.dart';
import 'utils/logger.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Edge-to-edge — Android 15 default. Content draws under the status/nav
    // bars. SafeArea in every screen already accounts for this, and the
    // overlay style below is re-applied on RemoteConfig load.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Firebase (core + crashlytics + messaging)
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

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

    // AdMob — initialize SDK once at startup. Safe to call even when
    // admob is disabled in remote config; we just won't ask for any ads.
    // No-op on web (the package has no web impl).
    if (!kIsWeb) {
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        Log.w('[admob] init failed: $e');
      }
    }

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

class AppTemplateApp extends StatefulWidget {
  const AppTemplateApp({super.key});
  @override
  State<AppTemplateApp> createState() => _AppTemplateAppState();
}

class _AppTemplateAppState extends State<AppTemplateApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyOverlayStyle();
    _initAppLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyOverlayStyle();
    }
  }

  /// Read the remote status-bar preference and apply it. Called again each
  /// time the app resumes so theme swaps on the web side take effect without
  /// a full restart.
  void _applyOverlayStyle() {
    final src = RemoteConfigService.statusBarStyle; // 'auto' | 'light' | 'dark'
    SystemUiOverlayStyle style;
    switch (src) {
      case 'light':
        style = SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
        break;
      case 'dark':
        style = SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
        break;
      default:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        style = (brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
    }
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  /// Handles OAuth callbacks and push deep links that open the app via a
  /// custom scheme (e.g. `maximoney://callback?code=...`). The URL is
  /// forwarded into the WebView by reusing NotificationService.deepLinkUrl.
  Future<void> _initAppLinks() async {
    try {
      // Cold-start: the URL the app was opened with.
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _forwardLink(initial);
      // Warm links while running.
      _linkSub = _appLinks.uriLinkStream.listen(_forwardLink, onError: (e) {
        Log.w('[applinks] stream error: $e');
      });
    } catch (e) {
      Log.w('[applinks] init failed: $e');
    }
  }

  void _forwardLink(Uri uri) {
    final raw = uri.toString();
    Log.i('[applinks] received $raw');
    NotificationService.deepLinkUrl.value = raw;
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.fromHexOr(
        AppConfig.fallbackThemeColor, const Color(0xFF1A1A2E));
    final accent =
        ColorUtils.fromHexOr(AppConfig.fallbackAccent, const Color(0xFFE94560));

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: primary, secondary: accent),
        useMaterial3: true,
      ),
      // i18n — English + Hindi for native screens (splash, update, offline).
      // The default is overridden by RemoteConfigService.defaultLocale once
      // config loads; Flutter picks the closest match for the device locale.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi')],
      localeResolutionCallback: (deviceLocale, supported) {
        final pref = RemoteConfigService.defaultLocale;
        return Locale(pref == 'hi' ? 'hi' : 'en');
      },
      home: const SplashScreen(),
    );
  }
}
