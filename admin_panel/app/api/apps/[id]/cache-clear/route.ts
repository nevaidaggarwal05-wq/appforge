// ═══════════════════════════════════════════════════════════════
// POST /api/apps/:id/cache-clear?kind=soft|hard
//
// Bumps cache_soft_clear_at or cache_hard_clear_at to now().
// Flutter shells compare this timestamp against the one they last
// applied and clear accordingly:
//   • soft  → clears WebView HTTP cache only (app state preserved)
//   • hard  → clears cache + cookies + localStorage (full reset)
// ═══════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';
import { getServerClient } from '@/lib/supabase/server';

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const kind = req.nextUrl.searchParams.get('kind');
  if (kind !== 'soft' && kind !== 'hard') {
    return NextResponse.json({ error: 'kind must be soft or hard' }, { status: 400 });
  }

  const supabase = getServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: app } = await supabase
    .from('apps').select('id, owner_id').eq('id', params.id).maybeSingle();
  if (!app)                    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  if (app.owner_id !== user.id) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const column = kind === 'soft' ? 'cache_soft_clear_at' : 'cache_hard_clear_at';
  const now    = new Date().toISOString();

  const { error } = await supabase
    .from('apps')
    .update({ [column]: now })
    .eq('id', params.id);

  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true, kind, at: now });
}
