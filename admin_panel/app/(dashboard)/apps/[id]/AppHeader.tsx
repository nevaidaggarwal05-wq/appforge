'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Download, Bell, Settings, BarChart3, ChevronLeft, Trash2 } from 'lucide-react';
import { toast } from 'sonner';
import type { App } from '@/lib/supabase/types';
import { cn } from '@/lib/utils';

export default function AppHeader({ app }: { app: App }) {
  const pathname = usePathname();
  const base = `/apps/${app.id}`;

  const tabs = [
    { href: `${base}/config`,        label: 'Config',        icon: Settings },
    { href: `${base}/notifications`, label: 'Notifications', icon: Bell },
    { href: `${base}/analytics`,     label: 'Analytics',     icon: BarChart3 },
  ];

  const onDelete = async () => {
    if (!confirm(`Delete ${app.name}? This removes ALL its data (notifications, events, tokens). Cannot be undone.`)) return;
    const res = await fetch(`/api/apps/${app.id}`, { method: 'DELETE' });
    if (!res.ok) { toast.error('Delete failed'); return; }
    toast.success('App deleted');
    window.location.href = '/apps';
  };

  return (
    <div className="mb-6">
      <Link href="/apps" className="text-sm text-muted-foreground flex items-center gap-1 mb-3 hover:text-foreground">
        <ChevronLeft size={14} /> Back to apps
      </Link>

      <div className="flex items-start justify-between mb-4">
        <div>
          <h1 className="text-2xl font-bold">{app.name}</h1>
          <p className="text-xs text-muted-foreground font-mono mt-1">{app.package_name}</p>
        </div>
        <div className="flex gap-2">
          <a href={`/api/generator/${app.id}`} className="btn-secondary">
            <Download size={14} /> Flutter ZIP
          </a>
          <button onClick={onDelete} className="btn-danger">
            <Trash2 size={14} /> Delete
          </button>
        </div>
      </div>

      <nav className="flex gap-1 border-b">
        {tabs.map(t => {
          const active = pathname === t.href || pathname.startsWith(t.href + '/');
          const Icon = t.icon;
          return (
            <Link
              key={t.href}
              href={t.href}
              className={cn(
                'px-3 py-2 text-sm flex items-center gap-1.5 border-b-2 -mb-px transition-colors',
                active
                  ? 'border-primary text-foreground font-medium'
                  : 'border-transparent text-muted-foreground hover:text-foreground'
              )}
            >
              <Icon size={14} /> {t.label}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
