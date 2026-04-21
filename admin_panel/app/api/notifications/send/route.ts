// POST /api/notifications/send — admin triggers a push
import { NextRequest, NextResponse } from 'next/server';
import { getServerClient, getAdminClient } from '@/lib/supabase/server';
import { sendNotification } from '@/lib/fcm/send';
import type { App, NotificationCategory, NotificationTarget } from '@/lib/supabase/types';
import { z } from 'zod';

const SendSchema = z.object({
  app_id:        z.string().uuid(),
  title:         z.string().min(1).max(120),
  body:          z.string().min(1).max(500),
  image_url:     z.string().url().optional().nullable(),
  deep_link_url: z.string().url().optional().nullable(),
  category:      z.enum(['transactional', 'promotional', 'alerts']).default('transactional'),
  target_type:   z.enum(['all', 'topic', 'tokens', 'segment']).default('all'),
  target_value:  z.string().optional().nullable()
});

export async function POST(req: NextRequest) {
  const supabase = getServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = await req.json();
  const parsed = SendSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }
  const input = parsed.data;

  // Look up the app (bypass RLS — we already verified user above)
  const admin = getAdminClient();
  const { data: app } = await admin.from('apps').select('*').eq('id', input.app_id).maybeSingle<App>();
  if (!app) return NextResponse.json({ error: 'App not found' }, { status: 404 });
  if (app.owner_id !== user.id) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  // Save history row first
  const { data: notif } = await supabase
    .from('notifications')
    .insert({
      app_id:        input.app_id,
      title:         input.title,
      body:          input.body,
      image_url:     input.image_url ?? null,
      deep_link_url: input.deep_link_url ?? null,
      category:      input.category as NotificationCategory,
      target_type:   input.target_type as NotificationTarget,
      target_value:  input.target_value ?? null,
      status:        'sending',
      created_by:    user.id
    })
    .select()
    .single();

  // Send via FCM
  const result = await sendNotification(app, {
    title:         input.title,
    body:          input.body,
    image_url:     input.image_url ?? null,
    deep_link_url: input.deep_link_url ?? null,
    category:      input.category as NotificationCategory,
    target_type:   input.target_type as NotificationTarget,
    target_value:  input.target_value ?? null
  });

  // Update status
  if (notif) {
    await admin.from('notifications').update({
      status:        result.error ? 'failed' : 'sent',
      sent_at:       new Date().toISOString(),
      success_count: result.success,
      failure_count: result.failure,
      error_message: result.error || null
    }).eq('id', notif.id);
  }

  return NextResponse.json({ ok: !result.error, result, notification_id: notif?.id });
}
