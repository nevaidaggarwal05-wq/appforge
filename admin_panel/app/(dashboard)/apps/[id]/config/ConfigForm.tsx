'use client';
import { useState, useMemo } from 'react';
import { toast } from 'sonner';
import { Save, CheckCircle2 } from 'lucide-react';
import type { App } from '@/lib/supabase/types';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { Field } from '@/components/ui/Field';
import { Switch } from '@/components/ui/Switch';

type FormState = App;

export default function ConfigForm({ app }: { app: App }) {
  const [f, setF]             = useState<FormState>(app);
  const [baseline, setBaseline] = useState<FormState>(app);
  const [saving, setSaving]   = useState(false);
  const [lastSavedAt, setLastSavedAt] = useState<Date | null>(null);

  const set = <K extends keyof App>(k: K, v: App[K]) => setF(prev => ({ ...prev, [k]: v }));

  // Dirty check — only show save bar if something changed vs last save (or initial load)
  const dirty = useMemo(() => {
    return JSON.stringify(f) !== JSON.stringify(baseline);
  }, [f, baseline]);

  const save = async () => {
    setSaving(true);
    const res = await fetch(`/api/apps/${app.id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(f),
    });
    setSaving(false);
    if (!res.ok) {
      const err = await res.json();
      toast.error(typeof err.error === 'string' ? err.error : 'Save failed');
      return;
    }
    toast.success('Saved — live for users within 60 seconds');
    setLastSavedAt(new Date());
    // Update baseline so dirty check resets — no prop mutation
    setBaseline(f);
  };

  return (
    <div className="space-y-5 pb-24">
      {/* ── Core ────────────────────────────────────── */}
      <Card title="Core" description="The essential identity and URL. Package name is immutable.">
        <Field label="Name">
          <input value={f.name} onChange={e => set('name', e.target.value)} className="input" maxLength={80} />
        </Field>
        <Field label="Website URL" hint="Changes propagate to all users within 60 seconds on next app open.">
          <input value={f.app_url} onChange={e => set('app_url', e.target.value)} className="input" />
        </Field>
        <Field label="Package name" hint="Cannot change after Play Store submission.">
          <input value={f.package_name} disabled className="input font-mono text-sm" />
        </Field>
      </Card>

      {/* ── Theme ───────────────────────────────────── */}
      <Card title="Theme" description="Primary = app background + splash. Accent = buttons + progress bars.">
        <div className="grid grid-cols-2 gap-4">
          <Field label="Primary color">
            <div className="flex gap-2">
              <input type="color" value={f.theme_primary} onChange={e => set('theme_primary', e.target.value)}
                className="w-10 h-10 rounded border cursor-pointer" />
              <input value={f.theme_primary} onChange={e => set('theme_primary', e.target.value)}
                className="input font-mono text-sm" />
            </div>
          </Field>
          <Field label="Accent color">
            <div className="flex gap-2">
              <input type="color" value={f.theme_accent} onChange={e => set('theme_accent', e.target.value)}
                className="w-10 h-10 rounded border cursor-pointer" />
              <input value={f.theme_accent} onChange={e => set('theme_accent', e.target.value)}
                className="input font-mono text-sm" />
            </div>
          </Field>
        </div>
      </Card>

      {/* ── Splash ──────────────────────────────────── */}
      <Card title="Splash screen" description="Branded loading screen shown for ~2 seconds on app open.">
        <Field label="Splash screen enabled" inline hint="Off = instant transition to WebView">
          <Switch checked={f.splash_enabled} onChange={v => set('splash_enabled', v)} />
        </Field>
        <Field label="Splash background color">
          <div className="flex gap-2">
            <input type="color" value={f.splash_color} onChange={e => set('splash_color', e.target.value)}
              className="w-10 h-10 rounded border cursor-pointer" />
            <input value={f.splash_color} onChange={e => set('splash_color', e.target.value)}
              className="input font-mono text-sm" />
          </div>
        </Field>
        <Field label="Splash text" hint="Shown below the app icon. Leave blank to use app name.">
          <input value={f.splash_text || ''} onChange={e => set('splash_text', e.target.value)}
            className="input" placeholder={f.name} />
        </Field>
        <Field label="Splash logo URL" hint="Optional custom image. Must be HTTPS.">
          <input value={f.splash_logo_url || ''} onChange={e => set('splash_logo_url', e.target.value)}
            className="input" placeholder="https://..." />
        </Field>
        <Field label={`Duration: ${f.splash_duration_ms}ms (${(f.splash_duration_ms / 1000).toFixed(1)}s)`}>
          <input type="range" min={500} max={5000} step={100}
            value={f.splash_duration_ms} onChange={e => set('splash_duration_ms', Number(e.target.value))}
            className="w-full" />
        </Field>
      </Card>

      {/* ── Feature flags ───────────────────────────── */}
      <Card title="Feature flags" description="Toggle per-app features. Changes live within 60 seconds.">
        <Field label="WhatsApp share button" inline hint="Floating FAB to share the app on WhatsApp">
          <Switch checked={f.whatsapp_share} onChange={v => set('whatsapp_share', v)} />
        </Field>
        <Field label="Biometric auth bridge" inline hint="Enables flutter.biometric() JS bridge for fingerprint/Face ID">
          <Switch checked={f.biometric_auth} onChange={v => set('biometric_auth', v)} />
        </Field>
        <Field label="AdMob banner ads" inline hint="Requires AdMob IDs in the section below">
          <Switch checked={f.admob_enabled} onChange={v => set('admob_enabled', v)} />
        </Field>
        <Field label="Dark mode support" inline hint="Follows system preference, injects CSS class into WebView">
          <Switch checked={f.dark_mode} onChange={v => set('dark_mode', v)} />
        </Field>
        <Field label="Block screenshots" inline hint="FLAG_SECURE on Android + hide window on iOS">
          <Switch checked={f.screenshot_block} onChange={v => set('screenshot_block', v)} />
        </Field>
        <Field label="Block rooted/jailbroken devices" inline hint="Hard block — app refuses to run">
          <Switch checked={f.root_block} onChange={v => set('root_block', v)} />
        </Field>
        <Field label="Session persistence" inline hint="Remember last URL + scroll position on cold start">
          <Switch checked={f.session_persistence} onChange={v => set('session_persistence', v)} />
        </Field>
        <Field label="Network quality detection" inline hint="Adds ?network=slow to URL on 2G/3G for lite mode">
          <Switch checked={f.network_detection} onChange={v => set('network_detection', v)} />
        </Field>
      </Card>

      {/* ── Force update ────────────────────────────── */}
      <Card title="Force update" description="Blocks users below this version code. Set 0 to disable.">
        <Field label="Minimum versionCode" hint="Users with lower versionCode see the Update Required screen">
          <input type="number" min={0} value={f.force_update_version}
            onChange={e => set('force_update_version', Number(e.target.value))} className="input" />
        </Field>
        <Field label="Update message">
          <input value={f.force_update_message || ''} onChange={e => set('force_update_message', e.target.value)}
            className="input" placeholder="A new version is available. Please update to continue." />
        </Field>
        <Field label="Changelog (optional, shown in a box)">
          <textarea value={f.update_changelog || ''} onChange={e => set('update_changelog', e.target.value)}
            className="input min-h-[80px]" placeholder="• New: Biometric login&#10;• Fixed: Crash on slow networks" />
        </Field>
      </Card>

      {/* ── Soft update ─────────────────────────────── */}
      <Card title="Soft update" description="Non-blocking banner. Users can keep using the app.">
        <Field label="Soft update versionCode" hint="Users below this see a dismissible update banner. 0 = off.">
          <input type="number" min={0} value={f.soft_update_version}
            onChange={e => set('soft_update_version', Number(e.target.value))} className="input" />
        </Field>
        <Field label="Banner message">
          <input value={f.soft_update_message || ''} onChange={e => set('soft_update_message', e.target.value)}
            className="input" placeholder="A new version is available" />
        </Field>
      </Card>

      {/* ── AdMob (conditional) ─────────────────────── */}
      {f.admob_enabled && (
        <Card title="AdMob" description="Required when AdMob ads are enabled above.">
          <Field label="AdMob App ID">
            <input value={f.admob_app_id || ''} onChange={e => set('admob_app_id', e.target.value)}
              className="input font-mono text-sm" placeholder="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX" />
          </Field>
          <Field label="Banner ad unit ID">
            <input value={f.admob_banner_unit_id || ''} onChange={e => set('admob_banner_unit_id', e.target.value)}
              className="input font-mono text-sm" placeholder="ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX" />
          </Field>
        </Card>
      )}

      {/* ── Store links ─────────────────────────────── */}
      <Card title="Store links" description="Used by the Update and Rate-us prompts. Fill in after publish.">
        <Field label="Play Store URL">
          <input value={f.play_store_url || ''} onChange={e => set('play_store_url', e.target.value)}
            className="input" placeholder="https://play.google.com/store/apps/details?id=..." />
        </Field>
        <Field label="App Store URL">
          <input value={f.app_store_url || ''} onChange={e => set('app_store_url', e.target.value)}
            className="input" placeholder="https://apps.apple.com/app/id..." />
        </Field>
      </Card>

      {/* ── Custom config (escape hatch) ─────────────── */}
      <Card title="Custom config" description="Per-app JSON values the Flutter app can read (e.g. UPI IDs, API keys).">
        <Field label="JSON (advanced)">
          <textarea
            defaultValue={JSON.stringify(f.custom_config, null, 2)}
            onBlur={e => {
              try {
                const parsed = JSON.parse(e.target.value);
                set('custom_config', parsed);
              } catch {
                toast.error('Invalid JSON');
              }
            }}
            className="input font-mono text-xs min-h-[120px]"
            placeholder={'{\n  "upi_merchant_id": "abc@ybl"\n}'}
          />
        </Field>
      </Card>

      {/* ── Sticky save bar ─────────────────────────── */}
      {(dirty || lastSavedAt) && (
        <div className="fixed bottom-4 left-1/2 -translate-x-1/2 max-w-lg w-[calc(100%-32px)] save-bar bg-background border rounded-lg p-3 flex items-center justify-between z-50">
          <div className="text-xs text-muted-foreground pl-2">
            {dirty ? 'Unsaved changes' : lastSavedAt ? (
              <span className="text-green-700 dark:text-green-300 flex items-center gap-1">
                <CheckCircle2 size={12} /> Saved {lastSavedAt.toLocaleTimeString()}
              </span>
            ) : null}
          </div>
          <Button onClick={save} disabled={saving || !dirty}>
            <Save size={14} /> {saving ? 'Saving...' : 'Save changes'}
          </Button>
        </div>
      )}
    </div>
  );
}
