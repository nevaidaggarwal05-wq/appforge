'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { Send } from 'lucide-react';
import type { App, Notification } from '@/lib/supabase/types';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { Field } from '@/components/ui/Field';

export default function NotificationComposer({
  app,
  history
}: {
  app: App;
  history: Notification[];
}) {
  const router = useRouter();
  const [title, setTitle]       = useState('');
  const [body, setBody]         = useState('');
  const [url, setUrl]           = useState('');
  const [category, setCategory] = useState<'transactional' | 'promotional' | 'alerts'>('transactional');
  const [sending, setSending]   = useState(false);

  const send = async () => {
    if (!title || !body) { toast.error('Title and body required'); return; }
    setSending(true);
    const res = await fetch('/api/notifications/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        app_id:        app.id,
        title,
        body,
        deep_link_url: url || null,
        category,
        target_type:   'all',
      }),
    });
    setSending(false);
    const json = await res.json();
    if (json.ok) {
      toast.success(`Sent to ${app.name} users`);
      setTitle(''); setBody(''); setUrl('');
      router.refresh();
    } else {
      toast.error(`Failed: ${json.result?.error || 'Unknown error'}`);
    }
  };

  return (
    <div className="space-y-5">
      <Card
        title="Compose notification"
        description={`Send to all devices running ${app.name}.`}
      >
        <Field label="Title" hint={`${title.length}/65`}>
          <input
            value={title}
            onChange={e => setTitle(e.target.value)}
            className="input"
            maxLength={65}
            placeholder="Your loan is approved!"
          />
        </Field>

        <Field label="Body" hint={`${body.length}/240`}>
          <textarea
            value={body}
            onChange={e => setBody(e.target.value)}
            className="input min-h-[80px]"
            maxLength={240}
            placeholder="Tap to view details and complete disbursement."
          />
        </Field>

        <Field label="Deep link URL (optional)" hint="Opens this URL in the WebView when the notification is tapped">
          <input
            value={url}
            onChange={e => setUrl(e.target.value)}
            className="input"
            placeholder="https://credit.maximoney.in/approval"
          />
        </Field>

        <Field label="Category">
          <select
            value={category}
            onChange={e => setCategory(e.target.value as any)}
            className="input"
          >
            <option value="transactional">Transactional — order updates, confirmations</option>
            <option value="alerts">Alerts — security, important updates</option>
            <option value="promotional">Promotional — offers, campaigns (users can opt out)</option>
          </select>
        </Field>

        <div className="pt-2">
          <Button onClick={send} disabled={sending || !title || !body} className="w-full">
            <Send size={14} /> {sending ? 'Sending...' : `Send to all ${app.name} users`}
          </Button>
        </div>
      </Card>

      {history.length > 0 && (
        <Card title={`Recent notifications (${history.length})`}>
          <div className="rounded border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted">
                <tr className="text-xs text-muted-foreground text-left">
                  <th className="p-2 font-medium">Title</th>
                  <th className="p-2 font-medium">Category</th>
                  <th className="p-2 font-medium">Sent</th>
                  <th className="p-2 font-medium">Status</th>
                </tr>
              </thead>
              <tbody>
                {history.map(n => (
                  <tr key={n.id} className="border-t">
                    <td className="p-2" title={n.body}>{n.title}</td>
                    <td className="p-2">
                      <span className="text-xs px-1.5 py-0.5 rounded bg-muted">{n.category}</span>
                    </td>
                    <td className="p-2 text-muted-foreground text-xs">
                      {n.sent_at ? new Date(n.sent_at).toLocaleString() : new Date(n.created_at).toLocaleString()}
                    </td>
                    <td className="p-2">
                      <StatusBadge status={n.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: Notification['status'] }) {
  const colors: Record<Notification['status'], string> = {
    draft:     'bg-muted text-muted-foreground',
    scheduled: 'bg-yellow-100 text-yellow-900 dark:bg-yellow-950 dark:text-yellow-200',
    sending:   'bg-blue-100 text-blue-900 dark:bg-blue-950 dark:text-blue-200',
    sent:      'bg-green-100 text-green-900 dark:bg-green-950 dark:text-green-200',
    failed:    'bg-red-100 text-red-900 dark:bg-red-950 dark:text-red-200',
  };
  return <span className={`text-xs px-2 py-0.5 rounded ${colors[status]}`}>{status}</span>;
}
