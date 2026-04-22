# admin_panel/CLAUDE.md

Next.js 14 admin dashboard + the `/api/config/:appId` endpoint that
every Flutter shell polls.

## Deployment

Coolify on Hetzner deploys this directory on every push to `main`.
Secrets (Supabase service-role key, Firebase service-account JSON)
live in Coolify env vars, not in this repo.

## Supabase

- Migrations: `supabase/migrations/NNN_description.sql`, numbered
  sequentially. 003 is the current head.
- Every new column must use `add column if not exists` + a default,
  so migrations are re-runnable and safe to land before the code
  that reads the column.
- Claude does **not** hold the service-role key locally. When you
  author a migration, surface the SQL to the human so they can run
  it in the Supabase dashboard SQL Editor.

## /api/config/:appId

- Shape defined in `docs/API_CONTRACT.md` (repo root).
- Every field must have a server-side `??` fallback so the API keeps
  working if the migration hasn't been applied yet.
- Any change here requires a matching change in
  `flutter_shell/lib/core/models/remote_config_model.dart`.

## Conventions

- Use the existing component primitives in `components/ui/` — do not
  pull in a new component library.
- Dashboard pages use server components by default; drop to client
  only for interactivity.
- Tailwind + shadcn conventions already in use — match them.
