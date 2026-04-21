import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../services/remote_config_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final msg = RemoteConfigService.forceUpdateMessage.isNotEmpty
        ? RemoteConfigService.forceUpdateMessage
        : 'A new version of the app is required to continue.';
    final changelog = RemoteConfigService.updateChangelog;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.system_update, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(msg, textAlign: TextAlign.center),
                if (changelog.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(changelog, style: const TextStyle(fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _openStore,
                  child: const Text('Update now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
}
