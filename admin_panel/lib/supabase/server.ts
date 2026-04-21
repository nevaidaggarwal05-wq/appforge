// Server-side Supabase clients.
// Use getServerClient() in server components + route handlers (respects user session / RLS).
// Use getAdminClient() ONLY in public API routes that need to bypass RLS (config fetch, event logging).

import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { createClient } from '@supabase/supabase-js';

export function getServerClient() {
  const cookieStore = cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll()    { return cookieStore.getAll(); },
        setAll(all: { name: string; value: string; options?: Record<string, unknown> }[]) {
          try {
            all.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            // Server Components (read-only render pass) cannot set cookies.
            // This is expected and safe — cookies will be set by the Server Action
            // or Route Handler that triggered the request.
          }
        }
      }
    }
  );
}

export function getAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  );
}
