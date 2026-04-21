import { notFound } from 'next/navigation';
import { getServerClient } from '@/lib/supabase/server';
import type { App, Notification } from '@/lib/supabase/types';
import AppHeader from '../AppHeader';
import NotificationComposer from './NotificationComposer';

export const dynamic = 'force-dynamic';

export default async function NotifPage({ params }: { params: { id: string } }) {
  const supabase = getServerClient();
  const [
    { data: app },
    { data: history }
  ] = await Promise.all([
    supabase.from('apps').select('*').eq('id', params.id).maybeSingle<App>(),
    supabase.from('notifications').select('*').eq('app_id', params.id)
      .order('created_at', { ascending: false }).limit(20),
  ]);

  if (!app) notFound();

  return (
    <div>
      <AppHeader app={app} />
      <NotificationComposer app={app} history={(history as Notification[]) || []} />
    </div>
  );
}
