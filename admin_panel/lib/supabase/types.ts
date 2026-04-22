// ═══════════════════════════════════════════════════════════════
// Database row types — kept in sync with migrations/001_initial_schema.sql
// ═══════════════════════════════════════════════════════════════

export type AppStatus = 'draft' | 'building' | 'testing' | 'live';
export type NotificationCategory = 'transactional' | 'promotional' | 'alerts';
export type NotificationTarget = 'all' | 'topic' | 'tokens' | 'segment';
export type NotificationStatus = 'draft' | 'scheduled' | 'sending' | 'sent' | 'failed';

export interface App {
  id: string;
  owner_id: string | null;

  // identity
  name: string;
  slug: string;
  package_name: string;
  bundle_id: string | null;
  icon_url: string | null;

  // core
  app_url: string;

  // theme
  theme_primary: string;
  theme_accent: string;

  // splash
  splash_enabled: boolean;
  splash_color: string;
  splash_text: string | null;
  splash_logo_url: string | null;
  splash_duration_ms: number;

  // features
  whatsapp_share: boolean;
  biometric_auth: boolean;
  admob_enabled: boolean;
  dark_mode: boolean;
  screenshot_block: boolean;
  root_block: boolean;
  session_persistence: boolean;
  network_detection: boolean;

  // updates
  force_update_version: number;
  force_update_message: string | null;
  update_changelog: string | null;
  soft_update_version: number;
  soft_update_message: string | null;

  // admob
  admob_app_id: string | null;
  admob_banner_unit_id: string | null;

  // stores
  play_store_url: string | null;
  app_store_url: string | null;

  // build
  version_code: number;
  version_name: string;
  sha256_fingerprint: string | null;

  // status
  android_status: AppStatus;
  ios_status: AppStatus;

  // runtime-configurable behaviour (migration 002)
  pinch_to_zoom: boolean;
  pull_to_refresh: boolean;
  whatsapp_number: string | null;
  whatsapp_message: string;
  admob_position: 'none' | 'top' | 'bottom';
  cache_soft_clear_at: string | null;
  cache_hard_clear_at: string | null;

  // escape hatch
  custom_config: Record<string, unknown>;

  created_at: string;
  updated_at: string;
}

export interface FcmToken {
  id: string;
  app_id: string;
  token: string;
  platform: 'android' | 'ios' | 'web';
  device_model: string | null;
  os_version: string | null;
  app_version: string | null;
  last_seen_at: string;
  created_at: string;
}

export interface Notification {
  id: string;
  app_id: string;
  title: string;
  body: string;
  image_url: string | null;
  deep_link_url: string | null;
  category: NotificationCategory;
  target_type: NotificationTarget;
  target_value: string | null;
  status: NotificationStatus;
  scheduled_at: string | null;
  sent_at: string | null;
  recipients_count: number;
  success_count: number;
  failure_count: number;
  error_message: string | null;
  created_by: string | null;
  created_at: string;
}

/** Shape returned by GET /api/config/:appId — Flutter parses this exactly */
export interface RemoteConfigResponse {
  app_url: string;
  splash: {
    enabled: boolean;
    color: string;
    text: string;
    duration_ms: number;
    logo_url: string;
  };
  theme: { primary: string; accent: string };
  features: {
    whatsapp_share: boolean;
    biometric_auth: boolean;
    admob: boolean;
    dark_mode: boolean;
    screenshot_block: boolean;
    root_block: boolean;
    session_persistence: boolean;
    network_detection: boolean;
    pinch_to_zoom: boolean;
    pull_to_refresh: boolean;
  };
  whatsapp: { number: string | null; message: string };
  admob: { position: 'none' | 'top' | 'bottom' };
  cache: { soft_clear_at: string | null; hard_clear_at: string | null };
  force_update: { min_version_code: number; message: string; changelog: string };
  soft_update:  { min_version_code: number; message: string; changelog: string };
  custom: Record<string, unknown>;
}
