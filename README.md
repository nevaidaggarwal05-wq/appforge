# AppForge v5 — Handoff to Claude Code Desktop

**Purpose:** Transfer all context from the Claude.ai chat session to Claude Code running on your Mac, so it can finish Phase 4 (Flutter shell), deploy everything to Hetzner, and hand you a production-testable APK.

---

## What's in this ZIP

```
appforge-handoff/
├── README.md                         ← You are reading this
├── HANDOFF_PROMPT.md                 ← Paste into Claude Code session start
├── admin_panel/                      ← COMPLETE (Phase 2+3 done, all bugs fixed)
│   ├── app/                          ← 15 route files
│   ├── components/                   ← 4 UI primitives
│   ├── lib/                          ← Supabase + FCM + utils
│   ├── supabase/migrations/
│   ├── package.json
│   ├── middleware.ts
│   └── ... (45 files total)
├── docs/
│   ├── ARCHITECTURE.md               ← System design
│   ├── PHASE_STATUS.md               ← What's done, what's pending
│   ├── API_CONTRACT.md               ← /api/config/:appId JSON schema (CRITICAL)
│   ├── BUGS_FIXED.md                 ← 9 bugs caught and fixed
│   └── PHASE_4_SPEC.md               ← Exact spec for Flutter shell (not yet written)
└── credentials_checklist.md          ← What you'll need to give Claude Code
```

---

## How to Hand Off to Claude Code Desktop

### Step 1: Install Claude Code Desktop (if you haven't)

- Go to: https://claude.com/download (get the desktop app)
- Or if you prefer terminal: `npm install -g @anthropic-ai/claude-code`, then `claude-code` in any directory

### Step 2: Unzip this package

```bash
cd ~/Desktop
unzip appforge-handoff.zip
cd appforge-handoff
```

### Step 3: Open the folder in Claude Code

- Claude Code Desktop: File → Open Folder → select `appforge-handoff/`
- Or terminal: `cd appforge-handoff && claude-code`

### Step 4: Start the session with the handoff prompt

Copy the contents of `HANDOFF_PROMPT.md` and paste it as your first message to Claude Code. This gives it all the context it needs.

Claude Code will:
1. Read the entire codebase (all 45 files)
2. Read all docs (architecture, API contract, phase status, bugs fixed)
3. Tell you what it understands before asking for credentials
4. Wait for your approval before starting each major step

---

## What Claude Code Will Do

### Session 1: Review + finish Phase 4 (2-3 hours)
- Read all 45 existing files in admin_panel/
- Read all 5 docs
- Build the Flutter shell (~35 files): services, screens, widgets, Android/iOS config
- Run `flutter analyze` locally to catch Dart errors
- Ask you to approve before proceeding

### Session 2: Deployment (wait for credentials)
You share these when you're ready:
- Hetzner server IP + root password
- Domain name (e.g., `admin.yourdomain.com`)
- Cloudflare API token (DNS)
- Supabase project URL + anon key + service role key
- Firebase service account JSON (ONE shared project)
- GitHub Personal Access Token

Claude Code will:
- SSH into Hetzner, install Coolify
- Deploy admin panel via Coolify
- Run Supabase migration
- Configure domain + SSL
- Test `/api/config/test` returns a valid response

### Session 3: First app build + test (30 min)
- You create "Maximoney" in the admin panel
- Download Flutter ZIP
- Claude Code builds the signed APK locally
- You install on your phone
- Full end-to-end test: config changes, notifications, biometric, etc.

### Total calendar time: 3-4 days
Because you're not testing intermediate APKs — only the final one after the backend is live — this is actually faster than testing each phase in isolation. Good call.

---

## Testing Strategy You've Chosen

You said: "I will not test the intermediate apk and will only test the production ready apk when backend is hosted so that I can test everything end to end."

This is correct because:
- The Flutter app is useless without the backend running (it fetches config on startup)
- Intermediate APKs would just use fallback config, not tell you anything useful
- End-to-end test with deployed backend = real test

So Claude Code will:
1. Build everything complete (backend + flutter shell + android config)
2. Deploy backend first
3. THEN build and test the APK

---

## If Anything Goes Wrong

If Claude Code gets stuck:

- Check its output for errors
- Check `/home/claude/appforge/docs/BUGS_FIXED.md` — similar bugs may appear
- If desperate, come back to Claude.ai with a snapshot of the problem and I can help debug

---

## Key Constraints Claude Code Must Respect

These are encoded in `HANDOFF_PROMPT.md` but worth stating here:

1. **DO NOT rebuild what's already done.** The admin_panel/ folder is complete and bug-fixed. Only Phase 4 (Flutter) remains.
2. **DO NOT change the API contract.** `GET /api/config/:appId` response shape is locked. Flutter's `RemoteConfig` model must match it.
3. **DO NOT add Firebase Remote Config or Firebase Analytics back.** We explicitly removed these.
4. **DO NOT delete the splash screen.** Nevaid wants it kept.
5. **DO NOT change package name after Play Store publish.**
6. **versionCode MUST increase by 1** on every Play Store upload.
7. **Use ONE shared Firebase project** for FCM delivery. Apps isolated via topic `app_<uuid>`.

---

Now paste `HANDOFF_PROMPT.md` into Claude Code and let it take over. 🚀
