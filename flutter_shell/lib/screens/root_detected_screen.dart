import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RootDetectedScreen extends StatelessWidget {
  const RootDetectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.security, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Device not supported',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'For your security, this app cannot run on rooted or '
                  'jailbroken devices.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Close app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
