// Root route. If Supabase redirects here with ?code=... (magic-link flow),
// hand off to the /auth/callback Route Handler (Server Components can't set cookies).
import { redirect } from 'next/navigation';

export default function Home({
  searchParams,
}: {
  searchParams: { code?: string };
}) {
  if (searchParams?.code) {
    redirect(`/auth/callback?code=${encodeURIComponent(searchParams.code)}`);
  }
  redirect('/apps');
}
