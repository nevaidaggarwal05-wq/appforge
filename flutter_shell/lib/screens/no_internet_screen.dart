import 'package:flutter/material.dart';

import '../services/network_quality_service.dart';
import 'splash_screen.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No internet connection',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your Wi-Fi or mobile data and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final online = await NetworkQualityService.isOnline();
                    if (!context.mounted) return;
                    if (online) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Still offline')),
                      );
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
