-- ═══════════════════════════════════════════════════════════════
-- 004 — Per-platform AdMob banner unit IDs
--
-- Google AdMob best practice is one banner ad unit per platform —
-- separate fill optimization, separate eCPM, separate reporting.
-- We had a single `admob_banner_unit_id` field that both Android
-- and iOS shared. This migration adds an iOS-specific override.
--
-- Backward compatibility:
--   • Existing `admob_banner_unit_id` continues to be the universal
--     value (effectively the Android value).
--   • New `admob_banner_unit_id_ios` is optional. When NULL, the iOS
--     shell falls back to the universal value. When set, iOS uses
--     this and Android keeps using the universal value.
--   • Old shells that don't know about the new field keep working
--     unchanged — they read the universal field exactly like before.
-- ═══════════════════════════════════════════════════════════════

alter table public.apps
  add column if not exists admob_banner_unit_id_ios text;

comment on column public.apps.admob_banner_unit_id is
  'Banner ad unit ID used on Android (and as iOS fallback). ca-app-pub-XXX/ZZZ';
comment on column public.apps.admob_banner_unit_id_ios is
  'iOS-specific banner ad unit ID. NULL means "use admob_banner_unit_id for iOS too".';
