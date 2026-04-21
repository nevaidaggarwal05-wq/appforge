import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';

class InAppUpdateBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const InAppUpdateBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  Future<void> _openStore() async {
    String url;
    if (!kIsWeb && Platform.isIOS) {
      url = AppConfig.appStoreUrl;
    } else {
      url = AppConfig.playStoreUrl;
    }
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final display = message.isNotEmpty
        ? message
        : 'A new version is available.';
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.system_update, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(display)),
            TextButton(onPressed: _openStore, child: const Text('Update')),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onDismiss,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
