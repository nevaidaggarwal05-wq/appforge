// ═══════════════════════════════════════════════════════════════
// AdmobBanner — renders a 320×50 banner driven by RemoteConfigService.
//
// • Reads the unit ID from RemoteConfigService.admobBannerUnitId, which
//   prefers the admin-panel value and falls back to the build-time
//   AppConfig constant. Change the unit ID in admin panel → next config
//   refresh applies on next cold start (offline-first config pattern).
// • Reserves a 50dp slot while loading so the WebView doesn't reflow
//   when the ad fills.
// • Disposes cleanly. AdMob fail-to-load is logged but never throws —
//   network blips or unfilled inventory should never crash the shell.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/remote_config_service.dart';
import '../utils/logger.dart';

class AdmobBanner extends StatefulWidget {
  const AdmobBanner({super.key});

  @override
  State<AdmobBanner> createState() => _AdmobBannerState();
}

class _AdmobBannerState extends State<AdmobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return; // google_mobile_ads has no web impl
    _load();
  }

  void _load() {
    final unitId = RemoteConfigService.admobBannerUnitId;
    if (unitId.isEmpty) {
      Log.w('[admob] no banner unit id; skipping load');
      return;
    }
    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          Log.w('[admob] banner failed to load: ${err.code} ${err.message}');
          ad.dispose();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reserve space immediately so the WebView lays out at its final
    // height — avoids a visible reflow when the ad fills a moment later.
    if (!_loaded || _ad == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
