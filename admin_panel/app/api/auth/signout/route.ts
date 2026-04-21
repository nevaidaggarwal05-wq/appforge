import { NextResponse } from 'next/server';
import { getServerClient } from '@/lib/supabase/server';

export async function POST() {
  const supabase = getServerClient();
  await supabase.auth.signOut();
  const url = new URL('/login', process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000');
  // 303 converts POST -> GET redirect, required after form submission
  return NextResponse.redirect(url, { status: 303 });
}
