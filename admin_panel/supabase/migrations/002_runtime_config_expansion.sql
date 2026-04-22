-- ═══════════════════════════════════════════════════════════════
-- 002 — expand runtime-configurable flags + admin cache-clear timestamps
-- ═══════════════════════════════════════════════════════════════

alter table public.apps
  add column if not exists pinch_to_zoom      boolean     default true,
  add column if not exists pull_to_refresh    boolean     default true,
  add column if not exists whatsapp_number    text,
  add column if not exists whatsapp_message   text        default 'Check out this app',
  add column if not exists admob_position     text        default 'none' check (admob_position in ('none','top','bottom')),
  add column if not exists cache_soft_clear_at timestamptz,
  add column if not exists cache_hard_clear_at timestamptz;

-- Back-fill WhatsApp number from existing custom_config blobs where present.
update public.apps
   set whatsapp_number = custom_config ->> 'whatsapp_number'
 where whatsapp_number is null
   and (custom_config ->> 'whatsapp_number') is not null;
