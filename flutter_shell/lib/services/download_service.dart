// ═══════════════════════════════════════════════════════════════
// flutter_downloader wrapper.
// - Captures onDownloadStartRequest from InAppWebView and enqueues
//   a background download via the native DownloadManager (Android).
// - Shows a system notification for progress + tap-to-open.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

class DownloadService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
    _initialized = true;
  }

  /// Enqueue a download. Returns the task id or null on failure.
  static Future<String?> enqueue({
    required String url,
    required String fileName,
    Map<String, String>? headers,
  }) async {
    await initialize();

    // Android ≤ 9 writes to external storage; 10+ uses scoped storage automatically.
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      // If denied on Android 10+ we fall back to app-private Downloads dir.
      if (!storageStatus.isGranted) Log.i('[download] storage permission denied; using app sandbox');
    }

    final dir = await _resolveDir();
    if (dir == null) return null;

    try {
      final id = await FlutterDownloader.enqueue(
        url: url,
        savedDir: dir.path,
        fileName: fileName,
        headers: headers ?? const {},
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: Platform.isAndroid, // /storage/emulated/0/Download on Android
      );
      Log.i('[download] enqueued $fileName → id=$id');
      return id;
    } catch (e) {
      Log.e('[download] enqueue failed: $e');
      return null;
    }
  }

  static Future<Directory?> _resolveDir() async {
    try {
      if (Platform.isAndroid) {
        final d = Directory('/storage/emulated/0/Download');
        if (await d.exists()) return d;
      }
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getApplicationDocumentsDirectory();
    }
  }
}
