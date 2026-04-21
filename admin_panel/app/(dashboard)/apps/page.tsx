import Link from 'next/link';
import { Plus, Download, Settings, Bell, Smartphone } from 'lucide-react';
import { getServerClient } from '@/lib/supabase/server';
import type { App } from '@/lib/supabase/types';

export const dynamic = 'force-dynamic';

export default async function AppsPage() {
  const supabase = getServerClient();
  const { data: apps } = await supabase
    .from('apps')
    .select('*')
    .order('created_at', { ascending: false });

  return (
    <div>
      <header className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold">Apps</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Manage all your white-label mobile apps from here. Changes propagate to users in ~60 seconds.
          </p>
        </div>
        <Link
          href="/apps/new"
          className="btn-primary whitespace-nowrap"
        >
          <Plus size={16} /> New App
        </Link>
      </header>

      {(!apps || apps.length === 0) ? (
        <EmptyState />
      ) : (
        <div className="rounded-lg border overflow-hidden">
          <table className="w-full">
            <thead className="bg-muted">
              <tr className="text-left text-xs text-muted-foreground">
                <th className="p-3 font-medium">Name</th>
                <th className="p-3 font-medium">URL</th>
                <th className="p-3 font-medium">Package</th>
                <th className="p-3 font-medium">Android</th>
                <th className="p-3 font-medium w-32">Actions</th>
              </tr>
            </thead>
            <tbody>
              {(apps as App[]).map(app => (
                <tr key={app.id} className="border-t hover:bg-muted/50 transition-colors">
                  <td className="p-3">
                    <Link href={`/apps/${app.id}/config`} className="font-medium hover:underline">
                      {app.name}
                    </Link>
                  </td>
                  <td className="p-3 text-sm text-muted-foreground truncate max-w-[220px]">
                    {app.app_url}
                  </td>
                  <td className="p-3 text-xs text-muted-foreground font-mono">{app.package_name}</td>
                  <td className="p-3">
                    <span className={`badge badge-${app.android_status}`}>{app.android_status}</span>
                  </td>
                  <td className="p-3">
                    <div className="flex gap-1">
                      <Link
                        href={`/apps/${app.id}/config`}
                        title="Config"
                        className="p-1.5 hover:bg-muted rounded"
                      ><Settings size={15} /></Link>
                      <Link
                        href={`/apps/${app.id}/notifications`}
                        title="Notifications"
                        className="p-1.5 hover:bg-muted rounded"
                      ><Bell size={15} /></Link>
                      <a
                        href={`/api/generator/${app.id}`}
                        title="Download Flutter ZIP"
                        className="p-1.5 hover:bg-muted rounded"
                      ><Download size={15} /></a>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function EmptyState() {
  return (
    <div className="rounded-lg border border-dashed py-16 text-center">
      <Smartphone className="mx-auto mb-3 text-muted-foreground" size={32} />
      <p className="text-muted-foreground mb-4">No apps yet</p>
      <Link href="/apps/new" className="btn-primary inline-flex">
        <Plus size={16} /> Create your first app
      </Link>
    </div>
  );
}
