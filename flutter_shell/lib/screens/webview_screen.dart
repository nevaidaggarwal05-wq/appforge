import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController _controller;
  bool _loading = true;
  bool _showSoftUpdate = false;

  @override
  void initState() {
    super.initState();
    _buildController();

    NotificationService.deepLinkUrl.addListener(_onDeepLink);
    _maybeEvaluateSoftUpdate();
    _maybePromptRating();
  }

  @override
  void dispose() {
    NotificationService.deepLinkUrl.removeListener(_onDeepLink);
    super.dispose();
  }

  void _buildController() {
    final startUrl = _resolveStartUrl();
    final params = const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onJsBridgeMessage,
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) async {
          setState(() => _loading = false);
          await _injectBridge();
          await _injectDarkModeClass();
          await _injectViewportLock();
          SessionService.saveLastUrl(url);
        },
        onNavigationRequest: _onNavigationRequest,
        onWebResourceError: (e) => Log.w('[webview] ${e.description}'),
      ))
      ..loadRequest(Uri.parse(startUrl));
  }

  String _resolveStartUrl() {
    final url = RemoteConfigService.appUrl;
    return url.isEmpty ? 'about:blank' : url;
  }

  // ── Navigation intercept ────────────────────────────────────────

  Future<NavigationDecision> _onNavigationRequest(NavigationRequest req) async {
    final url = req.url;
    final uri = Uri.tryParse(url);
    if (uri == null) return NavigationDecision.navigate;

    // tel: / mailto: / sms: / upi:
    if (uri.scheme == 'tel' || uri.scheme == 'mailto' || uri.scheme == 'sms' ||
        uri.scheme == 'upi') {
      _launchExternal(uri);
      return NavigationDecision.prevent;
    }

    // UPI intents (Android intent:// form)
    if (uri.scheme == 'intent' && url.contains('upi')) {
      _launchExternal(uri);
      return NavigationDecision.prevent;
    }

    // Same host → stay in webview; different host → external browser
    final configured = Uri.tryParse(RemoteConfigService.appUrl);
    if (configured != null &&
        configured.host.isNotEmpty &&
        uri.host.isNotEmpty &&
        uri.host != configured.host) {
      _launchExternal(uri);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.w('[webview] launchUrl failed: $e');
    }
  }

  // ── JS bridge ──────────────────────────────────────────────────

  static const _bridgeJs = r'''
    (function(){
      if (window.flutter && window.flutter.__installed) return;
      function send(obj){ try { FlutterBridge.postMessage(JSON.stringify(obj)); } catch(e){} }
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

  Future<void> _injectBridge() async {
    try {
      await _controller.runJavaScript(_bridgeJs);
    } catch (e) {
      Log.w('[bridge] inject failed: $e');
    }
  }

  Future<void> _injectViewportLock() async {
    // Disable pinch-to-zoom inside the webview
    const js = r'''
      (function(){
        var m = document.querySelector('meta[name=viewport]');
        if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
        m.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      })();
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _injectDarkModeClass() async {
    final enabled = RemoteConfigService.darkModeEnabled;
    final js = '''
      (function(){
        try { document.documentElement.classList.${enabled ? "add" : "remove"}('app-dark-mode'); } catch(e){}
      })();
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _onJsBridgeMessage(JavaScriptMessage m) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(m.message) as Map<String, dynamic>;
    } catch (_) {
      Log.w('[bridge] bad JSON: ${m.message}');
      return;
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
        final wa   = Uri.parse('https://wa.me/?text=$msg');
        await _launchExternal(wa);
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
  }

  Future<void> _callJsBiometricResult(bool success) async {
    final js = '''
      (function(){
        if (typeof window._biometricResult === 'function') {
          try { window._biometricResult(${success ? 'true' : 'false'}); } catch(e){}
        }
      })();
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _tryUpiIntents(String params) async {
    // Try gpay, phonepe, paytm, generic upi — first one that launches wins.
    final candidates = <String>[
      'tez://upi/pay?$params',            // Google Pay
      'phonepe://pay?$params',            // PhonePe
      'paytmmp://pay?$params',            // Paytm
      'upi://pay?$params',                // generic UPI
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

  // ── Push deep link ─────────────────────────────────────────────

  void _onDeepLink() {
    final url = NotificationService.deepLinkUrl.value;
    if (url == null || url.isEmpty) return;
    _controller.loadRequest(Uri.parse(url));
    NotificationService.deepLinkUrl.value = null;
  }

  // ── Soft update + rating ────────────────────────────────────────

  Future<void> _maybeEvaluateSoftUpdate() async {
    final device = await DeviceInfoService.load();
    final minCode = RemoteConfigService.softUpdateVersion;
    if (minCode > 0 && device.buildNumber < minCode) {
      if (!mounted) return;
      setState(() => _showSoftUpdate = true);
    }
  }

  Future<void> _maybePromptRating() async {
    // Give the page a moment to settle before asking
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;
    await RatingService.maybePrompt();
  }

  // ── Back / refresh ─────────────────────────────────────────────

  Future<void> _onPopInvoked(bool didPop, Object? _) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _refresh() async {
    await _controller.reload();
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (RemoteConfigService.screenshotBlock && !kIsWeb) {
      // Android FLAG_SECURE is set in MainActivity.kt; iOS handles via
      // AppDelegate. No extra Dart-side work here.
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: WebViewWidget(controller: _controller),
                    ),
                  ],
                ),
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
