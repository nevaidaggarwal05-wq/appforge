import { notFound } from 'next/navigation';
import { getServerClient } from '@/lib/supabase/server';
import type { App } from '@/lib/supabase/types';
import AppHeader from '../AppHeader';
import { Card } from '@/components/ui/Card';
import { BarChart3, AlertTriangle, Smartphone } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function AnalyticsPage({ params }: { params: { id: string } }) {
  const supabase = getServerClient();

  const { data: app } = await supabase
    .from('apps').select('*').eq('id', params.id).maybeSingle<App>();
  if (!app) notFound();

  // Parallel fetches
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const [eventsResp, crashesResp, devicesResp] = await Promise.all([
    supabase.from('analytics_events')
      .select('event_name, created_at, platform')
      .eq('app_id', params.id)
      .gte('created_at', since)
      .order('created_at', { ascending: false })
      .limit(500),
    supabase.from('app_crashes')
      .select('id, error, created_at, app_version')
      .eq('app_id', params.id)
      .order('created_at', { ascending: false })
      .limit(20),
    supabase.from('fcm_tokens')
      .select('platform, device_model, os_version, last_seen_at', { count: 'exact' })
      .eq('app_id', params.id)
      .gte('last_seen_at', since)
      .limit(100),
  ]);

  const events  = eventsResp.data || [];
  const crashes = crashesResp.data || [];
  const tokens  = devicesResp.data || [];

  // Aggregate events by name
  const eventCounts: Record<string, number> = {};
  for (const e of events) {
    eventCounts[e.event_name] = (eventCounts[e.event_name] || 0) + 1;
  }
  const topEvents = Object.entries(eventCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);

  // Platform split
  const platformCounts = { android: 0, ios: 0, web: 0 };
  for (const t of tokens) {
    if (t.platform in platformCounts) (platformCounts as any)[t.platform]++;
  }

  return (
    <div>
      <AppHeader app={app} />

      <div className="grid grid-cols-3 gap-4 mb-5">
        <StatCard
          title="Active devices (7d)"
          value={devicesResp.count || 0}
          icon={<Smartphone size={18} />}
          sub={`Android: ${platformCounts.android} · iOS: ${platformCounts.ios}`}
        />
        <StatCard
          title="Events (7d)"
          value={events.length}
          icon={<BarChart3 size={18} />}
          sub={events.length >= 500 ? '500+ (capped)' : 'All events in last 7 days'}
        />
        <StatCard
          title="Crashes (all time)"
          value={crashes.length}
          icon={<AlertTriangle size={18} />}
          sub={crashes.length >= 20 ? '20+ (latest shown)' : 'Recent crash reports'}
        />
      </div>

      <Card title="Top events (last 7 days)">
        {topEvents.length === 0 ? (
          <p className="text-sm text-muted-foreground">No events yet. Flutter apps log events via <code className="bg-muted px-1 rounded text-xs">window.flutter.track(name, props)</code>.</p>
        ) : (
          <div className="space-y-2">
            {topEvents.map(([name, count]) => {
              const maxCount = topEvents[0][1];
              const pct = (count / maxCount) * 100;
              return (
                <div key={name} className="flex items-center gap-3">
                  <div className="w-40 text-sm font-mono truncate">{name}</div>
                  <div className="flex-1 bg-muted h-6 rounded relative overflow-hidden">
                    <div
                      className="absolute inset-y-0 left-0 bg-primary rounded transition-all"
                      style={{ width: `${pct}%` }}
                    />
                    <div className="absolute inset-0 flex items-center px-2 text-xs font-medium">
                      {count}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </Card>

      <div className="mt-5">
        <Card title="Recent crashes" description="Also available in Firebase Crashlytics console for the shared project.">
          {crashes.length === 0 ? (
            <p className="text-sm text-muted-foreground">No crashes reported. 🎉</p>
          ) : (
            <div className="space-y-2">
              {crashes.map(c => (
                <details key={c.id} className="rounded border">
                  <summary className="p-3 cursor-pointer text-sm hover:bg-muted flex items-center justify-between">
                    <span className="font-mono truncate mr-3">{c.error}</span>
                    <span className="text-xs text-muted-foreground whitespace-nowrap">
                      v{c.app_version || '?'} · {new Date(c.created_at).toLocaleString()}
                    </span>
                  </summary>
                </details>
              ))}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon, sub }: { title: string; value: number; icon: React.ReactNode; sub: string }) {
  return (
    <div className="card">
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm text-muted-foreground">{title}</span>
        <span className="text-muted-foreground">{icon}</span>
      </div>
      <div className="text-2xl font-bold">{value.toLocaleString()}</div>
      <div className="text-xs text-muted-foreground mt-1">{sub}</div>
    </div>
  );
}
