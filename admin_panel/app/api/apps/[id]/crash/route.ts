// POST /api/apps/:id/crash — PUBLIC, Flutter reports crashes
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

  if (!body.error || typeof body.error !== 'string') {
    return NextResponse.json({ error: 'error field required' }, { status: 400 });
  }

  const { error } = await supabase.from('app_crashes').insert({
    app_id:      params.id,
    error:       body.error,
    stack_trace: body.stack_trace || null,
    device_info: body.device_info || {},
    app_version: body.app_version || null
  });

  if (error) {
    console.error('[crash] insert failed:', error);
    return NextResponse.json({ error: 'Insert failed' }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
