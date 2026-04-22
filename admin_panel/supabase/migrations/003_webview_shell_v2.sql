-- ═══════════════════════════════════════════════════════════════
-- 003 — WebView Shell v2 expansion (P0/P1/P2 audit items)
-- ═══════════════════════════════════════════════════════════════

alter table public.apps
  -- Hardware + permissions gates (§5, §12.4)
  add column if not exists geolocation_enabled boolean     default false,
  add column if not exists scanner_enabled     boolean     default false,
  add column if not exists file_upload_enabled boolean     default true,
  add column if not exists downloads_enabled   boolean     default true,

  -- WebView behaviour (§1.7, §11.2, §6.9)
  add column if not exists user_agent_suffix   text,                 -- appended to default UA
  add column if not exists status_bar_style    text        default 'auto'  check (status_bar_style in ('auto','light','dark')),
  add column if not exists edge_to_edge        boolean     default true,
  add column if not exists long_press_disabled boolean     default true,
  add column if not exists extra_allowed_hosts text[]      default '{}',  -- multi-host whitelist
  add column if not exists page_load_timeout_ms integer    default 20000 check (page_load_timeout_ms between 5000 and 120000),

  -- Upload tuning (§3.8)
  add column if not exists upload_max_image_kb integer     default 1024 check (upload_max_image_kb between 100 and 10240),
  add column if not exists upload_image_quality integer    default 80   check (upload_image_quality between 30 and 100),

  -- Theme + locale (§11.10, B.16, B.17)
  add column if not exists default_locale      text        default 'en'  check (default_locale in ('en','hi')),
  add column if not exists theme_color_source  text        default 'admin' check (theme_color_source in ('admin','meta','system')),

  -- OAuth via Custom Tabs (§6.5, §8.5)
  add column if not exists oauth_custom_scheme text,                 -- e.g. 'maximoney' → maximoney://callback
  add column if not exists oauth_hosts         text[]      default '{}', -- hosts that trigger Custom Tab fallback
                                                                           -- (default: accounts.google.com, appleid.apple.com)

  -- Notification tuning (B.7)
  add column if not exists notif_badge_enabled boolean     default true;

-- Sensible defaults for any existing rows:
update public.apps
   set oauth_hosts = array['accounts.google.com','appleid.apple.com','login.microsoftonline.com']
 where oauth_hosts is null or cardinality(oauth_hosts) = 0;
