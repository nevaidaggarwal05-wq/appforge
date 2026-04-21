# Bugs Caught and Fixed in Phase 2+3

Before handoff, a comprehensive audit of Phase 2+3 code found and fixed 9 real bugs. They're documented here so you (Claude Code) don't reintroduce them.

---

## 🔴 Bug 1: Literal `\n` in JSX placeholder

**File:** `admin_panel/app/(dashboard)/apps/[id]/config/ConfigForm.tsx:205`

**Broken:**
```tsx
placeholder='{\n  "upi_merchant_id": "abc@ybl"\n}'
```

In JSX single-quoted strings, `\n` is literal — rendered as the characters backslash + n, not a newline.

**Fixed:**
```tsx
placeholder={'{\n  "upi_merchant_id": "abc@ybl"\n}'}
```

Template literal (`{`...`}`) processes the escape sequence properly.

---

## 🔴 Bug 2: Missing explicit auth on /api/apps/[id]

**File:** `admin_panel/app/api/apps/[id]/route.ts`

The GET/PATCH/DELETE endpoints relied on middleware + RLS for auth. If middleware was bypassed or RLS policy broken, unauth'd requests could slip through.

**Fixed:** Added `requireOwnership(id)` helper that:
1. Checks user is authenticated (`auth.getUser()`)
2. Checks app exists
3. Checks user owns the app

All three endpoints now call this helper before any DB work.

---

## 🔴 Bug 3: POST /api/auth/signout redirect status

**File:** `admin_panel/app/api/auth/signout/route.ts`

**Broken:**
```ts
return NextResponse.redirect(url);  // Default 307 preserves POST method
```

When a browser receives 307 on POST, it re-POSTs to the new URL. This caused `/login` to get a POST, which returns 405.

**Fixed:**
```ts
return NextResponse.redirect(url, { status: 303 });  // 303 converts POST→GET
```

---

## 🔴 Bug 4: Fire-and-forget upsert can be dropped

**File:** `admin_panel/app/api/config/[appId]/route.ts`

**Broken:**
```ts
supabase.from('fcm_tokens').upsert(...).then(() => {}, (e) => ...);
// Response returned immediately, promise may be killed on serverless
```

On Vercel/edge runtimes, when the response is sent, background promises get killed. Token upsert silently fails.

**Fixed:**
```ts
const { error } = await supabase.from('fcm_tokens').upsert(...);
if (error) console.error(...);
// Adds ~20ms but guaranteed to run
```

---

## 🔴 Bug 5: ConfigForm mutated the `app` prop

**File:** `admin_panel/app/(dashboard)/apps/[id]/config/ConfigForm.tsx`

**Broken:**
```tsx
Object.assign(app, f);  // ← mutating a React prop!
```

React props are supposed to be immutable. Mutating them causes strict mode warnings and can break re-rendering.

**Fixed:** Proper baseline state:
```tsx
const [baseline, setBaseline] = useState(app);
// After save:
setBaseline(f);
// Dirty check:
const dirty = JSON.stringify(f) !== JSON.stringify(baseline);
```

---

## 🟡 Bug 6: package_name regex had /i flag

**File:** `admin_panel/app/api/apps/route.ts:14`

**Broken:**
```ts
regex(/^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$/i, 'Invalid package name')
//                                          ^ allows UPPERCASE
```

Android package names must be lowercase. The `/i` flag let `Com.Foo.Bar` through, which Play Store would reject later.

**Fixed:** Removed `/i`.

---

## 🟡 Bug 7: Cookies try/catch wasn't documented

**File:** `admin_panel/lib/supabase/server.ts`

The empty `catch {}` looked like a silent error swallower. It's actually required — Server Components can't set cookies.

**Fixed:** Added inline comment explaining why.

---

## 🟡 Bug 8: slugify could return empty string

**File:** `admin_panel/lib/utils.ts`

For non-ASCII input (e.g., `"नेविद"`), `slugify` returns `""`. Then slug UNIQUE constraint in Supabase fails on second non-ASCII app.

**Fixed:** Added `slugifyOrFallback()` helper. API route uses fallback: `'app-' + Date.now().toString(36)`.

---

## 🟡 Bug 9: NotificationComposer used window.location.reload()

**File:** `admin_panel/app/(dashboard)/apps/[id]/notifications/NotificationComposer.tsx`

**Broken:**
```tsx
setTimeout(() => window.location.reload(), 500);
// Full page reload — loses scroll position, re-downloads everything
```

**Fixed:**
```tsx
const router = useRouter();
router.refresh();  // Re-fetches server data, preserves client state
```

---

## Don't reintroduce these patterns

### ❌ NEVER write
```tsx
placeholder='multi\nline'                       // Bug 1
Object.assign(someProp, ...)                    // Bug 5
regex(/pattern/i)  // for case-sensitive data   // Bug 6
supabase.xxx().then(...)  // in API routes      // Bug 4
window.location.reload()  // in Next.js         // Bug 9
```

### ✅ ALWAYS write
```tsx
placeholder={'multi\nline'}
const [baseline, setBaseline] = useState(app)
regex(/pattern/)
const { error } = await supabase.xxx()
router.refresh()
```

---

## What to check when writing NEW code

1. **Auth** — every admin API route starts with `auth.getUser()` check
2. **Ownership** — every `/api/apps/:id/*` route calls `requireOwnership()` or equivalent
3. **Validation** — every write endpoint uses Zod
4. **Async** — no fire-and-forget promises in serverless routes; always await
5. **Immutability** — never mutate props, state, or any object passed as an argument
6. **Error handling** — try/catch on JSON parse, specific error messages
