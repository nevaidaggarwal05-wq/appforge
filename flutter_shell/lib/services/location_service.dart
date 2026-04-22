// ═══════════════════════════════════════════════════════════════
// Geolocation bridge. Two paths:
//   1. InAppWebView's onGeolocationPermissionsShowPrompt — HTML5
//      navigator.geolocation.* goes through the native WebView
//      and we just grant/deny based on the permission flag.
//   2. window.flutter.getLocation() — JS bridge that returns a
//      single one-shot fix via geolocator (bypasses WebView).
// ═══════════════════════════════════════════════════════════════

import 'package:geolocator/geolocator.dart';

import '../utils/logger.dart';

class LocationService {
  /// Request runtime permission and obtain a one-shot fix.
  /// Returns null if denied / disabled / error.
  static Future<Map<String, dynamic>?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        Log.w('[location] service disabled');
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        Log.w('[location] permission denied');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
      return {
        'latitude':         pos.latitude,
        'longitude':        pos.longitude,
        'accuracy':         pos.accuracy,
        'altitude':         pos.altitude,
        'heading':          pos.heading,
        'speed':            pos.speed,
        'timestamp_millis': pos.timestamp.millisecondsSinceEpoch,
      };
    } catch (e) {
      Log.e('[location] getCurrentPosition failed: $e');
      return null;
    }
  }
}
