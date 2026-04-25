// ═══════════════════════════════════════════════════════════════
// GET /api/config/:appId
// PUBLIC — Flutter shells fetch their config here on every open.
// This endpoint is the heart of the whole system.
// ═══════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/server';
import type { App, RemoteConfigResponse } from '@/lib/supabase/types';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(
  req: NextRequest,
  { params }: { params: { appId: string } }
) {
  const supabase = getAdminClient();

  const { data: app, error } = await supabase
    .from('apps')
    .select('*')
    .eq('id', params.appId)
    .maybeSingle<App>();

  if (error || !app) {
    return NextResponse.json({ error: 'App not found' }, { status: 404 });
  }

  // Track FCM token + device info if provided (for targeted pushes + analytics)
  const fcmToken    = req.nextUrl.searchParams.get('fcm_token');
  const platform    = req.nextUrl.searchParams.get('platform');
  const deviceModel = req.nextUrl.searchParams.get('device_model');
  const osVersion   = req.nextUrl.searchParams.get('os_version');
  const appVersion  = req.nextUrl.searchParams.get('app_version');

  if (fcmToken && platform) {
    // Awaited upsert — ~20ms added but guaranteed to run (fire-and-forget
    // can be killed on serverless when the response is sent).
    const { error: tokenErr } = await supabase.from('fcm_tokens').upsert({
      app_id:       app.id,
      token:        fcmToken,
      platform:     platform as 'android' | 'ios' | 'web',
      device_model: deviceModel,
      os_version:   osVersion,
      app_version:  appVersion,
      last_seen_at: new Date().toISOString()
    }, { onConflict: 'app_id,token' });
    if (tokenErr) console.error('[config] fcm_token upsert failed:', tokenErr);
  }

  const response: RemoteConfigResponse = {
    app_url: app.app_url,
    splash: {
      enabled:     app.splash_enabled,
      color:       app.splash_color,
      text:        app.splash_text ?? '',
      duration_ms: app.splash_duration_ms,
      logo_url:    app.splash_logo_url ?? ''
    },
    theme: {
      primary: app.theme_primary,
      accent:  app.theme_accent
    },
    features: {
      whatsapp_share:      app.whatsapp_share,
      biometric_auth:      app.biometric_auth,
      admob:               app.admob_enabled,
      dark_mode:           app.dark_mode,
      screenshot_block:    app.screenshot_block,
      root_block:          app.root_block,
      session_persistence: app.session_persistence,
      network_detection:   app.network_detection,
      pinch_to_zoom:       app.pinch_to_zoom ?? true,
      pull_to_refresh:     app.pull_to_refresh ?? true
    },
    whatsapp: {
      number:  app.whatsapp_number ?? null,
      message: app.whatsapp_message ?? 'Check out this app'
    },
    admob: {
      position: (app.admob_position ?? 'none') as 'none' | 'top' | 'bottom'
    },
    cache: {
      soft_clear_at: app.cache_soft_clear_at ?? null,
      hard_clear_at: app.cache_hard_clear_at ?? null
    },
    webview: {
      user_agent_suffix:    app.user_agent_suffix ?? null,
      edge_to_edge:         app.edge_to_edge ?? true,
      status_bar_style:     (app.status_bar_style ?? 'auto') as 'auto'|'light'|'dark',
      long_press_disabled:  app.long_press_disabled ?? true,
      page_load_timeout_ms: app.page_load_timeout_ms ?? 20000,
      extra_allowed_hosts:  (app.extra_allowed_hosts ?? []) as string[],
      theme_color_source:   (app.theme_color_source ?? 'admin') as 'admin'|'meta'|'system'
    },
    permissions: {
      geolocation: app.geolocation_enabled ?? false,
      scanner:     app.scanner_enabled ?? false,
      file_upload: app.file_upload_enabled ?? true,
      downloads:   app.downloads_enabled ?? true
    },
    upload: {
      max_image_kb:  app.upload_max_image_kb ?? 1024,
      image_quality: app.upload_image_quality ?? 80
    },
    oauth: {
      custom_scheme: app.oauth_custom_scheme ?? null,
      hosts:         (app.oauth_hosts ?? ['accounts.google.com','appleid.apple.com','login.microsoftonline.com']) as string[]
    },
    notif:  { badge_enabled: app.notif_badge_enabled ?? true },
    locale: { default: (app.default_locale ?? 'en') as 'en'|'hi' },
    force_update: {
      min_version_code: app.force_update_version,
      message:          app.force_update_message ?? '',
      changelog:        app.update_changelog ?? ''
    },
    soft_update: {
      min_version_code: app.soft_update_version,
      message:          app.soft_update_message ?? '',
      changelog:        ''
    },
    custom: app.custom_config ?? {}
  };

  return NextResponse.json(response, {
    headers: {
      // No caching. Every shell open should see the latest admin-panel
      // state. Previous `public, max-age=60, s-maxage=60,
      // stale-while-revalidate=300` meant an admin-panel URL change
      // could take up to 6 minutes to propagate — and in practice,
      // Next.js's route-level cache + any intermediate proxy held it
      // far longer. The Flutter shell already does local caching in
      // SharedPreferences for offline/fast-start, so the server doesn't
      // need to add another layer.
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'CDN-Cache-Control': 'no-store',
      'Vercel-CDN-Cache-Control': 'no-store'
    }
  });
}
