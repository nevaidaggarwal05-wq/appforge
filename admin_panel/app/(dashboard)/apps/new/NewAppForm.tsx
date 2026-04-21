'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { slugify } from '@/lib/utils';

export default function NewAppForm() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    name: '',
    app_url: '',
    package_name: '',
    theme_primary: '#1A1A2E',
    theme_accent:  '#E94560',
  });

  const set = <K extends keyof typeof form>(k: K, v: typeof form[K]) =>
    setForm(f => ({ ...f, [k]: v }));

  // Auto-suggest package name from app name
  const onNameChange = (name: string) => {
    const auto = name
      ? 'com.' + slugify(name).replace(/-/g, '')
      : '';
    set('name', name);
    if (!form.package_name || form.package_name === 'com.' + slugify(form.name).replace(/-/g, '')) {
      set('package_name', auto);
    }
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    const res = await fetch('/api/apps', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...form, slug: slugify(form.name) }),
    });
    setLoading(false);
    if (!res.ok) {
      const err = await res.json();
      toast.error(typeof err.error === 'string' ? err.error : 'Failed to create');
      return;
    }
    const app = await res.json();
    toast.success(`${app.name} created — configure it now`);
    router.push(`/apps/${app.id}/config`);
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      <Field label="App name" hint="Shown on the phone home screen (max 30 chars recommended)">
        <input
          required
          autoFocus
          maxLength={80}
          value={form.name}
          onChange={e => onNameChange(e.target.value)}
          className="input"
          placeholder="Maximoney"
        />
      </Field>

      <Field label="Website URL" hint="The URL the Flutter WebView will load. Change remotely anytime.">
        <input
          required
          type="url"
          value={form.app_url}
          onChange={e => set('app_url', e.target.value)}
          className="input"
          placeholder="https://credit.maximoney.in"
        />
      </Field>

      <Field
        label="Package name"
        hint="Reverse domain notation. Cannot be changed after Play Store upload."
      >
        <input
          required
          value={form.package_name}
          onChange={e => set('package_name', e.target.value)}
          className="input font-mono text-sm"
          pattern="^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$"
          placeholder="com.maximoney.credit"
        />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Primary color">
          <div className="flex items-center gap-2">
            <input
              type="color"
              value={form.theme_primary}
              onChange={e => set('theme_primary', e.target.value)}
              className="w-10 h-10 rounded border cursor-pointer"
            />
            <input
              value={form.theme_primary}
              onChange={e => set('theme_primary', e.target.value)}
              className="input font-mono text-sm"
            />
          </div>
        </Field>
        <Field label="Accent color">
          <div className="flex items-center gap-2">
            <input
              type="color"
              value={form.theme_accent}
              onChange={e => set('theme_accent', e.target.value)}
              className="w-10 h-10 rounded border cursor-pointer"
            />
            <input
              value={form.theme_accent}
              onChange={e => set('theme_accent', e.target.value)}
              className="input font-mono text-sm"
            />
          </div>
        </Field>
      </div>

      <div className="pt-2">
        <Button type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create app'}
        </Button>
      </div>
    </form>
  );
}
