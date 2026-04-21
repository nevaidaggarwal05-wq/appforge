import Link from 'next/link';
import { ChevronRight, Bell } from 'lucide-react';
import { getServerClient } from '@/lib/supabase/server';
import type { App } from '@/lib/supabase/types';

export const dynamic = 'force-dynamic';

export default async function NotificationsHub() {
  const supabase = getServerClient();
  const { data: apps } = await supabase
    .from('apps')
    .select('id, name, package_name, android_status')
    .order('name');

  return (
    <div>
      <header className="mb-6">
        <h1 className="text-2xl font-bold">Notifications</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Select an app to compose and send a notification.
        </p>
      </header>

      {(!apps || apps.length === 0) ? (
        <div className="rounded-lg border border-dashed py-16 text-center">
          <Bell className="mx-auto mb-3 text-muted-foreground" size={32} />
          <p className="text-muted-foreground">Create an app first</p>
          <Link href="/apps/new" className="text-sm text-primary underline mt-2 inline-block">
            New app
          </Link>
        </div>
      ) : (
        <div className="rounded-lg border overflow-hidden">
          {(apps as Pick<App, 'id' | 'name' | 'package_name' | 'android_status'>[]).map((a, i) => (
            <Link
              key={a.id}
              href={`/apps/${a.id}/notifications`}
              className={`flex items-center justify-between p-4 hover:bg-muted transition-colors ${i > 0 ? 'border-t' : ''}`}
            >
              <div>
                <div className="font-medium">{a.name}</div>
                <div className="text-xs text-muted-foreground font-mono mt-0.5">{a.package_name}</div>
              </div>
              <ChevronRight size={16} className="text-muted-foreground" />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
