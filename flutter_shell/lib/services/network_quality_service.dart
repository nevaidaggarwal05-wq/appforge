import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../utils/logger.dart';

enum NetworkQuality { none, slow, ok }

class NetworkQualityService {
  static final Connectivity _conn = Connectivity();

  static Future<bool> isOnline() async {
    try {
      final results = await _conn.checkConnectivity();
      return !results.contains(ConnectivityResult.none) && results.isNotEmpty;
    } catch (e) {
      Log.w('[net] isOnline failed: $e');
      return true;
    }
  }

  static Future<NetworkQuality> current() async {
    try {
      final results = await _conn.checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return NetworkQuality.none;
      }
      if (results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi)) {
        return NetworkQuality.slow;
      }
      return NetworkQuality.ok;
    } catch (_) {
      return NetworkQuality.ok;
    }
  }

  static Stream<NetworkQuality> watch() {
    return _conn.onConnectivityChanged.map((results) {
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return NetworkQuality.none;
      }
      if (results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi)) {
        return NetworkQuality.slow;
      }
      return NetworkQuality.ok;
    });
  }
}
