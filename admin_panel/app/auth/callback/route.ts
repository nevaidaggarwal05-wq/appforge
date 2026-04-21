// Handles the ?code=... redirect from Supabase magic-link emails.
// Exchanges the code for a session cookie, then sends the user to /apps.
import { NextRequest, NextResponse } from 'next/server';
import { getServerClient } from '@/lib/supabase/server';

export async function GET(req: NextRequest) {
  const url  = new URL(req.url);
  const code = url.searchParams.get('code');
  const next = url.searchParams.get('next') ?? '/apps';

  if (code) {
    const supabase = getServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(new URL(next, url.origin));
    }
    return NextResponse.redirect(
      new URL(`/login?error=${encodeURIComponent(error.message)}`, url.origin)
    );
  }
  return NextResponse.redirect(new URL('/login', url.origin));
}
