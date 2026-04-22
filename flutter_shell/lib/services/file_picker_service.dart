// ═══════════════════════════════════════════════════════════════
// Unified picker for <input type=file> + JS bridge uploads.
// - Images: image_picker (gallery/camera) + flutter_image_compress
// - Other types: file_picker
// Returns a list of local file paths the WebView can consume.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'remote_config_service.dart';

class FilePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick + compress one image from gallery. Returns local path or null.
  static Future<String?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 100);
      if (picked == null) return null;
      return await _compress(File(picked.path));
    } catch (e) {
      Log.e('[filepicker] pickImage failed: $e');
      return null;
    }
  }

  /// Multi-image picker (gallery only).
  static Future<List<String>> pickMultiImage() async {
    try {
      final list = await _picker.pickMultiImage(imageQuality: 100);
      final out = <String>[];
      for (final x in list) {
        final compressed = await _compress(File(x.path));
        if (compressed != null) out.add(compressed);
      }
      return out;
    } catch (e) {
      Log.e('[filepicker] pickMultiImage failed: $e');
      return const [];
    }
  }

  /// Pick arbitrary files (documents, video, audio…).
  static Future<List<String>> pickFiles({List<String>? extensions, bool multiple = true}) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: extensions == null ? FileType.any : FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: multiple,
      );
      if (res == null) return const [];
      return res.files.where((f) => f.path != null).map((f) => f.path!).toList();
    } catch (e) {
      Log.e('[filepicker] pickFiles failed: $e');
      return const [];
    }
  }

  /// Best-effort JPEG recompression if the file is larger than the admin limit.
  /// Skips PNG/WebP/HEIC to preserve transparency and non-photo quality.
  static Future<String?> _compress(File src) async {
    try {
      final sizeKb = (await src.length()) ~/ 1024;
      final maxKb  = RemoteConfigService.uploadMaxImageKb;
      final quality = RemoteConfigService.uploadImageQuality.clamp(30, 100);

      if (sizeKb <= maxKb) return src.path;

      final lower = src.path.toLowerCase();
      if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) {
        return src.path; // don't touch non-JPEG
      }

      final tmpDir = await getTemporaryDataDir();
      final out    = '${tmpDir.path}/upl_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        src.absolute.path,
        out,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return result?.path ?? src.path;
    } catch (e) {
      Log.w('[filepicker] compression failed, using original: $e');
      return src.path;
    }
  }

  static Future<Directory> getTemporaryDataDir() async {
    final d = await getTemporaryDirectory();
    return d;
  }
}
