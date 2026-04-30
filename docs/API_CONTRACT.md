# API Contract — Flutter ↔ AppForge Backend

**Every field in this document is a binding contract.** If Flutter or backend changes this shape, both sides must be updated in the same commit.

---

## GET /api/config/:appId

**Public endpoint.** Called by Flutter on every app open.

### Request

```
GET https://admin.yourdomain.com/api/config/550e8400-e29b-41d4-a716-446655440000
  ?fcm_token=dG9rZW5fc3RyaW5nX2hlcmU
  &platform=android
  &device_model=SM-G991B
  &os_version=14
  &app_version=1.0.0
```

All query params are optional. If provided, the backend registers/updates the `fcm_tokens` row.

### Response 200 OK

```json
{
  "app_url": "https://credit.maximoney.in",
  "splash": {
    "enabled": true,
    "color": "#1A1A2E",
    "text": "Maximoney",
    "duration_ms": 2000,
    "logo_url": "https://admin.yourdomain.com/logos/maximoney.png"
  },
  "theme": {
    "primary": "#1A1A2E",
    "accent":  "#E94560"
  },
  "features": {
    "whatsapp_share":      false,
    "biometric_auth":      false,
    "admob":               false,
    "dark_mode":           true,
    "screenshot_block":    true,
    "root_block":          true,
    "session_persistence": true,
    "network_detection":   true
  },
  "admob": {
    "position":           "none",
    "app_id":             "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY",
    "banner_unit_id":     "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ",
    "banner_unit_id_ios": "ca-app-pub-XXXXXXXXXXXXXXXX/QQQQQQQQQQ"
  },
  "force_update": {
    "min_version_code": 0,
    "message":          "",
    "changelog":        ""
  },
  "soft_update": {
    "min_version_code": 0,
    "message":          "",
    "changelog":        ""
  },
  "custom": {
    "upi_merchant_id": "abc@ybl",
    "feature_x_enabled": true
  }
}
```

### Response 404 Not Found

```json
{ "error": "App not found" }
```

### Response headers

```
Cache-Control:               no-store, no-cache, must-revalidate
CDN-Cache-Control:           no-store
Vercel-CDN-Cache-Control:    no-store
```

The shell does its own offline-first caching in SharedPreferences (next-launch-applies pattern). The server intentionally does NOT cache so admin-panel changes propagate to every device on its next config fetch (which Flutter does on every cold start + every WebView resume).

### AdMob fields — important caveat

- **`admob.app_id`** is informational only. Google's MobileAds SDK reads the App ID from `AndroidManifest.xml` `<meta-data>` *before* any Dart code runs, so it cannot be runtime-driven. The shell surfaces this value so it can warn during dev if the manifest-baked App ID drifts from what's in the admin panel.
- **`admob.banner_unit_id`** IS runtime-driven. The shell reads this on every config refresh and uses the value for the next ad request — so changing it in the admin panel propagates without a rebuild. Used on Android, and as the iOS fallback when `banner_unit_id_ios` is null.
- **`admob.banner_unit_id_ios`** is runtime-driven and iOS-only. AdMob's policy is one ad unit per platform; setting this gives iOS its own unit (separate fill optimization, separate eCPM, separate reporting). When null, the iOS shell falls back to `banner_unit_id`.
- **`admob.position`** is runtime-driven. `'none'` hides the banner entirely.

### Flutter Dart equivalent (RemoteConfig model)

**File:** `lib/core/models/remote_config_model.dart`

```dart
class RemoteConfig {
  final String appUrl;
  final SplashConfig splash;
  final ThemeConfig  theme;
  final FeatureFlags features;
  final UpdateConfig forceUpdate;
  final UpdateConfig softUpdate;
  final Map<String, dynamic> custom;
  final DateTime fetchedAt;
  // ...
}
```

All fields must map 1:1 with the JSON keys. Use snake_case in JSON, camelCase in Dart.

---

## POST /api/apps/:id/analytics-event

**Public endpoint.** Called by Flutter whenever the website (via JS bridge) or app logs an event.

### Request

```http
POST /api/apps/550e8400-e29b-41d4-a716-446655440000/analytics-event
Content-Type: application/json

{
  "event_name":  "button_click",
  "properties":  { "button_id": "apply_loan", "page": "/dashboard" },
  "user_id":     "user_12345",
  "device_id":   "android_abc123",
  "platform":    "android",
  "app_version": "1.0.0"
}
```

Required field: `event_name`. Everything else optional.

### Response

```json
{ "ok": true }
```

---

## POST /api/apps/:id/crash

**Public endpoint.** Called by Flutter's `FlutterError.onError` handler + `runZonedGuarded`.

### Request

```http
POST /api/apps/550e8400-e29b-41d4-a716-446655440000/crash
Content-Type: application/json

{
  "error":       "NoSuchMethodError: The method 'x' was called on null",
  "stack_trace": "...",
  "device_info": { "model": "SM-G991B", "os": "Android 14" },
  "app_version": "1.0.0"
}
```

Required field: `error`. Everything else optional.

### Response

```json
{ "ok": true }
```

---

## POST /api/notifications/send

**Admin endpoint.** Called from the admin panel.

### Request

```http
POST /api/notifications/send
Content-Type: application/json
Cookie: sb-xxxxxx-auth-token=... (set by Supabase OTP login)

{
  "app_id":        "550e8400-e29b-41d4-a716-446655440000",
  "title":         "Your loan is approved!",
  "body":          "Tap to view approval details.",
  "image_url":     null,
  "deep_link_url": "https://credit.maximoney.in/approval",
  "category":      "transactional",
  "target_type":   "all",
  "target_value":  null
}
```

### Validation (Zod)

```ts
app_id:        z.string().uuid()
title:         z.string().min(1).max(120)
body:          z.string().min(1).max(500)
image_url:     z.string().url().optional().nullable()
deep_link_url: z.string().url().optional().nullable()
category:      z.enum(['transactional', 'promotional', 'alerts']).default('transactional')
target_type:   z.enum(['all', 'topic', 'tokens', 'segment']).default('all')
target_value:  z.string().optional().nullable()
```

### FCM topic convention

When `target_type: 'all'`, the backend sends to topic `app_<app_id_with_underscores>`:

```
App ID: 550e8400-e29b-41d4-a716-446655440000
Topic:  app_550e8400_e29b_41d4_a716_446655440000
```

Flutter subscribes to this exact topic on first launch.

### Data payload sent to Flutter

```json
{
  "notification": {
    "title": "Your loan is approved!",
    "body":  "Tap to view approval details.",
    "imageUrl": "..." (if provided)
  },
  "data": {
    "url":      "https://credit.maximoney.in/approval",
    "category": "transactional",
    "app_id":   "550e8400-..."
  },
  "android": {
    "priority": "high",
    "notification": { "channelId": "transactional", "sound": "default" }
  },
  "apns": {
    "payload": { "aps": { "sound": "default", "badge": 1, "mutable-content": 1 } }
  }
}
```

Flutter reads `data.url` → loads it in WebView when notification is tapped.

---

## Flutter JS Bridge (website ↔ native)

The Flutter WebView injects `window.flutter` object. Websites can call:

```js
// Haptic feedback
window.flutter.haptic('light');    // 'light' | 'medium' | 'heavy' | 'success' | 'error'

// Biometric auth (returns via callback)
window._biometricResult = (success) => { ... };
window.flutter.biometric('Authenticate to view balance');

// WhatsApp share
window.flutter.share('Check out this site', 'https://example.com');

// UPI payment intent
window.flutter.openUPI('pa=merchant@ybl&pn=Merchant&am=100&cu=INR');

// Custom analytics event
window.flutter.track('cta_click', { cta: 'apply_now' });
```

Each bridge call becomes a JSON message sent through `FlutterBridge.postMessage()` and handled in `webview_screen.dart`'s `_onJsBridgeMessage()`.

---

## Database schema reference

See `admin_panel/supabase/migrations/001_initial_schema.sql` for complete table definitions.

Key tables for Flutter:
- `apps` — fetched via `/api/config/:appId`
- `fcm_tokens` — upserted on every config fetch (when fcm_token query param present)
- `analytics_events` — inserted via `/api/apps/:id/analytics-event`
- `app_crashes` — inserted via `/api/apps/:id/crash`

---

## Changes to this contract require coordinated updates

If you add a field:
1. Add column to Supabase migration (or new migration file)
2. Add TypeScript type to `admin_panel/lib/supabase/types.ts`
3. Add to `RemoteConfigResponse` type
4. Update `/api/config/[appId]/route.ts` to include it
5. Add field to admin panel `ConfigForm.tsx`
6. Add Dart field to `RemoteConfig` model
7. Add accessor to `RemoteConfigService`
8. Use it in Flutter where appropriate

**All 8 steps must be in the same PR or commit.** Otherwise one side breaks.
