import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

class DeviceSnapshot {
  final String platform;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final int    buildNumber;
  final String deviceId;

  const DeviceSnapshot({
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'platform':     platform,
        'device_model': deviceModel,
        'os_version':   osVersion,
        'app_version':  appVersion,
        'build_number': buildNumber,
        'device_id':    deviceId,
      };
}

class DeviceInfoService {
  static DeviceSnapshot? _cached;

  static Future<DeviceSnapshot> load() async {
    if (_cached != null) return _cached!;

    String platform = 'unknown';
    String model = 'unknown';
    String osVersion = 'unknown';
    String deviceId = '';

    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
        final a = await info.androidInfo;
        model = a.model;
        osVersion = 'Android ${a.version.release}';
        deviceId = a.id;
      } else if (Platform.isIOS) {
        platform = 'ios';
        final i = await info.iosInfo;
        model = i.utsname.machine;
        osVersion = '${i.systemName} ${i.systemVersion}';
        deviceId = i.identifierForVendor ?? '';
      }
    } catch (e) {
      Log.w('[device_info] failed: $e');
    }

    String appVersion = '0.0.0';
    int buildNumber = 0;
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
      buildNumber = int.tryParse(pkg.buildNumber) ?? 0;
    } catch (e) {
      Log.w('[package_info] failed: $e');
    }

    _cached = DeviceSnapshot(
      platform:    platform,
      deviceModel: model,
      osVersion:   osVersion,
      appVersion:  appVersion,
      buildNumber: buildNumber,
      deviceId:    deviceId,
    );
    return _cached!;
  }
}
