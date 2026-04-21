// Root route. If Supabase redirects here with ?code=... (magic-link flow),
// exchange the code for a session before sending the user on to /apps.
import { redirect } from 'next/navigation';
import { getServerClient } from '@/lib/supabase/server';

export default async function Home({
  searchParams,
}: {
  searchParams: { code?: string };
}) {
  if (searchParams?.code) {
    const supabase = getServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(searchParams.code);
    if (error) {
      redirect(`/login?error=${encodeURIComponent(error.message)}`);
    }
  }
  redirect('/apps');
}
