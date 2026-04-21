import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_config.dart';
import '../utils/logger.dart';

// Top-level background handler — required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  Log.i('[fcm] background: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// WebViewScreen listens to this to navigate when a push deep link arrives.
  static final ValueNotifier<String?> deepLinkUrl = ValueNotifier<String?>(null);
  static String? fcmToken;
  static bool _initialized = false;

  /// Call from main() *before* runApp.
  static void registerBackgroundHandler() {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      Log.w('[fcm] background handler registration failed: $e');
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Local notifications (foreground display + tap handling)
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null && r.payload!.isNotEmpty) {
            deepLinkUrl.value = r.payload;
          }
        },
      );

      await _createAndroidChannels();

      // Permission
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      // Per-app topic — see docs/API_CONTRACT.md
      final topic = 'app_${AppConfig.appId.replaceAll("-", "_")}';
      await _subscribeSafely(topic);
      await _subscribeSafely('all_apps');
      await _subscribeSafely(AppConfig.notifChannelTransactional);
      await _subscribeSafely(AppConfig.notifChannelAlerts);
      await _subscribeSafely(AppConfig.notifChannelPromotional);

      fcmToken = await _messaging.getToken();
      Log.i('[fcm] token=${fcmToken?.substring(0, 12)}...');
      _messaging.onTokenRefresh.listen((t) {
        fcmToken = t;
        Log.i('[fcm] token refreshed');
      });

      FirebaseMessaging.onMessage.listen((m) {
        _showLocalNotification(m);
        _processDeepLink(m);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_processDeepLink);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        // Delay so WebViewScreen has time to mount its listener
        Future.delayed(const Duration(seconds: 1), () => _processDeepLink(initial));
      }
    } catch (e) {
      Log.e('[fcm] initialize failed: $e');
    }
  }

  static Future<void> _subscribeSafely(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      Log.w('[fcm] subscribe $topic failed: $e');
    }
  }

  static Future<void> _createAndroidChannels() async {
    if (kIsWeb) return;
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final id in [
      AppConfig.notifChannelTransactional,
      AppConfig.notifChannelAlerts,
      AppConfig.notifChannelPromotional,
    ]) {
      await android.createNotificationChannel(AndroidNotificationChannel(
        id,
        id[0].toUpperCase() + id.substring(1),
        importance: Importance.high,
      ));
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    final channelId = (m.data['category'] as String?) ?? AppConfig.notifChannelTransactional;
    final payload = m.data['url'] as String?;

    await _local.show(
      m.messageId.hashCode,
      n.title ?? '',
      n.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId[0].toUpperCase() + channelId.substring(1),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  static void _processDeepLink(RemoteMessage m) {
    final url = m.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      deepLinkUrl.value = url;
    }
  }
}
