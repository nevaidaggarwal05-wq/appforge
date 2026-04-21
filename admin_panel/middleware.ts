// Protects all /apps, /notifications, and authenticated API routes.
// Public routes: /api/config/*, /api/apps/[id]/analytics-event, /api/apps/[id]/crash, /login, /api/auth/*

import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

const PUBLIC_PREFIXES = [
  '/login',
  '/api/auth',
  '/api/config',     // Flutter hits these — no auth
  '/_next',
  '/favicon'
];

// These API patterns are public regardless of path structure
const PUBLIC_API_SUFFIXES = [
  '/analytics-event',
  '/crash'
];

function isPublic(pathname: string): boolean {
  if (PUBLIC_PREFIXES.some(p => pathname.startsWith(p))) return true;
  if (PUBLIC_API_SUFFIXES.some(s => pathname.endsWith(s))) return true;
  return false;
}

export async function middleware(req: NextRequest) {
  const pathname = req.nextUrl.pathname;

  // Public routes bypass auth entirely
  if (isPublic(pathname)) return NextResponse.next();

  let response = NextResponse.next({ request: req });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return req.cookies.getAll(); },
        setAll(all) {
          all.forEach(({ name, value, options }) => {
            req.cookies.set(name, value);
            response.cookies.set(name, value, options);
          });
        }
      }
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    const loginUrl = new URL('/login', req.url);
    return NextResponse.redirect(loginUrl);
  }

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)']
};
