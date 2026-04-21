// ═══════════════════════════════════════════════════════════════
// GET  /api/apps   — list current user's apps
// POST /api/apps   — create a new app
// ═══════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';
import { getServerClient } from '@/lib/supabase/server';
import { slugify, isValidHex } from '@/lib/utils';
import { z } from 'zod';

const CreateSchema = z.object({
  name:           z.string().min(1).max(80),
  app_url:        z.string().url(),
  package_name:   z.string().regex(/^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$/, 'Invalid package name'),
  bundle_id:      z.string().optional(),
  theme_primary:  z.string().refine(isValidHex, 'Invalid hex color').optional(),
  theme_accent:   z.string().refine(isValidHex, 'Invalid hex color').optional(),
  slug:           z.string().optional()
});

export async function GET() {
  const supabase = getServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data, error } = await supabase
    .from('apps')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}

export async function POST(req: NextRequest) {
  const supabase = getServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = await req.json();
  const parsed = CreateSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  let slug = parsed.data.slug || slugify(parsed.data.name);
  // Fallback for non-ASCII names that produce empty slugs
  if (!slug) slug = 'app-' + Date.now().toString(36);

  const row = {
    owner_id:      user.id,
    name:          parsed.data.name,
    slug,
    package_name:  parsed.data.package_name,
    bundle_id:     parsed.data.bundle_id || parsed.data.package_name,
    app_url:       parsed.data.app_url,
    theme_primary: parsed.data.theme_primary ?? '#1A1A2E',
    theme_accent:  parsed.data.theme_accent  ?? '#E94560',
    splash_color:  parsed.data.theme_primary ?? '#1A1A2E',
    splash_text:   parsed.data.name
  };

  const { data, error } = await supabase.from('apps').insert(row).select().single();
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json(data);
}
