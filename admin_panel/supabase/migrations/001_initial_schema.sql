-- ═══════════════════════════════════════════════════════════════
-- AppForge v5 schema — one panel, many apps
-- Run this in Supabase SQL Editor or via `supabase db push`
-- ═══════════════════════════════════════════════════════════════

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ── apps: one row per Flutter app ──────────────────────────────
create table if not exists public.apps (
  id                    uuid primary key default uuid_generate_v4(),
  owner_id              uuid references auth.users(id) on delete cascade,

  -- identity
  name                  text not null,
  slug                  text unique not null,
  package_name          text unique not null,
  bundle_id             text,
  icon_url              text,

  -- core config (changeable remotely)
  app_url               text not null,

  -- theme
  theme_primary         text default '#1A1A2E',
  theme_accent          text default '#E94560',

  -- splash
  splash_enabled        boolean default true,
  splash_color          text default '#1A1A2E',
  splash_text           text,
  splash_logo_url       text,
  splash_duration_ms    integer default 2000,

  -- feature flags
  whatsapp_share        boolean default false,
  biometric_auth        boolean default false,
  admob_enabled         boolean default false,
  dark_mode             boolean default true,
  screenshot_block      boolean default true,
  root_block            boolean default true,
  session_persistence   boolean default true,
  network_detection     boolean default true,

  -- updates
  force_update_version  integer default 0,
  force_update_message  text,
  update_changelog      text,
  soft_update_version   integer default 0,
  soft_update_message   text,

  -- admob ids (only used when enabled)
  admob_app_id          text,
  admob_banner_unit_id  text,

  -- store links (fill after publish)
  play_store_url        text,
  app_store_url         text,

  -- build metadata
  version_code          integer default 1,
  version_name          text default '1.0.0',
  sha256_fingerprint    text,

  -- status tracking
  android_status        text default 'draft' check (android_status in ('draft','building','testing','live')),
  ios_status            text default 'draft' check (ios_status in ('draft','building','testing','live')),

  -- per-app escape hatch for custom values
  custom_config         jsonb default '{}'::jsonb,

  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

create index if not exists idx_apps_slug  on public.apps(slug);
create index if not exists idx_apps_owner on public.apps(owner_id);

-- ── fcm_tokens: one row per device per app ─────────────────────
create table if not exists public.fcm_tokens (
  id            uuid primary key default uuid_generate_v4(),
  app_id        uuid not null references public.apps(id) on delete cascade,
  token         text not null,
  platform      text not null check (platform in ('android','ios','web')),
  device_model  text,
  os_version    text,
  app_version   text,
  last_seen_at  timestamptz default now(),
  created_at    timestamptz default now(),
  unique(app_id, token)
);

create index if not exists idx_fcm_app on public.fcm_tokens(app_id);

-- ── notifications: history + queue ─────────────────────────────
create table if not exists public.notifications (
  id               uuid primary key default uuid_generate_v4(),
  app_id           uuid not null references public.apps(id) on delete cascade,

  title            text not null,
  body             text not null,
  image_url        text,
  deep_link_url    text,
  category         text default 'transactional' check (category in ('transactional','promotional','alerts')),

  target_type      text not null default 'all' check (target_type in ('all','topic','tokens','segment')),
  target_value     text,

  status           text default 'draft' check (status in ('draft','scheduled','sending','sent','failed')),
  scheduled_at     timestamptz,
  sent_at          timestamptz,

  recipients_count integer default 0,
  success_count    integer default 0,
  failure_count    integer default 0,
  error_message    text,

  created_by       uuid references auth.users(id),
  created_at       timestamptz default now()
);

create index if not exists idx_notif_app  on public.notifications(app_id, created_at desc);
create index if not exists idx_notif_sched on public.notifications(status, scheduled_at)
  where status = 'scheduled';

-- ── analytics_events: custom events from Flutter apps ──────────
create table if not exists public.analytics_events (
  id           bigserial primary key,
  app_id       uuid not null references public.apps(id) on delete cascade,
  event_name   text not null,
  properties   jsonb default '{}'::jsonb,
  user_id      text,
  device_id    text,
  platform     text,
  app_version  text,
  created_at   timestamptz default now()
);

create index if not exists idx_events_app_time on public.analytics_events(app_id, created_at desc);
create index if not exists idx_events_name     on public.analytics_events(app_id, event_name);

-- ── app_crashes: lightweight crash log ────────────────────────
create table if not exists public.app_crashes (
  id           bigserial primary key,
  app_id       uuid not null references public.apps(id) on delete cascade,
  error        text not null,
  stack_trace  text,
  device_info  jsonb,
  app_version  text,
  created_at   timestamptz default now()
);

create index if not exists idx_crashes_app on public.app_crashes(app_id, created_at desc);

-- ── triggers ───────────────────────────────────────────────────
create or replace function public.update_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists trg_apps_updated on public.apps;
create trigger trg_apps_updated
  before update on public.apps
  for each row execute function public.update_updated_at();

-- ── Row-level security ─────────────────────────────────────────
alter table public.apps              enable row level security;
alter table public.fcm_tokens        enable row level security;
alter table public.notifications     enable row level security;
alter table public.analytics_events  enable row level security;
alter table public.app_crashes       enable row level security;

drop policy if exists "apps_owner_all"   on public.apps;
drop policy if exists "fcm_owner_all"    on public.fcm_tokens;
drop policy if exists "notif_owner_all"  on public.notifications;
drop policy if exists "events_owner_read" on public.analytics_events;
drop policy if exists "crashes_owner_read" on public.app_crashes;

-- Owner-only access (single-user admin for now; easy to extend)
create policy "apps_owner_all" on public.apps
  for all using (auth.uid() = owner_id);

create policy "fcm_owner_all" on public.fcm_tokens
  for all using (exists(select 1 from public.apps a where a.id = fcm_tokens.app_id and a.owner_id = auth.uid()));

create policy "notif_owner_all" on public.notifications
  for all using (exists(select 1 from public.apps a where a.id = notifications.app_id and a.owner_id = auth.uid()));

create policy "events_owner_read" on public.analytics_events
  for select using (exists(select 1 from public.apps a where a.id = analytics_events.app_id and a.owner_id = auth.uid()));

create policy "crashes_owner_read" on public.app_crashes
  for select using (exists(select 1 from public.apps a where a.id = app_crashes.app_id and a.owner_id = auth.uid()));

-- Note: public endpoints (/api/config/*, /api/apps/*/analytics-event, /api/apps/*/crash)
-- use the service_role key which bypasses RLS. That's intentional — Flutter apps
-- don't have user context, only their own appId.
