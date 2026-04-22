// ═══════════════════════════════════════════════════════════════
// QR / barcode scanner. Presented as a full-screen modal.
// Called from window.flutter.scanQR() JS bridge.
// Returns the first successful scan as a string, or null on cancel.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerService {
  static Future<String?> scan(BuildContext context) async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) return null;

    if (!context.mounted) return null;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerScreen()),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan QR code', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on, color: Colors.white),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_done) return;
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code == null || code.isEmpty) return;
          _done = true;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
