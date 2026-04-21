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
    final msg = AppConfig.whatsappShareMessage;
    final url = RemoteConfigService.appUrl;
    final encoded = Uri.encodeComponent('$msg $url');
    final uri = Uri.parse('https://wa.me/?text=$encoded');
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
