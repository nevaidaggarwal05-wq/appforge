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
      network_detection:   app.network_detection
    },
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
      // Cache 60s at edge, serve stale up to 5 minutes while revalidating
      'Cache-Control': 'public, max-age=60, s-maxage=60, stale-while-revalidate=300'
    }
  });
}
