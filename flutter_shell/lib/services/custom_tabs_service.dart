// ═══════════════════════════════════════════════════════════════
// Chrome Custom Tabs (Android) / SFSafariViewController (iOS) for
// OAuth providers that refuse to log in inside a WebView:
//   - accounts.google.com, appleid.apple.com, login.microsoftonline.com
//   - anything in RemoteConfig.oauth.hosts
// The callback comes back via a custom URL scheme handled by app_links.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

import '../utils/color_utils.dart';
import '../utils/logger.dart';
import 'remote_config_service.dart';

Color _primary() => ColorUtils.fromHexOr(RemoteConfigService.themeColor, const Color(0xFF2563EB));

class CustomTabsService {
  /// Returns true if `uri` should open in a Custom Tab instead of the WebView.
  static bool shouldHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    final hosts = RemoteConfigService.oauthHosts.map((h) => h.toLowerCase()).toList();
    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }

  static Future<void> launch(BuildContext context, Uri uri) async {
    try {
      final primary = _primary();
      await launchUrl(
        uri,
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: primary,
          ),
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          showTitle: true,
          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: primary,
          preferredControlTintColor: Colors.white,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (e) {
      Log.e('[customtabs] launch failed: $e');
    }
  }
}
