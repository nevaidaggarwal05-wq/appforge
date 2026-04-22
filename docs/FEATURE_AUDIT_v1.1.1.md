# Flutter WebView Shell — Feature Audit (as of v1.1.1 / Apr 22 2026)

This is a line-by-line answer to the audit checklist you shared. It is a **read-only review** — no code has changed. Decisions about what to build next happen in the next session.

**Scope of this audit:** AppForge Flutter shell in `~/Desktop/handoff/flutter_shell/`. Maximoney v1.1.1 is the first production build of this shell (Phase 4). Up through v1.1.0 the shell ran on `webview_flutter`; v1.1.1 switched to `flutter_inappwebview`.

**Legend**
- ✅ Implemented — working in v1.1.1 shell
- 🟡 Partial — wired but with caveats (called out in notes)
- ❌ Missing — not present today
- 🚫 Skip — deliberately out of scope (reason noted)

---

## Status key for what we have and what we don't

Before the tables, two facts that shape every answer below:

1. **iOS is effectively unconfigured.** The `ios/` folder only contains `AppDelegate.swift` and the Flutter-generated plugin registrants. There's no `Info.plist`, no `Runner.xcodeproj`, no `Podfile`. Every iOS-specific row below is either ❌ or 🚫 until we run `flutter create --platforms=ios .` and do a full iOS build pass.
2. **Maximoney is shipping Android-only.** That matches the state of the shell. Adding iOS later is its own ~1–2 day effort.

---

## 1. 🌐 WebView Core

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 1.1 | WebView widget rendering | ✅ | `flutter_inappwebview: ^6.1.5`, `InAppWebView` is the root widget in `webview_screen.dart`. |
| 1.2 | JavaScript enabled | ✅ | `javaScriptEnabled: true`. |
| 1.3 | Hybrid composition (Android smooth render) | ✅ | `useHybridComposition: true`. |
| 1.4 | Inline media playback (iOS video) | ❌ | `allowsInlineMediaPlayback` not set. Irrelevant today (no iOS) but will be needed. |
| 1.5 | Autoplay without gesture | ✅ | `mediaPlaybackRequiresUserGesture: false`. |
| 1.6 | Transparent / edge-to-edge background | 🟡 | `transparentBackground: false` + we wrap in `SafeArea`. Not edge-to-edge. System UI overlay also not customised. |
| 1.7 | Custom User-Agent string | ❌ | No `userAgent` / `applicationNameForUserAgent` set. Webapps can't detect "running inside shell vs Chrome." High-value for analytics segmentation + server-side conditionals. |
| 1.8 | Zoom disabled (native feel) | ✅ | Admin-configurable — `supportZoom` + `builtInZoomControls` both driven by `features.pinch_to_zoom`. |
| 1.9 | DOM storage enabled | ✅ | `domStorageEnabled: true`. |
| 1.10 | Third-party cookies (Android) | ✅ | `thirdPartyCookiesEnabled: true`. |
| 1.11 | Mixed content mode | ✅ | `MIXED_CONTENT_COMPATIBILITY_MODE` (payment iframes often mix http subresources). |
| 1.12 | Desktop mode / viewport meta handling | 🟡 | We deliberately removed viewport-lock JS in v1.1.1 (it was breaking sticky headers). The webapp's own `<meta viewport>` now wins. Good default, but no way to force desktop mode. |
| 1.13 | Initial URL / base URL loading | ✅ | `URLRequest(url: WebUri(startUrl))`. |
| 1.14 | Pull-to-refresh | ✅ | Native `SwipeRefreshLayout` via `PullToRefreshController`, admin-toggleable. |
| 1.15 | Progress indicator while page loads | 🟡 | We show a `LinearProgressIndicator` based on `_loading` (binary on/off via `onLoadStart`/`onLoadStop`) but don't wire `onProgressChanged` to a real 0–100% bar. |
| 1.16 | Error page handling | 🟡 | `onReceivedError` just logs. No in-WebView error screen (we have `NoInternetScreen` but that's for cold-start offline only). If a page fails mid-session the user sees the WebView's default "webpage not available." |
| 1.17 | HTTP error handling (404, 500) | 🟡 | `onReceivedHttpError` logs only. Webapp shows whatever it rendered. |

---

## 2. 🔗 JavaScript ↔ Flutter Bridge

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 2.1 | JS channel / message handler registered | ✅ | `controller.addJavaScriptHandler(handlerName: 'FlutterBridge', callback: _onJsBridge)`. |
| 2.2 | Flutter → JS calls | ✅ | `_controller.evaluateJavascript(source: …)`. |
| 2.3 | Pass FCM token to webapp via JS | 🟡 | Token goes to the **backend** via `?fcm_token=` on the config fetch (`RemoteConfigService.initialize`). The webapp can't directly read it. Most webapps don't need to — backend pushes are driven off the token we already store. |
| 2.4 | Pass device info to webapp via JS | 🟡 | Same as above — device info is sent to backend, not injected into the page. Easy to add a `window.flutter.deviceInfo = {…}` injection. |
| 2.5 | Pass deep link / notification payload via JS | 🟡 | We `loadUrl` to the deep-link URL on notification tap. That's URL-based delivery — the webapp gets the URL but not the raw payload (e.g. `{category:"promo", campaign_id:"x"}`). |
| 2.6 | Webapp triggers native share sheet | 🟡 | `flutter.share(text, url)` exists but **only opens WhatsApp** (`https://wa.me/…`). A real `Share.share()` (system share sheet) is not wired — `share_plus` isn't in the pubspec. |
| 2.7 | Webapp triggers native haptics | ✅ | `flutter.haptic('light'\|'medium'\|'heavy')` → `HapticService.byTag`. |

---

## 3. 📷 Camera & File Handling

**This whole section is ❌.** If the webapp has `<input type="file">` anywhere — profile upload, KYC document, resume, etc. — it will silently do nothing when tapped. Most fintech/creditech apps (including Maximoney's KYC flow) hit this.

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 3.1 | `<input type="file">` intercept (Android) | ❌ | No `onShowFileChooser` handler. File input taps are dropped. |
| 3.2 | `<input type="file" accept="image/*">` (iOS) | ❌ | — |
| 3.3 | Camera capture via `capture="camera"` | ❌ | No `image_picker` dependency. |
| 3.4 | Gallery / photo library picker | ❌ | — |
| 3.5 | General file picker (PDF, doc) | ❌ | No `file_picker` dependency. |
| 3.6 | Video recording / picker | ❌ | — |
| 3.7 | Multiple file selection | ❌ | — |
| 3.8 | Image compression before upload | ❌ | No `flutter_image_compress`. Unoptimized 20 MB phone-camera uploads will hammer the backend. |
| 3.9 | File MIME type filtering | ❌ | — |
| 3.10 | Camera permission request | 🟡 | Manifest has `CAMERA` but runtime prompting is WebView-default (not `permission_handler`). |
| 3.11 | Microphone permission request | ❌ | No `RECORD_AUDIO` permission in manifest, no runtime prompt. |
| 3.12 | Photo library permission request | 🟡 | Manifest has `READ_MEDIA_IMAGES` + legacy `READ_EXTERNAL_STORAGE`. No runtime flow. |

---

## 4. 🔔 Push Notifications

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 4.1 | FCM setup | ✅ | `firebase_core` + `firebase_messaging`, shared `appforge-push` Firebase project. |
| 4.2 | FCM token retrieval + refresh listener | ✅ | `_messaging.getToken()` + `onTokenRefresh` in `NotificationService`. |
| 4.3 | Foreground notification display | ✅ | `flutter_local_notifications` with per-category channel. |
| 4.4 | Background / terminated handling | ✅ | `_firebaseBackgroundHandler` registered before `runApp`. |
| 4.5 | Notification tap → payload | ✅ | Via `onMessageOpenedApp` → `_processDeepLink` → `ValueNotifier` → WebView navigates. |
| 4.6 | App opened from terminated via notification | ✅ | `getInitialMessage()` with 1s delay so WebView can mount its listener. |
| 4.7 | iOS APNs entitlements | ❌ | No iOS target. |
| 4.8 | Android notification channel | ✅ | Three channels: transactional, promotional, alerts. |
| 4.9 | Notification icon / color branding | 🟡 | Falls back to `@mipmap/ic_launcher`. No dedicated `notification_icon` drawable (usually a monochrome white silhouette) — on Android 5+ your colour icon may render as a grey square in the status bar. |
| 4.10 | FCM token to webapp via JS bridge | ❌ | See 2.3 — token goes to backend only. |

---

## 5. 📍 Geolocation

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 5.1 | WebView geolocation enabled | ❌ | `geolocationEnabled` not set on InAppWebView. |
| 5.2 | iOS geolocation prompt handled | 🚫 | No iOS. |
| 5.3 | Android geolocation prompt handled | ❌ | No `onGeolocationPermissionsShowPrompt` callback. Requests from `navigator.geolocation` silently deny. |
| 5.4 | Native GPS fallback | ❌ | No `geolocator`. |
| 5.5 | Location permission request flow | ❌ | No `permission_handler`, no `ACCESS_FINE_LOCATION` in manifest. |
| 5.6 | Background location | 🚫 | Not needed for Maximoney / similar WebView apps. |

---

## 6. 🔗 Deep Linking & Navigation

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 6.1 | Deep link (cold start) | 🟡 | Works for **FCM-triggered** deep links via `getInitialMessage`. OS-level deep links (user taps an https link in WhatsApp) don't route anywhere specific — the app opens to its default URL. |
| 6.2 | Deep link (warm start) | 🟡 | Same: FCM yes, OS link no. No `uni_links` / `app_links` package. |
| 6.3 | Android App Links (`assetlinks.json`) | 🟡 | Intent filter is in the manifest template but host is hardcoded to `example.com` — the generator replaces it with the per-app host. `docs/hosting/assetlinks_TEMPLATE.json` is a template you have to upload manually. Not automated. |
| 6.4 | iOS Universal Links | 🚫 | No iOS. |
| 6.5 | Custom URL scheme (`myapp://`) | ❌ | Not declared. Blocks OAuth-return flows that redirect to `maximoney://callback`. |
| 6.6 | External links → browser | ✅ | `_onNavRequest` routes different-host URLs to `launchUrl(…externalApplication)`. Sub-host awareness (`a.example.com` vs `example.com`) is handled. |
| 6.7 | `mailto:` / `tel:` / `sms:` | ✅ | All three + `upi:` handled explicitly. |
| 6.8 | Android hardware back | ✅ | `PopScope` → `canGoBack` → `goBack`, else pop. |
| 6.9 | Domain whitelist | 🟡 | Implicit: same-host-or-subhost stays in WebView, everything else goes external. No explicit multi-host whitelist (e.g. allow `credit.maximoney.in` + `api.maximoney.in` + `cdn.maximoney.in` but block `evil.com`). |

---

## 7. 💾 Storage & Cookies

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 7.1 | Cookie persistence across sessions | ✅ | InAppWebView default + `thirdPartyCookiesEnabled: true`. |
| 7.2 | Secure storage for tokens/credentials | ❌ | No `flutter_secure_storage`. We use `shared_preferences` for session state, which is NOT encrypted. OK for "last URL visited," **not** OK if we ever store an access token natively. |
| 7.3 | Shared preferences for app settings | ✅ | `shared_preferences` used by `CacheService`, `SessionService`. |
| 7.4 | Clear cookies on logout (JS bridge) | 🟡 | Hard cache-clear does this globally from admin. No per-user `flutter.logout()` JS bridge call yet — webapp can't trigger it from a "Log out" button. |
| 7.5 | Clear WebView cache | ✅ | Admin panel Soft + Hard buttons. |
| 7.6 | IndexedDB / localStorage enabled | ✅ | `databaseEnabled: true`. |

---

## 8. 🔐 Auth & Security

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 8.1 | SSL error handling / pinning | ❌ | No `onReceivedServerTrustAuthRequest`. On a self-signed/expired cert the WebView just fails silently. No cert pinning. |
| 8.2 | Biometric auth | ✅ | `local_auth`, exposed via `flutter.biometric('reason')` JS bridge. |
| 8.3 | Google Sign-In in WebView | ❌ | Google blocks OAuth inside WebViews (error 403 "disallowed_useragent"). Needs Custom Tabs fallback or native GSI. Untested — if Maximoney has "Continue with Google," it will break. |
| 8.4 | Apple Sign-In | 🚫 | No iOS. |
| 8.5 | OAuth redirect (custom scheme) | ❌ | Tied to 6.5. Blocks bank-login redirect flows. |
| 8.6 | Play Integrity check | ❌ | No `play_integrity`. |
| 8.7 | Root detection | ✅ | `SecurityService.isRooted`, gates to `RootDetectedScreen` when `root_block` flag on. Uses `device_info_plus` heuristics (OK, not bulletproof — a determined attacker can bypass it, but it stops casual copy-testers). |

---

## 9. 💳 Payments

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 9.1 | Payment Request API | 🟡 | Whatever the WebView supports natively. Not tested. |
| 9.2 | Google Pay / Apple Pay | 🟡 | Google Pay via UPI intent works (we fixed this in v1.1.1). Google Pay via Payment Request API untested. Apple Pay N/A. |
| 9.3 | In-App Purchase | 🚫 | Only needed if you sell **digital goods**. Credit products are financial services, exempt from IAP. |
| 9.4 | Razorpay / Stripe | ✅ | Razorpay UPI intent flow works in v1.1.1. Stripe hosted-checkout (3DS redirects) should work via normal navigation. |

---

## 10. 📡 Connectivity & Network

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 10.1 | Connectivity check on launch | ✅ | `NetworkQualityService.isOnline()` in bootstrap. |
| 10.2 | Offline screen | ✅ | `NoInternetScreen` shown when bootstrap detects no network. |
| 10.3 | Auto-reload on reconnect | ❌ | The `NoInternetScreen` doesn't listen for reconnect — user has to tap "Retry." And if you go offline **mid-session** (inside WebView), there's no banner or auto-retry. |
| 10.4 | Custom HTTP headers on WebView | 🟡 | Not currently set. Config API fetch adds headers but the WebView itself doesn't forward an `X-App-Client` or similar. |
| 10.5 | CORS / certificate handling | 🟡 | Default. `usesCleartextTraffic="false"` in manifest so http URLs are blocked — fine for prod, would need a dev-only override if you ever need to debug against http staging. |

---

## 11. 🎨 UI / UX & Edge-to-Edge

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 11.1 | Edge-to-edge display | ❌ | WebView is wrapped in `SafeArea`. No `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`. |
| 11.2 | Status bar colour / brightness | ❌ | No `setSystemUIOverlayStyle`. Uses OS defaults — may read illegibly on some themes. |
| 11.3 | Native splash (before Flutter loads) | ❌ | We have a Flutter-drawn splash, which means there's a brief black frame while Flutter engine boots. `flutter_native_splash` would eliminate that. |
| 11.4 | App icon | ✅ | `flutter_launcher_icons` config in per-app pubspec (Maximoney build). |
| 11.5 | Keyboard resize | 🟡 | `windowSoftInputMode="adjustResize"` in manifest. `resizeToAvoidBottomInset` not explicitly tuned on the Scaffold (defaults to true, which is usually fine). |
| 11.6 | Smooth scroll / scrollbar | 🟡 | Scrollbar visibility not explicitly set. |
| 11.7 | Overscroll / bounce | 🟡 | Platform default. |
| 11.8 | Loading skeleton / shimmer | ❌ | Only a thin progress bar at the top. First-paint shows white screen. |
| 11.9 | Safe area / notch | ✅ | `SafeArea` wraps WebView. |
| 11.10 | Dark mode | 🟡 | We inject a `.app-dark-mode` CSS class on `<html>` when enabled. We don't forward `prefers-color-scheme` — the webapp doesn't automatically get a dark-theme media query. And the flag is remote-only, not OS-following. |
| 11.11 | Font scaling / accessibility | 🟡 | WebView respects system font size by default. Not tested. |

---

## 12. 🎙 Device Hardware Access

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 12.1 | Microphone access | ❌ | No `RECORD_AUDIO` permission, no runtime handler. `getUserMedia({audio:true})` fails. |
| 12.2 | Torch / flashlight | 🚫 | Not needed for credit/fintech. |
| 12.3 | Vibration / haptics | ✅ | `flutter.haptic(…)`. |
| 12.4 | QR / barcode scanner | ❌ | No `mobile_scanner`. Any "scan to pay" or KYC flow won't work. |
| 12.5 | NFC | 🚫 | Skip. |
| 12.6 | Contacts | ❌ | Might be useful (refer-a-friend) — currently no `flutter.getContacts()` bridge. |
| 12.7 | Calendar | 🚫 | Skip. |
| 12.8 | Bluetooth | 🚫 | Skip. |
| 12.9 | WebRTC / getUserMedia | ❌ | Needs mic + camera permissions to work. Since 12.1 and 3.10 are both gaps, WebRTC is effectively dead. Only matters if you ever add video-KYC. |

---

## 13. 📊 Analytics & Monitoring

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 13.1 | Firebase Analytics | 🟡 | Not installed. We use our own `AnalyticsService` posting to `/api/apps/:id/analytics-event`. That covers event logging but not GA4 funnel/audience features. |
| 13.2 | Crashlytics | ✅ | Installed. `FirebaseCrashlytics.instance.recordFlutterError` + we also POST crashes to `/api/apps/:id/crash`. |
| 13.3 | Performance monitoring | ❌ | No `firebase_performance`. |
| 13.4 | Remote config | ✅ | Our own `RemoteConfigService` + `/api/config/:id`. We don't use Firebase Remote Config — we built the equivalent. |
| 13.5 | App version / build number | ✅ | `package_info_plus` via `DeviceInfoService`. |

---

## 14. 🔄 App Lifecycle & Updates

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 14.1 | WebView pause/resume on lifecycle | ❌ | No `WidgetsBindingObserver` tied to the WebView. On backgrounding, JS timers / video / audio keep running. Battery + wasted network. |
| 14.2 | In-app update prompt (Android native) | 🟡 | We have a remote-config-driven `ForceUpdateScreen` + `InAppUpdateBanner`, but not Google's `in_app_update` API (which does flexible / immediate in-place updates without going to Play Store). |
| 14.3 | Force update / min version | ✅ | Driven by admin panel. Works. |
| 14.4 | App review prompt | ✅ | `in_app_review`, triggered in `RatingService.maybePrompt` after N sessions. |

---

## 15. 🏗 Build & Platform Configuration

| # | Feature | Status | Notes |
|---|---------|:------:|-------|
| 15.1 | Android `minSdkVersion` 21+ | ✅ | 21. |
| 15.2 | Android `INTERNET` | ✅ | |
| 15.3 | Android `CAMERA` | ✅ | |
| 15.4 | Android `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` | ✅ | Both present. |
| 15.5 | Android `ACCESS_FINE_LOCATION` | ❌ | |
| 15.6 | Android `RECORD_AUDIO` | ❌ | |
| 15.7 | Android `VIBRATE` | ✅ | |
| 15.8 | iOS `NSCameraUsageDescription` | ❌ | No `Info.plist`. |
| 15.9 | iOS `NSMicrophoneUsageDescription` | ❌ | Ditto. |
| 15.10 | iOS `NSPhotoLibraryUsageDescription` | ❌ | Ditto. |
| 15.11 | iOS `NSLocationWhenInUseUsageDescription` | ❌ | Ditto. |
| 15.12 | iOS `NSContactsUsageDescription` | ❌ | Ditto. |
| 15.13 | iOS Background modes | ❌ | Ditto. |
| 15.14 | Proguard / R8 rules | 🟡 | Default `proguard-android-optimize.txt` + empty `proguard-rules.pro`. No custom keep-rules yet. Release AAB built cleanly, so this is fine for now — if we add reflection-heavy libs later we'd need keep-rules. |
| 15.15 | iOS `WKAppBoundDomains` | ❌ | No iOS. |

---

## 16. 🧪 Testing Checklist

This is **your** job — I can't run tests on a physical phone. I've filled in the ones where I know the current state of the code well enough to make a confident prediction.

| # | Test Case | Predicted Result | Notes |
|---|-----------|:------:|-------|
| 16.1 | File upload (Android) | ❌ | No file chooser wired — tap does nothing. |
| 16.2 | File upload (iOS) | 🚫 | No iOS. |
| 16.3 | Camera capture (Android) | ❌ | Same reason as 16.1. |
| 16.4 | Camera capture (iOS) | 🚫 | No iOS. |
| 16.5 | Foreground push | ✅ likely | Works in our manual tests in v1.1.0. |
| 16.6 | Background push | ✅ likely | Same. |
| 16.7 | Push tap → correct screen | ✅ likely | Works if notification payload has `data.url`. |
| 16.8 | Geolocation prompt | ❌ | Section 5 is missing. |
| 16.9 | Deep link opens correct page | 🟡 | Only via FCM today. |
| 16.10 | No-internet screen | ✅ | At cold start. |
| 16.11 | Back button (Android) | ✅ | Works. |
| 16.12 | OAuth / social login | ❌ | Google blocks WebView OAuth. Untested. |
| 16.13 | Payment end-to-end | 🟡 | UPI works per v1.1.1 — needs your field test on Maximoney. |
| 16.14 | WebRTC video call | ❌ | Permissions missing. |
| 16.15 | 30-min background → foreground | 🟡 | Should work but WebView may have been killed by OOM — untested. |
| 16.16 | Cookie/session persists | 🟡 | Should — needs confirmation. |
| 16.17 | Low-memory handling | 🟡 | Untested. |
| 16.18 | Keyboard covers input | 🟡 | `adjustResize` is set — should be OK. |

---

## Beyond the checklist — items I think you're missing

These are not in the audit doc but are relevant to a production-grade webview shell. Flagging so you can weigh them alongside the gaps:

| # | Feature | Why it matters |
|---|---------|----------------|
| B.1 | **Download handling** (PDFs, statements, invoices) | WebView doesn't automatically save/open download-attribute links. Maximoney statements, NOC, etc. will fail. Needs `onDownloadStartRequest`. |
| B.2 | **Long-press / context-menu control** | Right now users can long-press inside the WebView and get "Open in new tab," "Copy link," etc. — exposes the fact this is a WebView. `disableLongPressContextMenuOnLinks: true`. |
| B.3 | **Text selection / copy control** | For screens with sensitive PII (Aadhaar, account number) you may want to disable text selection. CSS-driven from web side, or Flutter-side. |
| B.4 | **Print-to-PDF bridge** | If Maximoney lets users print statements — there's no native print hookup. |
| B.5 | **Clipboard read bridge** | Auto-fill OTP from SMS requires clipboard access that WebView often denies. A `flutter.readClipboard()` bridge fixes that. |
| B.6 | **Theme-color meta forwarding** | If the web page has `<meta name="theme-color">`, we should mirror it to the Android status bar. Right now status bar colour is fixed / OS default. |
| B.7 | **Notification badge count** | iOS/Android home-screen icon badge count. Useful for "3 unread offers." |
| B.8 | **Silent data-only FCM** | Current setup shows **all** FCM messages. Data-only pushes (e.g. "refresh config now") would be dropped as a notification. |
| B.9 | **OAuth return via Custom Tabs** | Tie-in with 6.5 / 8.3 / 8.5. `flutter_custom_tabs` opens Chrome Custom Tab, lets Google OAuth complete, returns via intent-filter. |
| B.10 | **Dynamic App Link host** | Generator hardcodes `example.com` → per-app host, but the host comes from `app_url` only. Can't configure multiple verified hosts (e.g. `credit.maximoney.in` + `maximoney.in`). |
| B.11 | **"Pull to refresh" inside WebView only when at scrollTop=0** | Current impl fires even if user is mid-scroll — can accidentally reload. `PullToRefreshController` has a `shouldOverride` we're not using. |
| B.12 | **Page-load timeout / recovery** | If a page hangs at "Loading…" forever, we have no "Reload" escape hatch for the user. |
| B.13 | **WebView crash recovery** | On Android, Chromium can crash the WebView process independently (`RenderProcessGone`). Currently the app would just show a blank screen. |
| B.14 | **Device ID stability** | `DeviceInfoService.deviceId` uses Android `id` which changes on factory reset. For stable push-targeting, consider Install ID + Secure Storage. |
| B.15 | **URL-based screen routing via FCM** | We use `data.url`. What if the webapp wants to say "open loan-status for loan 12345" as a typed event, not a URL? Typed payload bridge would be cleaner. |
| B.16 | **Multi-language / i18n on native screens** | `NoInternetScreen`, `ForceUpdateScreen`, `RootDetectedScreen` are English-hardcoded. Maximoney likely wants Hindi. |
| B.17 | **`accept-language` header** | WebView uses OS locale by default. For testing-from-abroad this can make the server render the wrong language. |

---

## Summary — prioritised backlog for the next session

### ✅ Already Implemented (highlights)
- InAppWebView with proper scroll/sticky behaviour (v1.1.1)
- JS bridge (haptic, biometric, share, upi, track)
- Razorpay UPI intent flow + `<queries>` for Android 11+
- Admin-driven soft/hard cache clear
- Native pull-to-refresh (toggleable)
- Pinch-to-zoom (toggleable)
- FCM push: foreground + background + terminated + tap deep-link
- Runtime config + offline fallback + 60s refresh
- Biometric via `flutter.biometric()` bridge
- Crashlytics + custom analytics
- Root detection, force-update, soft-update banner, in-app review
- WhatsApp share (admin-configurable number + message)

### 🔴 P0 — Critical (ship-blockers or likely-production-fails for Maximoney)

1. **File upload + camera capture bridge** (§3.1–3.10). Maximoney has KYC = document upload = this is non-negotiable. Needs `flutter_inappwebview`'s `onShowFileChooser` + `image_picker` + `file_picker` + `permission_handler` + `flutter_image_compress`.
2. **Download handling** (B.1). Statements, NOCs, receipts. Needs `onDownloadStartRequest` + `flutter_downloader` or similar.
3. **Custom User-Agent** (§1.7). Lets the webapp detect "I'm in the shell" — needed for server-side conditionals (e.g. hide "Download our app" banners inside the app, tag analytics as `source=app`).
4. **OAuth / Google Sign-In via Custom Tabs** (§8.3, 8.5, 6.5). If Maximoney's login has "Continue with Google" this is broken today.
5. **WebView mid-session offline handling** (§10.3). Currently only bootstrap detects offline. Losing network mid-form = confused user.
6. **WebView crash recovery** (B.13). `RenderProcessGone` callback + reload.
7. **Page-load timeout + user-facing "reload" action** (B.12). A hung page with no escape = uninstall.

### 🟡 P1 — Important (meaningfully better UX / future-proofing)

8. **Edge-to-edge + status bar styling** (§11.1, 11.2). Bigger visual "native feel" jump than almost anything else. Theme-color forwarding (B.6) rides on this.
9. **Geolocation bridge** (§5.1, 5.3, 5.5). If Maximoney ever adds location-based credit offers, or "find nearest agent," this is needed.
10. **QR / barcode scanner bridge** (§12.4). Scan to pay / scan to KYC.
11. **`flutter_secure_storage`** (§7.2). Any future native-stored auth token should live here, not in shared_preferences.
12. **Webapp-triggerable logout bridge** (§7.4 completion). `flutter.logout()` → hard clear, without opening the admin panel.
13. **FCM token + device info JS injection** (§2.3, 2.4). Webapp gets `window.flutter.fcmToken`, `window.flutter.device`. Enables per-device personalization.
14. **System share sheet** (§2.6, beyond WhatsApp). `share_plus` — lets users share to anyone, not just WhatsApp.
15. **Mid-session connectivity banner + auto-reload on reconnect** (§10.3). Complements P0 #5.
16. **Real progress bar** (§1.15). Use `onProgressChanged` not binary on/off. Feels way faster even if it isn't.
17. **`flutter_native_splash`** (§11.3). Kills the black frame before Flutter engine boots.
18. **In-session deep links from OS** (§6.1, 6.2). `app_links` package so tapping an https link in WhatsApp opens the app on the right page.
19. **Notification icon drawable + colour** (§4.9). Avoid the grey-square bug on Android 5+.
20. **Runtime permission flow** via `permission_handler` (§3.10–3.12). Needed as glue for P0 #1 anyway.

### 💡 P2 — Nice to Have (polish, edge cases, future bets)

21. WebView lifecycle pause/resume (§14.1) — battery win, tiny UX win.
22. `in_app_update` Android API (§14.2) — smoother than our banner.
23. Long-press / context-menu disable (B.2).
24. Clipboard read for OTP autofill (B.5).
25. Notification badge count (B.7).
26. Silent data-only FCM (B.8).
27. Multi-host App Link whitelist (B.10 / §6.9).
28. i18n of native screens (B.16).
29. Theme-color meta → status bar (B.6).
30. Typed-payload FCM deep links (B.15).
31. `accept-language` header pass-through (B.17).
32. Play Integrity (§8.6) — skip unless you hit fraud issues.
33. Firebase Performance (§13.3).
34. Stable device ID across factory reset (B.14).

### 🚫 Not applicable to Maximoney-style apps

- iOS-specific rows (until we decide to ship iOS)
- In-App Purchase (§9.3) — financial services exempt
- Bluetooth (§12.8), NFC (§12.5), calendar (§12.7), torch (§12.2)
- Background location (§5.6)
- Apple Sign-In (§8.4)

---

## Recommended next-session scope

If I were picking **one** buildable chunk for the next session, I would do **P0 #1 + #2 + #3 + #5 + #6 + #20** together — all file-related + UA + offline + crash recovery — because they share infrastructure (`permission_handler` installs once, `onShowFileChooser` + `onDownloadStartRequest` are sibling callbacks, offline banner is ~50 lines). That one chunk turns v1.1.1 from "browses fine" → "can complete a Maximoney KYC journey without fallbacks."

**P1 #8 + #13 + #16 + #17** (edge-to-edge, JS injection of FCM/device, real progress bar, native splash) is the natural second chunk — all cosmetic/native-feel, also shares no dependencies with the P0 chunk, so the two chunks can be built back-to-back or split across sessions.

### Version plan for the next build

Per your instruction:
- Maximoney next build: **versionName 1.2.0**, **versionCode 7**
- Current Play Store production is versionCode 5 or 6 (per your note); v1.1.1 on your desk is versionCode 3 which you haven't pushed to Play
- Jumping to versionCode 7 for the next build (skipping 4–6) is totally fine — Play Store only cares that it's higher than whatever's already live there

I'll mark that in the build.gradle when we do the next build.
