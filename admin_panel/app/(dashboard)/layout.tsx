import Link from 'next/link';
import { Smartphone, Bell, LogOut, Settings } from 'lucide-react';
import { getServerClient } from '@/lib/supabase/server';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = getServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  return (
    <div className="min-h-screen flex">
      <aside className="w-60 bg-muted border-r flex flex-col">
        <div className="p-5 border-b">
          <Link href="/apps" className="text-lg font-bold block">AppForge</Link>
        </div>

        <nav className="flex-1 p-3 space-y-1">
          <NavLink href="/apps"          icon={<Smartphone size={16} />}>Apps</NavLink>
          <NavLink href="/notifications" icon={<Bell size={16} />}>Notifications</NavLink>
        </nav>

        <div className="p-3 border-t">
          <div className="text-xs text-muted-foreground mb-2 px-2 truncate" title={user?.email || ''}>
            {user?.email}
          </div>
          <form action="/api/auth/signout" method="post">
            <button
              type="submit"
              className="w-full flex items-center gap-2 px-2 py-1.5 rounded text-sm text-muted-foreground hover:bg-background hover:text-foreground transition-colors"
            >
              <LogOut size={14} /> Sign out
            </button>
          </form>
        </div>
      </aside>
      <main className="flex-1 overflow-y-auto">
        <div className="max-w-5xl mx-auto p-8">{children}</div>
      </main>
    </div>
  );
}

function NavLink({ href, icon, children }: { href: string; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="flex items-center gap-2 px-3 py-2 rounded text-sm hover:bg-background transition-colors"
    >
      {icon}
      {children}
    </Link>
  );
}
