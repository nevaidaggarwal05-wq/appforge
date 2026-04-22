// ═══════════════════════════════════════════════════════════════
// WebView screen — flutter_inappwebview based.
//
// Why InAppWebView and not webview_flutter:
//   • Native SwipeRefreshLayout on Android (webview_flutter's
//     RefreshIndicator + ListView wrapper breaks position:fixed and
//     sticky headers/footers — that was the #1 reported bug)
//   • Full shouldOverrideUrlLoading with intent:// + market:// support
//     (needed for Razorpay's intent://…#Intent;package=…;end payloads)
//   • InAppWebViewController.clearCache / clearAllCache /
//     CookieManager.deleteAllCookies — needed for remote cache-clear
//   • Direct `supportZoom` + `builtInZoomControls` switches for the
//     admin-toggleable "pinch to zoom" flag
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/storage/cache_service.dart';
import '../services/analytics_service.dart';
import '../services/biometric_service.dart';
import '../services/device_info_service.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/rating_service.dart';
import '../services/remote_config_service.dart';
import '../services/session_service.dart';
import '../utils/logger.dart';
import '../widgets/in_app_update_banner.dart';
import '../widgets/whatsapp_share_button.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;

  bool _loading = true;
  bool _showSoftUpdate = false;

  @override
  void initState() {
    super.initState();

    // Wire native SwipeRefreshLayout only if admin-enabled. The controller
    // has to be constructed here (not in build) because InAppWebView captures
    // it during PlatformView creation.
    if (RemoteConfigService.pullToRefresh) {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
          color: _parseColorHex(RemoteConfigService.themeColor),
        ),
        onRefresh: () async {
          if (defaultTargetPlatform == TargetPlatform.android) {
            await _controller?.reload();
          } else {
            final url = await _controller?.getUrl();
            if (url != null) {
              await _controller?.loadUrl(urlRequest: URLRequest(url: url));
            }
          }
        },
      );
    }

    NotificationService.deepLinkUrl.addListener(_onDeepLink);
    _maybeEvaluateSoftUpdate();
    _maybePromptRating();
    _maybeApplyRemoteCacheClear();
  }

  @override
  void dispose() {
    NotificationService.deepLinkUrl.removeListener(_onDeepLink);
    super.dispose();
  }

  String _resolveStartUrl() {
    final url = RemoteConfigService.appUrl;
    return url.isEmpty ? 'about:blank' : url;
  }

  Color _parseColorHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF1DBF98);
  }

  // ── Remote cache clear ─────────────────────────────────────────
  // Compares server-provided timestamps against locally-recorded ones.
  // Runs on boot and on every config refresh push.

  Future<void> _maybeApplyRemoteCacheClear() async {
    final hardAt = RemoteConfigService.cacheHardClearAt;
    final softAt = RemoteConfigService.cacheSoftClearAt;

    final lastHard = await CacheService.lastHardClearApplied();
    final lastSoft = await CacheService.lastSoftClearApplied();

    // Hard clear takes precedence — also implies soft.
    if (hardAt != null && (lastHard == null || hardAt.isAfter(lastHard))) {
      await _runHardClear();
      await CacheService.recordHardClearApplied(hardAt);
      if (softAt != null) await CacheService.recordSoftClearApplied(softAt);
      return;
    }

    if (softAt != null && (lastSoft == null || softAt.isAfter(lastSoft))) {
      await _runSoftClear();
      await CacheService.recordSoftClearApplied(softAt);
    }
  }

  Future<void> _runSoftClear() async {
    try {
      await InAppWebViewController.clearAllCache();
      Log.i('[cache] soft clear applied');
    } catch (e) {
      Log.w('[cache] soft clear failed: $e');
    }
  }

  Future<void> _runHardClear() async {
    try {
      await InAppWebViewController.clearAllCache();
      await CookieManager.instance().deleteAllCookies();
      await SessionService.clearSession();
      Log.i('[cache] hard clear applied');
    } catch (e) {
      Log.w('[cache] hard clear failed: $e');
    }
  }

  // ── Navigation intercept ───────────────────────────────────────
  //
  // Covers:
  //   • tel:/mailto:/sms:    → hand to OS
  //   • upi:                 → OS picker
  //   • intent://…           → decode + resolve package/fallback URL
  //                            (this is the Razorpay/PhonePe path)
  //   • market://            → Play Store
  //   • different host       → external browser
  //   • everything else      → keep in WebView

  Future<NavigationActionPolicy?> _onNavRequest(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    final url = uri.toString();

    // Simple handoff schemes
    if (uri.scheme == 'tel' ||
        uri.scheme == 'mailto' ||
        uri.scheme == 'sms' ||
        uri.scheme == 'upi') {
      await _launchExternal(uri.rawValue);
      return NavigationActionPolicy.CANCEL;
    }

    // Play Store
    if (uri.scheme == 'market' || url.startsWith('https://play.google.com/store/apps')) {
      await _launchExternal(uri.rawValue);
      return NavigationActionPolicy.CANCEL;
    }

    // Android intent:// — Razorpay UPI intent flow, PhonePe app links, etc.
    if (uri.scheme == 'intent') {
      await _handleAndroidIntent(url);
      return NavigationActionPolicy.CANCEL;
    }

    // External host → launch browser / third-party app
    final configured = Uri.tryParse(RemoteConfigService.appUrl);
    if (configured != null &&
        configured.host.isNotEmpty &&
        uri.host.isNotEmpty &&
        !_sameOrSubHost(uri.host, configured.host)) {
      await _launchExternal(uri.rawValue);
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  bool _sameOrSubHost(String a, String b) {
    final aa = a.toLowerCase();
    final bb = b.toLowerCase();
    return aa == bb || aa.endsWith('.$bb') || bb.endsWith('.$aa');
  }

  /// Parses Android's intent:// URI. Tries:
  ///   1. The target package directly (intent has `package=...;`)
  ///   2. Google Pay / PhonePe / Paytm / generic UPI app (if it's a UPI intent)
  ///   3. The `S.browser_fallback_url` if provided
  Future<void> _handleAndroidIntent(String url) async {
    try {
      // On Android, delegating to the OS with the raw intent:// URI is the
      // correct path — the OS resolves the Intent itself.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      }

      // Extract useful bits as a fallback.
      final lower = url.toLowerCase();

      // Pull S.browser_fallback_url if present
      final fallbackRe = RegExp(r'S\.browser_fallback_url=([^;]+);', caseSensitive: false);
      final fallbackMatch = fallbackRe.firstMatch(url);
      if (fallbackMatch != null) {
        final decoded = Uri.decodeComponent(fallbackMatch.group(1)!);
        if (await launchUrl(Uri.parse(decoded),
            mode: LaunchMode.externalApplication)) return;
      }

      // UPI intents → try the common Indian UPI apps
      if (lower.contains('upi') ||
          lower.contains('paisa.user') ||
          lower.contains('phonepe') ||
          lower.contains('paytm')) {
        await _tryUpiIntents(_extractQueryAfterPath(url));
        return;
      }

      Log.w('[intent] could not resolve: $url');
    } catch (e) {
      Log.w('[intent] resolver threw: $e');
    }
  }

  String _extractQueryAfterPath(String intentUrl) {
    // intent://pay?pa=xxx&am=10#Intent;scheme=upi;package=...;end
    final q = intentUrl.indexOf('?');
    final hash = intentUrl.indexOf('#');
    if (q < 0) return '';
    final end = (hash < 0) ? intentUrl.length : hash;
    return intentUrl.substring(q + 1, end);
  }

  Future<void> _launchExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.w('[webview] launchUrl failed: $e');
    }
  }

  // ── UPI helper (also invoked from JS bridge) ───────────────────

  Future<void> _tryUpiIntents(String params) async {
    final candidates = <String>[
      'tez://upi/pay?$params',         // Google Pay
      'phonepe://pay?$params',         // PhonePe
      'paytmmp://pay?$params',         // Paytm
      'bhim://pay?$params',            // BHIM
      'upi://pay?$params',             // generic
    ];
    for (final raw in candidates) {
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}
    }
  }

  // ── JS bridge (handler registered on controller create) ────────

  static const _bridgeJs = r'''
    (function(){
      if (window.flutter && window.flutter.__installed) return;
      function send(obj){
        try { window.flutter_inappwebview.callHandler('FlutterBridge', obj); } catch(e){}
      }
      window.flutter = {
        __installed: true,
        haptic:    function(t)   { send({action:'haptic',   type: t || 'light'}); },
        biometric: function(r)   { send({action:'biometric',reason: r || 'Authenticate'}); },
        share:     function(t,u) { send({action:'share',    text: t || '', url: u || ''}); },
        openUPI:   function(p)   { send({action:'upi',      params: p || ''}); },
        track:     function(e,p) { send({action:'track',    event: e || '', props: p || {}}); }
      };
    })();
  ''';

  Future<dynamic> _onJsBridge(List<dynamic> args) async {
    if (args.isEmpty) return null;
    Map<String, dynamic> payload;
    try {
      final raw = args.first;
      payload = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      Log.w('[bridge] bad payload: ${args.first}');
      return null;
    }

    final action = payload['action'] as String?;
    switch (action) {
      case 'haptic':
        await HapticService.byTag(payload['type'] as String? ?? 'light');
        break;

      case 'biometric':
        if (!RemoteConfigService.biometricEnabled) {
          await _callJsBiometricResult(false);
          break;
        }
        final reason = payload['reason'] as String? ?? 'Authenticate';
        final ok = await BiometricService.authenticate(reason);
        await _callJsBiometricResult(ok);
        break;

      case 'share':
        final text = payload['text'] as String? ?? '';
        final url  = payload['url']  as String? ?? '';
        final msg  = Uri.encodeComponent([text, url].where((s) => s.isNotEmpty).join(' '));
        final number = RemoteConfigService.whatsappNumber ?? '';
        final wa   = number.isNotEmpty
            ? Uri.parse('https://wa.me/$number?text=$msg')
            : Uri.parse('https://wa.me/?text=$msg');
        await _launchExternal(wa.toString());
        break;

      case 'upi':
        final params = payload['params'] as String? ?? '';
        await _tryUpiIntents(params);
        break;

      case 'track':
        final event = payload['event'] as String? ?? '';
        final props = (payload['props'] as Map?)?.cast<String, dynamic>() ?? const {};
        if (event.isNotEmpty) {
          await AnalyticsService.log(event, props);
        }
        break;

      default:
        Log.w('[bridge] unknown action: $action');
    }
    return null;
  }

  Future<void> _callJsBiometricResult(bool success) async {
    final js = '''
      (function(){
        if (typeof window._biometricResult === 'function') {
          try { window._biometricResult(${success ? 'true' : 'false'}); } catch(e){}
        }
      })();
    ''';
    try { await _controller?.evaluateJavascript(source: js); } catch (_) {}
  }

  // ── JS injection on page load ──────────────────────────────────

  Future<void> _injectBridge() async {
    try { await _controller?.evaluateJavascript(source: _bridgeJs); } catch (e) {
      Log.w('[bridge] inject failed: $e');
    }
  }

  Future<void> _injectDarkModeClass() async {
    final enabled = RemoteConfigService.darkModeEnabled;
    final js = '''
      (function(){
        try { document.documentElement.classList.${enabled ? "add" : "remove"}('app-dark-mode'); } catch(e){}
      })();
    ''';
    try { await _controller?.evaluateJavascript(source: js); } catch (_) {}
  }

  // NOTE: NO viewport-lock injection anymore. InAppWebView handles pinch/zoom
  // natively via `supportZoom` — overriding the page's viewport meta was
  // causing sticky headers to break on responsive sites.

  // ── Push deep link ─────────────────────────────────────────────

  void _onDeepLink() {
    final url = NotificationService.deepLinkUrl.value;
    if (url == null || url.isEmpty) return;
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    NotificationService.deepLinkUrl.value = null;
  }

  // ── Soft update + rating ───────────────────────────────────────

  Future<void> _maybeEvaluateSoftUpdate() async {
    final device = await DeviceInfoService.load();
    final minCode = RemoteConfigService.softUpdateVersion;
    if (minCode > 0 && device.buildNumber < minCode) {
      if (!mounted) return;
      setState(() => _showSoftUpdate = true);
    }
  }

  Future<void> _maybePromptRating() async {
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;
    await RatingService.maybePrompt();
  }

  // ── Back button ────────────────────────────────────────────────

  Future<void> _onPopInvoked(bool didPop, Object? _) async {
    if (didPop) return;
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final startUrl = _resolveStartUrl();
    final pinchZoom = RemoteConfigService.pinchToZoom;

    final initialSettings = InAppWebViewSettings(
      // Core
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      transparentBackground: false,
      // Android-specific
      useHybridComposition: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      // Zoom — flagged
      supportZoom: pinchZoom,
      builtInZoomControls: pinchZoom,
      displayZoomControls: false,
      // Scheme handling
      useShouldOverrideUrlLoading: true,
      // Cookies + session
      cacheEnabled: true,
      thirdPartyCookiesEnabled: true,
      // Mixed content (many payment iframes still use http subresources)
      mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
    );

    // iOS screenshot blocking is wired in AppDelegate.swift; Android via
    // FLAG_SECURE in MainActivity.kt. Nothing to do here at runtime.
    if (RemoteConfigService.screenshotBlock && !kIsWeb) {
      SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((_) => null);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // The raw InAppWebView — NO ListView/SizedBox wrapper.
              // That is the fix for scrolling + sticky headers/footers.
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(startUrl)),
                initialSettings: initialSettings,
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (c) {
                  _controller = c;
                  c.addJavaScriptHandler(
                    handlerName: 'FlutterBridge',
                    callback: _onJsBridge,
                  );
                },
                shouldOverrideUrlLoading: _onNavRequest,
                onLoadStart: (_, __) {
                  if (mounted) setState(() => _loading = true);
                },
                onLoadStop: (c, url) async {
                  if (mounted) setState(() => _loading = false);
                  _pullToRefreshController?.endRefreshing();
                  await _injectBridge();
                  await _injectDarkModeClass();
                  if (url != null) await SessionService.saveLastUrl(url.toString());
                },
                onProgressChanged: (_, p) {
                  if (p >= 100) _pullToRefreshController?.endRefreshing();
                },
                onReceivedError: (_, __, err) =>
                    Log.w('[webview] ${err.description}'),
                onReceivedHttpError: (_, __, err) =>
                    Log.w('[webview] http ${err.statusCode}: ${err.reasonPhrase}'),
              ),

              if (_loading)
                const Positioned(
                  top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              if (_showSoftUpdate)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: InAppUpdateBanner(
                    message: RemoteConfigService.softUpdateMessage,
                    onDismiss: () => setState(() => _showSoftUpdate = false),
                  ),
                ),

              if (RemoteConfigService.whatsappEnabled)
                const Positioned(
                  right: 16, bottom: 24,
                  child: WhatsappShareButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
