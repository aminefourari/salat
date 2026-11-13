# Plan 011: When the browser rotates a push subscription, the service worker moves the server row to the new endpoint

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/public/sw.js apps/web/src/server/subscribe.ts apps/web/src/routes/api/subscribe.ts apps/web/test/subscribe.test.ts`
> Plans 002 and 005 change three of these files **on purpose**. Compare against the excerpts *as modified by those
> plans*. Treat it as a STOP condition only if something else changed them.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/002-push-endpoint-validation.md (**hard**: reuses `isPushEndpoint`/`validKeys`), plans/005-service-worker-cache.md (**hard**: same file, land 005 first)
- **Category**: bug
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

Browsers sometimes rotate or expire a Web Push subscription and fire `pushsubscriptionchange` in the service worker.
The worker doesn't handle it. The server keeps the old endpoint, which starts answering 404/410, and the cron then
**deletes** the row. The user stops getting prayer notifications until they next open the app (`__root.tsx` calls
`syncPush()` on every open). People who rely on notifications may not open the app for days. After this plan, the
worker resubscribes and tells the Worker to move the row (location, settings and offsets kept) to the new endpoint.

## Current state

- The service worker `apps/web/public/sw.js` has no `pushsubscriptionchange` listener. It can't read `localStorage`
  (where the location and settings live), so it can't call the existing `POST /api/subscribe`, which needs lat/lon/tz/settings.
- `apps/web/src/routes/api/subscribe.ts` has `POST` (upsert the full body) and `DELETE` (`{ endpoint }`). In this app
  **knowing an endpoint is the ownership proof**: endpoints are unguessable push-service URLs. `DELETE` and
  `/api/test-push` already rely on that.
  ```ts
  DELETE: async ({ request }) => {
    const b: any = await request.json().catch(() => null)
    if (typeof b?.endpoint !== 'string') return json({ error: 'bad endpoint' }, 400)
    await env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?').bind(b.endpoint).run()
    return json({ ok: true })
  },
  ```
- After plan 002, `apps/web/src/server/subscribe.ts` exports `isPushEndpoint(v)` and `validKeys(p256dh, auth)`.
- D1 table `subscriptions` has `endpoint TEXT PRIMARY KEY`, plus `p256dh`, `auth` and the settings columns
  (`apps/web/migrations/0001_init.sql`, `0003_reminders.sql`).
- The VAPID **public** key is in `apps/web/src/lib/config.ts` as `VAPID_PUBLIC_KEY`. It's public by design, so it may
  be copied into `sw.js`, which can't import TS modules.
- The client converts the key with `b64ToBytes` in `src/lib/client.ts:108-111`. Copy that logic into `sw.js`.
- Test pattern: `apps/web/test/subscribe.test.ts` (`parseSubscribe` tables).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Typecheck | `npm run typecheck` | exit 0 |
| Tests | `npm test` | all pass |
| SW syntax | `node --check apps/web/public/sw.js` | exit 0 |

## Scope

**In scope**: `apps/web/src/server/subscribe.ts`, `apps/web/src/routes/api/subscribe.ts`, `apps/web/public/sw.js`
(append one listener), `apps/web/test/subscribe.test.ts`.

**Out of scope**: migrations (no schema change), `client.ts`, and the `push`/`notificationclick` handlers.

## Git workflow

- Branch: `fix/push-subscription-change`. Commit: `fix(web): follow push subscription rotation in the service worker`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: A pure validator for the move

In `server/subscribe.ts` add:

```ts
/** Validates PATCH /api/subscribe: move a row from `oldEndpoint` to a new subscription (browser rotated it). */
export function parseResubscribe(b: any): { oldEndpoint: string; endpoint: string; p256dh: string; auth: string } | string {
  if (!b || typeof b !== 'object' || !isStr(b.oldEndpoint)) return 'bad old endpoint'
  const sub = b.subscription
  if (!isPushEndpoint(sub?.endpoint)) return 'bad endpoint'
  if (!validKeys(sub.keys?.p256dh, sub.keys?.auth)) return 'bad keys'
  return { oldEndpoint: b.oldEndpoint, endpoint: sub.endpoint, p256dh: sub.keys.p256dh, auth: sub.keys.auth }
}
```

### Step 2: The `PATCH` handler

In `routes/api/subscribe.ts` add, next to `DELETE`:

```ts
PATCH: async ({ request }) => {
  const r = parseResubscribe(await request.json().catch(() => null))
  if (typeof r === 'string') return json({ error: r }, 400)
  // Knowing the old endpoint is the ownership proof (as for DELETE). If the new endpoint already has a row
  // (the page synced first), the old one is just dropped.
  const res = await env.DB.batch([
    env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?2 AND EXISTS (SELECT 1 FROM subscriptions WHERE endpoint = ?1)').bind(r.endpoint, r.oldEndpoint),
    env.DB.prepare('UPDATE subscriptions SET endpoint = ?1, p256dh = ?2, auth = ?3, updated_at = ?4 WHERE endpoint = ?5')
      .bind(r.endpoint, r.p256dh, r.auth, Date.now(), r.oldEndpoint),
  ])
  return json({ ok: true, moved: (res[1].meta.changes ?? 0) > 0 })
},
```

Import `parseResubscribe`. If the old row is already gone (the cron deleted it after a 410), `moved` is `false`. The
next app open re-creates the row through `syncPush()`, as today.

**Verify**: `npm run typecheck` → exit 0.

### Step 3: The service-worker listener

Append to `sw.js` (after `notificationclick`):

```js
// The browser rotated or expired this device's push subscription: subscribe again and move the server row
// (location and settings live only in the page's storage, so the row is moved rather than re-created).
const VAPID_PUBLIC_KEY = '<copy the exact value from apps/web/src/lib/config.ts>'
const b64ToBytes = b64 => Uint8Array.from(atob((b64 + '='.repeat((4 - (b64.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))
self.addEventListener('pushsubscriptionchange', e => {
  e.waitUntil((async () => {
    const old = e.oldSubscription
    if (!old) return // nothing to move; the next app open re-syncs
    const sub = e.newSubscription || await self.registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(VAPID_PUBLIC_KEY) })
    await fetch('/api/subscribe', { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ oldEndpoint: old.endpoint, subscription: sub.toJSON() }) })
  })())
})
```

Copy the key value with a command, not by retyping:
`grep -o "'B[^']*'" apps/web/src/lib/config.ts`.

**Verify**: `node --check apps/web/public/sw.js` → exit 0. Then check the two keys match:
`diff <(grep -o "'B[^']*'" apps/web/src/lib/config.ts) <(grep -o "'B[^']*'" apps/web/public/sw.js)` → no output.

### Step 4: Tests

In `test/subscribe.test.ts`, import `parseResubscribe`. Using `good`'s subscription from plan 002 (valid host and
keys), add:
- valid: `parseResubscribe({ oldEndpoint: 'https://fcm.googleapis.com/old', subscription: good.subscription })` → an object whose `endpoint` is the new one
- rejects: missing `oldEndpoint`; non-push new endpoint; bad keys; a non-object body.

If plan 005's `test/sw.test.ts` exists, extend its `load()` context with `atob` and add one assertion that the
script still evaluates: `expect(load('?v=x').CACHE).toBe('salat-x')` already covers this, so just make sure it still passes.

**Verify**: `npm test` → all pass.

## Test plan

- Unit: `parseResubscribe` happy path and four rejections (Step 4).
- Manual (optional, needs a browser with DevTools): Application → Service Workers → "Push" still works, and in
  Firefox `about:debugging` you can unregister/re-subscribe. If you can't do it, say so in the report.

## Done criteria

- [ ] `npm run typecheck` exits 0; `npm test` exits 0
- [ ] `node --check apps/web/public/sw.js` exits 0; the key `diff` prints nothing
- [ ] `grep -n "PATCH" apps/web/src/routes/api/subscribe.ts` shows the handler
- [ ] Only the four in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- Plan 002 isn't merged (`isPushEndpoint` isn't exported from `server/subscribe.ts`).
- The D1 `batch` result shape has no `meta.changes` (check `worker-configuration.d.ts`'s `D1Result`). Report it rather
  than guessing.

## Maintenance notes

- If the VAPID key pair is ever rotated, `sw.js` holds a second copy of the public key. Update both
  (`src/lib/config.ts` and `public/sw.js`). The Step 3 `diff` command is the check.
- Chrome rarely fires `pushsubscriptionchange`, while Firefox does. The `syncPush()` on app open stays as the backstop.
