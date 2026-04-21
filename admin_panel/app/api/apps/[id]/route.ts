// ═══════════════════════════════════════════════════════════════
// GET    /api/apps/:id — fetch single app
// PATCH  /api/apps/:id — update fields (partial)
// DELETE /api/apps/:id — remove app + all related data
//
// All three verify auth + ownership before proceeding. RLS is
// secondary defense.
// ═══════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';
import { getServerClient } from '@/lib/supabase/server';

async function requireOwnership(id: string) {
  const supabase = getServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { err: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) } as const;

  const { data: app, error } = await supabase
    .from('apps').select('id, owner_id').eq('id', id).maybeSingle();
  if (error)       return { err: NextResponse.json({ error: error.message }, { status: 500 }) } as const;
  if (!app)        return { err: NextResponse.json({ error: 'Not found' },   { status: 404 }) } as const;
  if (app.owner_id !== user.id)
                   return { err: NextResponse.json({ error: 'Forbidden' },   { status: 403 }) } as const;
  return { supabase, user } as const;
}

export async function GET(_: NextRequest, { params }: { params: { id: string } }) {
  const check = await requireOwnership(params.id);
  if ('err' in check) return check.err;

  const { data, error } = await check.supabase
    .from('apps').select('*').eq('id', params.id).single();
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}

export async function PATCH(req: NextRequest, { params }: { params: { id: string } }) {
  const check = await requireOwnership(params.id);
  if ('err' in check) return check.err;

  let body: any;
  try { body = await req.json(); }
  catch { return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 }); }

  // Strip fields that shouldn't be client-settable
  delete body.id;
  delete body.owner_id;
  delete body.created_at;
  delete body.updated_at;

  const { data, error } = await check.supabase
    .from('apps')
    .update(body)
    .eq('id', params.id)
    .select()
    .single();

  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json(data);
}

export async function DELETE(_: NextRequest, { params }: { params: { id: string } }) {
  const check = await requireOwnership(params.id);
  if ('err' in check) return check.err;

  const { error } = await check.supabase.from('apps').delete().eq('id', params.id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true });
}
