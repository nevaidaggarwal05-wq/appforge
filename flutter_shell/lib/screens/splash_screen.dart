import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/remote_config_service.dart';
import '../utils/color_utils.dart';
import 'bootstrap_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _advance();
  }

  Future<void> _advance() async {
    // Splash is shown for a fixed short interval OR until the bootstrap is
    // ready to decide (whichever is longer). The BootstrapScreen does its
    // own parallel work once shown.
    final duration = Duration(milliseconds: AppConfig.splashDurationMs);
    await Future.delayed(duration);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BootstrapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use cached config colors if available, else fallback
    final bg = ColorUtils.fromHexOr(
      RemoteConfigService.splashColor,
      ColorUtils.fromHexOr(AppConfig.fallbackThemeColor, Colors.black),
    );
    final textLight = _isDark(bg);

    final label = RemoteConfigService.splashText;
    final logo  = RemoteConfigService.splashLogoUrl;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (logo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  logo,
                  width: 96,
                  height: 96,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (RemoteConfigService.splashEnabled) ...[
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  color: textLight ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(textLight ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDark(Color c) {
    // c.r/g/b are 0..1 doubles in current Flutter
    final y = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return y < 0.627;
  }
}
