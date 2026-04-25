// ═══════════════════════════════════════════════════════════════
// WebView screen — flutter_inappwebview based.  v2 (migration 003)
//
// Why InAppWebView and not webview_flutter:
//   • Native SwipeRefreshLayout on Android (webview_flutter's
//     RefreshIndicator + ListView wrapper breaks position:fixed and
//     sticky headers/footers — that was the #1 reported bug)
//   • Full shouldOverrideUrlLoading with intent:// + market:// support
//     (needed for Razorpay's intent://…#Intent;package=…;end payloads)
//   • onShowFileChooser / onDownloadStartRequest /
//     onGeolocationPermissionsShowPrompt / onPermissionRequest callbacks
//   • onRenderProcessGone — lets us recover from WebView OOM crashes
//   • InAppWebViewController.clearCache / clearAllCache /
//     CookieManager.deleteAllCookies — needed for remote cache-clear
//   • Direct `supportZoom` + `builtInZoomControls` switches for the
//     admin-toggleable "pinch to zoom" flag
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/storage/cache_service.dart';
import '../services/analytics_service.dart';
import '../services/biometric_service.dart';
import '../services/clipboard_service.dart';
import '../services/custom_tabs_service.dart';
import '../services/device_info_service.dart';
import '../services/download_service.dart';
import '../services/haptic_service.dart';
import '../services/intent_bridge_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/rating_service.dart';
import '../services/remote_config_service.dart';
import '../services/scanner_service.dart';
import '../services/secure_storage_service.dart';
import '../services/session_service.dart';
import '../services/share_service.dart';
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
  double _progress = 0;
  bool _showSoftUpdate = false;
  Timer? _loadTimeoutTimer;
  bool _timedOut = false;

  // Cleaned User-Agent. We strip the "; wv" WebView marker so payment
  // gateways (Razorpay, PhonePe, etc.) stop hiding UPI intent options —
  // their JS uses that substring to decide "this is a default WebView,
  // can't launch intent:// URIs" and collapses the UPI section. Our
  // WebView *can* resolve intent:// via shouldOverrideUrlLoading, so
  // the detection is a false positive for us.
  String? _userAgent;

  @override
  void initState() {
    super.initState();

    _prepareUserAgent();

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
    DownloadService.initialize();
    _maybeEvaluateSoftUpdate();
    _maybePromptRating();
    _maybeApplyRemoteCacheClear();
  }

  @override
  void dispose() {
    NotificationService.deepLinkUrl.removeListener(_onDeepLink);
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }

  /// Build a user-agent string that payment gateways accept as "real
  /// Chrome". The default Android WebView UA contains a `"; wv"` marker
  /// that causes Razorpay and similar JS to hide UPI intent options
  /// (their logic: "this is a WebView, it can't resolve intent://").
  /// Ours CAN — see `_handleAndroidIntent` — so we strip the marker.
  ///
  /// Always synthesize a clean Chrome UA. We do NOT trust the platform
  /// default — Android WebView includes both `; wv` AND `Version/4.0`
  /// tokens, either of which Razorpay uses to detect a WebView and
  /// hide UPI options. Sanitizing the platform string is a losing
  /// game; a fresh Chrome-shaped UA is bulletproof.
  Future<void> _prepareUserAgent() async {
    String androidVersion = '14';
    String model = 'Android';
    try {
      final device = await DeviceInfoService.load();
      androidVersion = device.osVersion.replaceFirst('Android ', '').trim();
      if (androidVersion.isEmpty) androidVersion = '14';
      if (device.deviceModel.isNotEmpty) model = device.deviceModel;
    } catch (e) {
      Log.w('[webview] DeviceInfo.load failed, using fallback UA: $e');
    }

    // Chrome for Android UA shape. No `wv`, no `Build/…`, no `Version/4.0`.
    // Version pinned to a recent stable — gateways only care that this
    // IS Chrome, not the exact build number.
    String ua = 'Mozilla/5.0 (Linux; Android $androidVersion; $model) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/124.0.6367.179 Mobile Safari/537.36';

    final suffix = RemoteConfigService.userAgentSuffix ?? '';
    if (suffix.isNotEmpty) ua = '$ua $suffix';

    if (!mounted) return;
    setState(() => _userAgent = ua);
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
      await SecureStorageService.clear();
      Log.i('[cache] hard clear applied');
    } catch (e) {
      Log.w('[cache] hard clear failed: $e');
    }
  }

  // ── Navigation intercept ───────────────────────────────────────
  //
  // Policy (intentionally unopinionated):
  //   • http/https  → ALWAYS load in the WebView. No host allowlist,
  //                   no automatic OAuth/CustomTabs handoff, no
  //                   external-browser kick-outs. If a payment flow
  //                   redirects to a bank's 3-D Secure page on some
  //                   random domain, it loads right here. If the user
  //                   ever gets stuck, they kill and relaunch — that's
  //                   the product's stated UX rule.
  //   • intent://   → Android Intent resolver (UPI apps, PhonePe deep
  //                   links, etc.) — resolved via _handleAndroidIntent.
  //   • any other   → hand off to the OS (tel, mailto, sms, upi,
  //                   market, whatsapp, fb, custom app schemes, …).
  //
  // CustomTabsService is intentionally NOT invoked automatically any
  // more. The `window.flutter.openCustomTab(url)` JS bridge method
  // still exists for websites that want to opt in explicitly.

  Future<NavigationActionPolicy?> _onNavRequest(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return NavigationActionPolicy.ALLOW;
    }

    if (uri.scheme == 'intent') {
      await _handleAndroidIntent(uri.toString());
      return NavigationActionPolicy.CANCEL;
    }

    // tel / mailto / sms / upi / market / whatsapp / fb / any custom scheme
    await _launchExternal(uri.rawValue);
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _handleAndroidIntent(String url) async {
    // Primary path: native Intent.parseUri via MainActivity method
    // channel. This is the ONLY way `intent://…#Intent;…;end` URIs
    // (GPay, PhonePe, bank deep links, Razorpay's UPI app-chooser)
    // actually dispatch — `url_launcher` can't parse that scheme and
    // silently returns false, which was the root cause of v1.2.3+10's
    // "UPI icons show but do nothing when tapped" bug.
    //
    // Returns true when an activity launched, including via
    // browser_fallback_url or Play Store fallback — so we only fall
    // through to the legacy synth-upi path if the native bridge is
    // genuinely unreachable (iOS, or the channel wasn't registered).
    try {
      if (await IntentBridgeService.launchIntent(url)) return;
    } catch (e) {
      Log.w('[intent] native bridge threw: $e');
    }

    // Legacy fallback — kept for safety. Only exercised if native
    // bridge above reports false. Extracts S.browser_fallback_url by
    // regex and, as a last resort, tries to re-synthesize common UPI
    // schemes from the query so an installed UPI app can pick it up.
    try {
      final fallbackRe = RegExp(
        r'S\.browser_fallback_url=([^;]+);',
        caseSensitive: false,
      );
      final fallbackMatch = fallbackRe.firstMatch(url);
      if (fallbackMatch != null) {
        final decoded = Uri.decodeComponent(fallbackMatch.group(1)!);
        if (await launchUrl(
          Uri.parse(decoded),
          mode: LaunchMode.externalApplication,
        )) return;
      }

      final lower = url.toLowerCase();
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
      'tez://upi/pay?$params',
      'phonepe://pay?$params',
      'paytmmp://pay?$params',
      'bhim://pay?$params',
      'upi://pay?$params',
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

  // ── window.open shim (document-start) ──────────────────────────
  //
  // Razorpay's UPI-icon click handler does roughly:
  //
  //     var w = window.open('');              // empty URL
  //     w.location = 'intent://...#Intent;...';
  //
  // In a real browser, window.open('') returns a Window reference;
  // you can then assign `.location` to fire an intent. Android WebView
  // returns `null` from the native window.open, so Razorpay's next
  // line throws "Cannot set property 'location' of null" and the UPI
  // icon silently does nothing — the exact symptom reported on
  // v1.2.4+11 (log: `win.open GET (body=0) ::` with empty URL).
  //
  // The shim replaces `window.open` so it ALWAYS returns a proxy
  // object. Assigning `.location = "intent://..."` on that proxy
  // routes the URL back through our FlutterBridge `dispatchUrl`
  // action, which calls the native Intent.parseUri bridge. Injected
  // at DOCUMENT_START so it runs before any Razorpay code.
  //
  // For http(s) URLs we still delegate to the native window.open so
  // `onCreateWindow` fires and the page loads in our WebView.
  static final _openShim = UserScript(
    source: r'''
      (function(){
        if (window.__flutter_open_shim) return;
        window.__flutter_open_shim = true;
        var origOpen = window.open;
        function dispatch(url){
          try {
            if (!url) return;
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('FlutterBridge', {
                action: 'dispatchUrl', url: String(url)
              });
            } else {
              // Bridge not ready yet — retry after a tick.
              setTimeout(function(){ dispatch(url); }, 32);
            }
          } catch(e){}
        }
        function makePopupProxy(initialUrl){
          var _loc = String(initialUrl || '');
          var locationObj = {
            get href(){ return _loc; },
            set href(v){ _loc = String(v); dispatch(v); },
            assign:  function(v){ _loc = String(v); dispatch(v); },
            replace: function(v){ _loc = String(v); dispatch(v); },
            reload:  function(){},
            toString: function(){ return _loc; }
          };
          var proxy = {
            closed: false,
            close: function(){ this.closed = true; },
            focus: function(){},
            blur:  function(){},
            postMessage: function(){},
            opener: null,
            document: {
              write: function(){}, writeln: function(){},
              open:  function(){}, close:   function(){}
            }
          };
          try {
            Object.defineProperty(proxy, 'location', {
              configurable: true,
              get: function(){ return locationObj; },
              set: function(v){
                if (v && typeof v === 'object' && 'href' in v) {
                  locationObj.href = v.href;
                } else {
                  locationObj.href = String(v);
                }
              }
            });
          } catch(e){
            proxy.location = locationObj;
          }
          return proxy;
        }
        window.open = function(url, target, features){
          var u = url ? String(url) : '';
          try { console.log('[openShim] open ' + (u.length > 80 ? u.substring(0, 80) + '…' : u)); } catch(e){}
          // ANY non-empty, non-http(s)/about scheme → dispatch natively.
          // Covers intent:, upi:, gpay:, tez:, phonepe:, paytmmp:, bhim:,
          // market:, whatsapp:, tel:, mailto:, sms:, and anything new
          // Razorpay adds in the future.
          if (u.length > 0 && !/^https?:/i.test(u) && !/^about:/i.test(u)) {
            dispatch(u);
            return makePopupProxy(u);
          }
          // http(s): delegate to native so onCreateWindow loads it in
          // the same WebView.
          if (u.length > 0) {
            try {
              var real = origOpen ? origOpen.apply(window, arguments) : null;
              if (real) return real;
            } catch(e){}
            return makePopupProxy(u);
          }
          // Empty URL (Razorpay's popup-ref pattern). Never call native
          // window.open — it returns null and doesn't help us.
          return makePopupProxy('');
        };

        // ── Form-submission normalizer ──────────────────────────────
        // Two separate Razorpay patterns break in Android WebView:
        //
        //   (a) Detached form: they build a <form> but never append it
        //       to the DOM, then call form.submit(). WebView refuses
        //       ("Form submission canceled because the form is not
        //       connected"). Chrome tolerates this. Fix: auto-attach.
        //
        //   (b) target="_blank" form: even if the form IS connected,
        //       target="_blank" tells the browser to open a new tab
        //       for the POST. Android WebView doesn't do popups, so
        //       the POST is dropped on the floor. Fix: retarget to
        //       _self so the submission navigates the main WebView.
        //       Payment gateways' success/cancel URLs redirect back
        //       to the checkout origin, so this is safe.
        //
        // Both patches are needed because forms can be submitted either
        // programmatically (form.submit()) OR by user interaction with
        // a <button type="submit">. The prototype patch covers the
        // former; the capture-phase 'submit' event listener covers the
        // latter.
        function normalizeForm(form, origin){
          try {
            if (!form) return;
            var act = form.getAttribute && form.getAttribute('action');
            var tgt = form.getAttribute && form.getAttribute('target');
            var mth = form.getAttribute && form.getAttribute('method');
            console.log('[openShim] form.submit(' + (origin||'') + ') method=' + (mth||'GET') +
                        ' target=' + (tgt||'(unset)') + ' action=' +
                        (act ? (act.length > 80 ? act.substring(0,80)+'…' : act) : '(empty)'));
            if (!form.isConnected) {
              form.style.display = 'none';
              (document.body || document.documentElement).appendChild(form);
              console.log('[openShim]   ↳ attached detached form');
            }
            // Decide the right target. Razorpay checkout runs inside an
            // iframe (api.razorpay.com) on the merchant page. When it
            // submits a form targeting _self, the bank's response loads
            // inside that iframe — and every major bank sets
            // X-Frame-Options: sameorigin / CSP frame-ancestors 'self'
            // so the iframe load is blocked. In Chrome the form normally
            // targets _blank and opens a new tab (outside any iframe),
            // which works. We have no tabs, so we route to _top: the
            // bank replaces the whole WebView, user completes auth, and
            // the bank's redirect chain takes the WebView back to
            // Razorpay → merchant's success URL. Standard redirect-mode.
            //
            // Only upgrade cross-origin submissions. Same-origin form
            // submissions (e.g. merchant's own forms posting to
            // /api/login) should stay on _self so they don't blow away
            // surrounding Razorpay / merchant state.
            var needsTop = false;
            if (act) {
              try {
                var a = document.createElement('a');
                a.href = act;
                // Compare against TOP-level origin, not the iframe's.
                // `top.location.host` throws in cross-origin iframes —
                // fall back to current host in that case, which still
                // catches the Razorpay-iframe-submits-to-bank case.
                var topHost = location.host;
                try { if (top && top.location && top.location.host) topHost = top.location.host; } catch(e){}
                if (a.host && a.host !== location.host && a.host !== topHost) {
                  needsTop = true;
                }
              } catch(e){ needsTop = true; }
            }
            if (needsTop || tgt === '_blank') {
              if (tgt !== '_top') {
                form.setAttribute('target', '_top');
                console.log('[openShim]   ↳ retargeted ' + (tgt||'(unset)') + ' → _top');
              }
            }
          } catch(e){}
        }
        try {
          var origSubmit = HTMLFormElement.prototype.submit;
          HTMLFormElement.prototype.submit = function(){
            normalizeForm(this, 'proto');
            return origSubmit.apply(this, arguments);
          };
        } catch(e){}
        try {
          document.addEventListener('submit', function(e){
            normalizeForm(e.target, 'evt');
          }, true); // capture-phase, runs before the browser submits
        } catch(e){}
      })();
    ''',
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  // ── JS bridge ──────────────────────────────────────────────────

  static const _bridgeJs = r'''
    (function(){
      if (window.flutter && window.flutter.__installed) return;
      var pending = {};
      var nextId = 1;
      function call(action, extra){
        var id = nextId++;
        var payload = Object.assign({action: action, __id: id}, extra || {});
        return new Promise(function(resolve){
          pending[id] = resolve;
          try { window.flutter_inappwebview.callHandler('FlutterBridge', payload); }
          catch(e){ pending[id] = null; resolve(null); }
        });
      }
      // The native side calls window._flutterResolve(id, value)
      window._flutterResolve = function(id, value){
        var r = pending[id]; if (r){ delete pending[id]; try { r(value); } catch(e){} }
      };

      window.flutter = {
        __installed: true,
        // fire-and-forget
        haptic:      function(t)         { call('haptic',    {type: t || 'light'}); },
        track:       function(e, p)      { call('track',     {event: e || '', props: p || {}}); },
        share:       function(t, u)      { call('share',     {text: t || '', url: u || ''}); },
        shareSystem: function(t, u)      { call('shareSystem', {text: t || '', url: u || ''}); },
        openUPI:     function(params)    { call('upi',       {params: params || ''}); },
        openCustomTab: function(url)     { call('openCustomTab', {url: url || ''}); },
        copyText:    function(s)         { call('copyText',  {text: s || ''}); },
        logout:      function()          { call('logout'); },
        download:    function(url, fn)   { call('download',  {url: url || '', filename: fn || ''}); },
        secureDel:   function(k)         { call('secureDel', {key: k || ''}); },

        // async (return promises)
        biometric:       function(r)     { return call('biometric',   {reason: r || 'Authenticate'}); },
        scanQR:          function()      { return call('scanQR'); },
        getLocation:     function()      { return call('getLocation'); },
        readClipboard:   function()      { return call('readClipboard'); },
        secureSet:       function(k, v)  { return call('secureSet', {key: k || '', value: v || ''}); },
        secureGet:       function(k)     { return call('secureGet', {key: k || ''}); },
      };

      // device + fcmToken are injected by the native side; expose as getters.
      if (!window.flutter.device)    window.flutter.device    = window.__flutter_device    || {};
      if (!window.flutter.fcmToken)  window.flutter.fcmToken  = window.__flutter_fcmToken  || '';
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
    final id     = payload['__id'];
    dynamic result;

    switch (action) {
      case 'haptic':
        await HapticService.byTag(payload['type'] as String? ?? 'light');
        break;

      case 'biometric':
        if (!RemoteConfigService.biometricEnabled) {
          result = false;
          break;
        }
        final reason = payload['reason'] as String? ?? 'Authenticate';
        result = await BiometricService.authenticate(reason);
        // Legacy callback for pre-promise pages
        await _callJsBiometricResult(result == true);
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

      case 'shareSystem':
        await ShareService.share(
          text: payload['text'] as String?,
          url:  payload['url']  as String?,
        );
        break;

      case 'upi':
        await _tryUpiIntents(payload['params'] as String? ?? '');
        break;

      // Routed from the window.open shim. Razorpay (and similar
      // gateways) call `var w = window.open(''); w.location = url;` to
      // launch UPI intents — our shim intercepts the location assign
      // and dispatches here so the right native handler gets it.
      case 'dispatchUrl':
        final rawUrl = payload['url'] as String? ?? '';
        if (rawUrl.isEmpty) break;
        final dScheme = Uri.tryParse(rawUrl)?.scheme.toLowerCase() ?? '';
        if (dScheme == 'intent') {
          await _handleAndroidIntent(rawUrl);
        } else if (dScheme == 'http' || dScheme == 'https') {
          // Razorpay sometimes does window.open('') then .location=<web
          // URL> to navigate the popup. We have no popup — load it in
          // the main WebView instead.
          try {
            await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(rawUrl)));
          } catch (_) {}
        } else if (dScheme == 'gpay') {
          // gpay://upi/pay?… — Razorpay emits this for the GPay icon.
          // Google Pay registers both `gpay://` and `upi://` schemes,
          // but only `upi://` is guaranteed across Android versions.
          // Try the literal URL first, then rewrite to upi:// if the
          // OS can't resolve gpay://. The upi:// variant also lets
          // other UPI apps (PhonePe, Paytm) handle it as a fallback.
          bool launched = false;
          try {
            launched = await launchUrl(
              Uri.parse(rawUrl),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
          if (!launched) {
            final qIdx = rawUrl.indexOf('?');
            if (qIdx > 0) {
              final upiUrl = 'upi://pay${rawUrl.substring(qIdx)}';
              try {
                await launchUrl(
                  Uri.parse(upiUrl),
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                Log.w('[bridge] upi fallback failed: $e');
              }
            }
          }
        } else {
          await _launchExternal(rawUrl);
        }
        break;

      case 'track':
        final event = payload['event'] as String? ?? '';
        final props = (payload['props'] as Map?)?.cast<String, dynamic>() ?? const {};
        if (event.isNotEmpty) await AnalyticsService.log(event, props);
        break;

      case 'openCustomTab':
        final url = payload['url'] as String? ?? '';
        final uri = Uri.tryParse(url);
        if (uri != null && mounted) await CustomTabsService.launch(context, uri);
        break;

      case 'scanQR':
        if (!RemoteConfigService.scannerEnabled || !mounted) { result = null; break; }
        result = await ScannerService.scan(context);
        break;

      case 'getLocation':
        if (!RemoteConfigService.geolocationEnabled) { result = null; break; }
        result = await LocationService.getCurrentPosition();
        break;

      case 'copyText':
        await ClipboardService.copy(payload['text'] as String? ?? '');
        break;

      case 'readClipboard':
        result = await ClipboardService.read();
        break;

      case 'secureSet':
        await SecureStorageService.set(
          payload['key']   as String? ?? '',
          payload['value'] as String? ?? '',
        );
        result = true;
        break;

      case 'secureGet':
        result = await SecureStorageService.get(payload['key'] as String? ?? '');
        break;

      case 'secureDel':
        await SecureStorageService.del(payload['key'] as String? ?? '');
        break;

      case 'logout':
        await _runHardClear();
        await NotificationService.unsubscribeAll();
        if (mounted) {
          await _controller?.loadUrl(
            urlRequest: URLRequest(url: WebUri(RemoteConfigService.appUrl)),
          );
        }
        break;

      case 'download':
        if (!RemoteConfigService.downloadsEnabled) break;
        final url = payload['url'] as String? ?? '';
        final fn  = (payload['filename'] as String?)?.trim();
        if (url.isEmpty) break;
        final name = (fn != null && fn.isNotEmpty)
            ? fn
            : (Uri.tryParse(url)?.pathSegments.lastOrNull ?? 'download');
        await DownloadService.enqueue(url: url, fileName: name);
        break;

      default:
        Log.w('[bridge] unknown action: $action');
    }

    // Resolve the promise on the JS side if the action had an id.
    if (id != null) {
      final jsValue = jsonEncode(result);
      try {
        await _controller?.evaluateJavascript(
          source: 'if(window._flutterResolve) window._flutterResolve($id, $jsValue);',
        );
      } catch (_) {}
    }
    return result;
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

  Future<void> _injectEnvironment() async {
    final device = await DeviceInfoService.load();
    final deviceJson = jsonEncode({
      'platform':      device.platform,
      'os_version':    device.osVersion,
      'device_model':  device.deviceModel,
      'app_version':   device.appVersion,
      'build_number':  device.buildNumber,
      'device_id':     device.deviceId,
    });
    final token = NotificationService.fcmToken ?? '';
    final js = '''
      window.__flutter_device   = $deviceJson;
      window.__flutter_fcmToken = ${jsonEncode(token)};
      if (window.flutter) {
        window.flutter.device   = window.__flutter_device;
        window.flutter.fcmToken = window.__flutter_fcmToken;
      }
    ''';
    try { await _controller?.evaluateJavascript(source: js); } catch (_) {}
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

  // ── Push deep link ─────────────────────────────────────────────

  void _onDeepLink() {
    final url = NotificationService.deepLinkUrl.value;
    if (url == null || url.isEmpty) return;

    final resolved = url.startsWith('http')
        ? url
        : _resolveRelative(url);
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(resolved)));
    NotificationService.deepLinkUrl.value = null;
  }

  String _resolveRelative(String path) {
    final base = Uri.tryParse(RemoteConfigService.appUrl);
    if (base == null) return path;
    return base.resolve(path).toString();
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

  // ── Load timeout ───────────────────────────────────────────────

  void _armLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _timedOut = false;
    final ms = RemoteConfigService.pageLoadTimeoutMs;
    _loadTimeoutTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (_loading) {
        setState(() => _timedOut = true);
        try { _controller?.stopLoading(); } catch (_) {}
        Log.w('[webview] load timed out after ${ms}ms');
      }
    });
  }

  void _cancelLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
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
    final longPressDisabled = RemoteConfigService.longPressDisabled;
    final ua = _userAgent;

    // Hold the WebView until the UA has been prepared. Mounting it with
    // the default UA and then swapping would cause an immediate reload
    // mid-boot — worse UX than a sub-second spinner.
    if (ua == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final initialSettings = InAppWebViewSettings(
      // Core
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      transparentBackground: false,
      // Android-specific
      useHybridComposition: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      allowFileAccess: true,
      allowContentAccess: true,
      geolocationEnabled: RemoteConfigService.geolocationEnabled,
      // iOS-specific
      allowsBackForwardNavigationGestures: true,
      allowsInlineMediaPlayback: true,
      suppressesIncrementalRendering: false,
      // User-Agent — cleaned of "wv" marker so Razorpay/PhonePe show UPI.
      userAgent: ua.isNotEmpty ? ua : null,
      // Zoom — flagged
      supportZoom: pinchZoom,
      builtInZoomControls: pinchZoom,
      displayZoomControls: false,
      // Scheme handling
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: RemoteConfigService.downloadsEnabled,
      useOnLoadResource: false,
      // Cookies + session
      cacheEnabled: true,
      thirdPartyCookiesEnabled: true,
      // Long-press — disable link preview / text selection for app-like feel
      disableLongPressContextMenuOnLinks: longPressDisabled,
      // Mixed content (many payment iframes still use http subresources)
      mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
      // Target=_blank handling via onCreateWindow
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
    );

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
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(startUrl)),
                initialSettings: initialSettings,
                initialUserScripts: UnmodifiableListView<UserScript>([_openShim]),
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
                  if (mounted) setState(() { _loading = true; _progress = 0; });
                  _armLoadTimeout();
                },
                onLoadStop: (c, url) async {
                  _cancelLoadTimeout();
                  if (mounted) setState(() { _loading = false; _progress = 1; });
                  _pullToRefreshController?.endRefreshing();
                  await _injectBridge();
                  await _injectEnvironment();
                  await _injectDarkModeClass();
                  if (url != null) await SessionService.saveLastUrl(url.toString());
                },
                onProgressChanged: (_, p) {
                  if (mounted) setState(() => _progress = p / 100.0);
                  if (p >= 100) _pullToRefreshController?.endRefreshing();
                },
                onReceivedError: (_, __, err) =>
                    Log.w('[webview] ${err.description}'),
                onReceivedHttpError: (_, __, err) =>
                    Log.w('[webview] http ${err.statusCode}: ${err.reasonPhrase}'),

                // Handle target=_blank / window.open. Razorpay uses this
                // for (a) UPI intent: URIs and (b) bank netbanking POSTs.
                // If we naively `loadUrl(URLRequest(url:))` we lose the
                // request method + headers + body, so POST-based bank
                // redirects fail silently. Forward the full request for
                // http(s), and hand off to the external launcher for
                // every non-web scheme so UPI/intent/upi/tel/mailto all
                // work the same as they do from a regular link tap.
                onCreateWindow: (controller, createWindowAction) async {
                  final req    = createWindowAction.request;
                  final uri    = req.url;
                  final scheme = uri?.scheme ?? '';
                  if (uri == null) return false;

                  if (scheme == 'http' || scheme == 'https' || scheme == 'about') {
                    // Load in the existing WebView, preserving method + body.
                    await controller.loadUrl(urlRequest: req);
                    return false;
                  }
                  if (scheme == 'intent') {
                    await _handleAndroidIntent(uri.toString());
                    return false;
                  }
                  // upi / tel / mailto / sms / market / whatsapp / etc.
                  await _launchExternal(uri.toString());
                  return false;
                },

                // Runtime WebView permission requests (mic, camera, geo).
                // We grant only the resources enabled in the admin panel;
                // string-matching covers API differences across
                // flutter_inappwebview versions.
                onPermissionRequest: (controller, req) async {
                  final grant = <PermissionResourceType>[];
                  for (final r in req.resources) {
                    final s = r.toString().toUpperCase();
                    if (s.contains('CAMERA') &&
                        (RemoteConfigService.scannerEnabled ||
                         RemoteConfigService.fileUploadEnabled)) {
                      grant.add(r);
                    } else if (s.contains('MICROPHONE') ||
                               s.contains('AUDIO_CAPTURE')) {
                      grant.add(r);
                    } else if (s.contains('GEOLOCATION') &&
                               RemoteConfigService.geolocationEnabled) {
                      grant.add(r);
                    }
                  }
                  return PermissionResponse(
                    resources: grant,
                    action: grant.isEmpty
                        ? PermissionResponseAction.DENY
                        : PermissionResponseAction.GRANT,
                  );
                },

                // Android: HTML5 navigator.geolocation prompt.
                onGeolocationPermissionsShowPrompt: (controller, origin) async {
                  final allow = RemoteConfigService.geolocationEnabled;
                  return GeolocationPermissionShowPromptResponse(
                    origin: origin,
                    allow: allow,
                    retain: allow,
                  );
                },

                // Downloads — route through flutter_downloader so the file
                // lands in ~/Download with a system notification.
                onDownloadStartRequest: (controller, req) async {
                  if (!RemoteConfigService.downloadsEnabled) return;
                  final name = req.suggestedFilename ??
                      Uri.tryParse(req.url.toString())?.pathSegments.lastOrNull ??
                      'download';
                  await DownloadService.enqueue(
                    url: req.url.toString(),
                    fileName: name,
                  );
                },

                // Recover from WebView renderer crashes (OOM / malformed pages)
                // by reloading the start URL instead of letting the shell die.
                onRenderProcessGone: (controller, detail) async {
                  Log.w('[webview] render process gone — reloading');
                  try { await controller.loadUrl(urlRequest: URLRequest(url: WebUri(_resolveStartUrl()))); } catch (_) {}
                },
              ),

              // Real-percent progress bar (replaces the old indeterminate one).
              if (_loading && _progress < 1)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 2,
                  ),
                ),

              // Timeout screen overlay.
              if (_timedOut)
                Positioned.fill(
                  child: _TimeoutOverlay(
                    onRetry: () {
                      setState(() => _timedOut = false);
                      _controller?.reload();
                      _armLoadTimeout();
                    },
                  ),
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

class _TimeoutOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  const _TimeoutOverlay({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 56),
          const SizedBox(height: 16),
          const Text(
            'This is taking longer than usual',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

