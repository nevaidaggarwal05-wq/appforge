# Credentials Checklist — What to Share with Claude Code

**Don't share these up front.** Only when Claude Code reaches the deployment step (after Phase 4 is complete).

For security, consider creating a separate text file on your Mac, filling in values, and then giving it to Claude Code via file upload — not pasted in plaintext chat.

---

## 1. Hetzner Cloud

```
SERVER_IP:       _______________
SSH_USER:        root
SSH_PASSWORD:    _______________
# OR SSH_KEY_PATH if you prefer key-based auth
```

Provisioning tip: Get a **CX32** (4 vCPU, 8GB RAM) — $8.29/mo. Ubuntu 24.04 LTS. Skip the extra add-ons for now.

## 2. Domain + DNS

```
ADMIN_DOMAIN:       admin.yourdomain.com   (e.g., admin.appforge.dev)
CLOUDFLARE_API_TOKEN: _______________      (needs Zone:DNS:Edit scope)
CLOUDFLARE_ZONE_ID:   _______________      (from domain dashboard)
```

You can use any DNS provider; Cloudflare just has the simplest API for Claude Code to use automatically.

## 3. Supabase

Go to https://supabase.com, create a project (free tier), then:

```
SUPABASE_URL:              https://xxxxx.supabase.co
SUPABASE_ANON_KEY:         eyJ...                (Settings → API → anon public)
SUPABASE_SERVICE_ROLE_KEY: eyJ...                (Settings → API → service_role — KEEP SECRET)
SUPABASE_DB_PASSWORD:      _______________       (the one you set at project creation)
```

## 4. Firebase (ONE project for all apps)

**Reuse `app-template-66952`** if you already have it, OR create a new one called `appforge-push`. Either way:

1. Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key" — downloads a JSON file
3. Open the JSON, copy these three values:

```
FIREBASE_PROJECT_ID:   app-template-66952
FIREBASE_CLIENT_EMAIL: firebase-adminsdk-xxx@app-template-66952.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY:  "-----BEGIN PRIVATE KEY-----\nxxx\n-----END PRIVATE KEY-----\n"
```

**Note:** `FIREBASE_PRIVATE_KEY` is a very long string with `\n` inside. In `.env.local`, wrap it in double quotes.

Also enable these services in the Firebase project:
- ✅ **Cloud Messaging (FCM)** — required, free
- ✅ **Crashlytics** — required, free
- ❌ **Remote Config** — DO NOT use (we replaced this)
- ❌ **Analytics** — DO NOT use (we replaced this)

## 5. GitHub

```
GITHUB_USERNAME:         nevaidaggarwal
GITHUB_PAT:              ghp_...           (scope: repo + workflow)
GITHUB_REPO_NAME:        appforge-admin    (to be created by Claude Code)
```

Generate PAT at: https://github.com/settings/tokens/new — pick "repo" and "workflow" scopes. Expiration: 90 days.

## 6. Anthropic API (for Claude Code to keep running)

If you're using Claude Code Desktop, this is auto-handled via your claude.ai subscription.
If you're using the terminal CLI, set `ANTHROPIC_API_KEY` in your shell profile:

```
export ANTHROPIC_API_KEY="sk-ant-..."
```

## 7. Play Store (later, when you're ready to publish)

```
GOOGLE_PLAY_EMAIL:    _______________  (Google Play Console account)
APP_NAME_PLAY_STORE:  Maximoney / etc
PACKAGE_NAME:         com.maximoney.credit
```

## 8. iOS — skip for v1

You said Apple Dev account ($99/yr) is pending. We can add iOS support later. Focus on Android first.

---

## Security reminder

- **Never commit** service_role keys, FIREBASE_PRIVATE_KEY, keystore passwords to git
- Keep `.env.local` in `.gitignore` (already is)
- Keep `android/key.properties` in `.gitignore` (already is)
- Rotate keys every 90 days or so
- If a key ever leaks, regenerate it in the relevant dashboard

---

## Delivery order (suggested)

When Claude Code asks for credentials:

1. Start with Supabase URL + anon key (safe, needed for local dev)
2. Then Firebase service account (needed for FCM)
3. Then Hetzner IP + SSH (needed for deploy)
4. Then Domain + Cloudflare token (needed for DNS)
5. Then GitHub PAT (needed for push)

That way if something goes wrong mid-deploy, you haven't shared keys you don't need yet.
