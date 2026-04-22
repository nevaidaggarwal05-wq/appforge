import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../services/haptic_service.dart';
import '../services/remote_config_service.dart';
import '../utils/logger.dart';

class WhatsappShareButton extends StatelessWidget {
  const WhatsappShareButton({super.key});

  Future<void> _share() async {
    await HapticService.light();
    // Prefer admin-configured message + number; fall back to compile-time defaults
    final remoteMsg = RemoteConfigService.whatsappMessage;
    final msg       = remoteMsg.isNotEmpty ? remoteMsg : AppConfig.whatsappShareMessage;
    final url       = RemoteConfigService.appUrl;
    final number    = RemoteConfigService.whatsappNumber ?? '';
    final encoded   = Uri.encodeComponent('$msg $url');
    final uri = Uri.parse(number.isNotEmpty
        ? 'https://wa.me/$number?text=$encoded'
        : 'https://wa.me/?text=$encoded');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.w('[whatsapp] launch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'whatsapp-fab',
      backgroundColor: const Color(0xFF25D366),
      onPressed: _share,
      child: const Icon(Icons.chat, color: Colors.white),
    );
  }
}
