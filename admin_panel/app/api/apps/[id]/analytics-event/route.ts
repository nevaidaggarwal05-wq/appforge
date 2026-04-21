// POST /api/apps/:id/analytics-event — PUBLIC, Flutter logs events here
import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  const supabase = getAdminClient();
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (!body.event_name || typeof body.event_name !== 'string') {
    return NextResponse.json({ error: 'event_name required' }, { status: 400 });
  }

  const { error } = await supabase.from('analytics_events').insert({
    app_id:      params.id,
    event_name:  body.event_name,
    properties:  body.properties || {},
    user_id:     body.user_id || null,
    device_id:   body.device_id || null,
    platform:    body.platform || null,
    app_version: body.app_version || null
  });

  if (error) {
    console.error('[analytics] insert failed:', error);
    return NextResponse.json({ error: 'Insert failed' }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
