import { notFound } from 'next/navigation';
import { getServerClient } from '@/lib/supabase/server';
import type { App } from '@/lib/supabase/types';
import AppHeader from '../AppHeader';
import ConfigForm from './ConfigForm';

export const dynamic = 'force-dynamic';

export default async function ConfigPage({ params }: { params: { id: string } }) {
  const supabase = getServerClient();
  const { data: app } = await supabase
    .from('apps').select('*').eq('id', params.id).maybeSingle<App>();
  if (!app) notFound();

  return (
    <div>
      <AppHeader app={app} />
      <ConfigForm app={app} />
    </div>
  );
}
