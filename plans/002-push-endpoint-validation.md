# Plan 002: The Worker only stores and pushes to real Web Push services, with well-formed keys

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src/server/subscribe.ts apps/web/src/server/push.ts apps/web/test/subscribe.test.ts`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-typecheck-in-ci.md (soft: it provides `npm run typecheck`; without it use `cd apps/web && npx tsc --noEmit`)
- **Category**: security
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

`POST /api/subscribe` (no auth, by design: a device is identified by its push subscription) accepts **any** `https://`
URL as the push endpoint. The per-minute cron and `POST /api/test-push` then POST to it. So anyone can make the Worker
send requests to arbitrary hosts, and `test-push` reveals the target's status class (`ok`/`gone`/`error`).
The keys are only checked as non-empty strings. A row with malformed keys makes `buildPushHTTPRequest` throw on
every due event. The cron catches the throw and logs it, but never deletes the row.

After this plan, only the browser push services' hosts are accepted, the keys must have the sizes the Web Push spec
requires, and a stored row with bad keys is treated as gone (deleted).

## Current state

- `apps/web/src/server/subscribe.ts` validates the subscribe body. Lines 5-6 and 13-17:
  ```ts
  const isNum = (v: unknown, min: number, max: number): v is number => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max
  const isStr = (v: unknown, max = 2048): v is string => typeof v === 'string' && v.length > 0 && v.length <= max
  ...
  export function parseSubscribe(b: any): Omit<Row, 'last_sent_at' | 'updated_at'> | string {
    if (!b || typeof b !== 'object') return 'body must be an object'
    const sub = b.subscription
    if (!isStr(sub?.endpoint) || !sub.endpoint.startsWith('https://')) return 'bad endpoint'
    if (!isStr(sub.keys?.p256dh, 256) || !isStr(sub.keys?.auth, 256)) return 'bad keys'
  ```
- `apps/web/src/server/push.ts`, the whole file:
  ```ts
  import { buildPushHTTPRequest } from '@pushforge/builder'
  import type { Payload, Row, SendResult } from './cron'

  export async function sendPush(env: Env, row: Pick<Row, 'endpoint' | 'p256dh' | 'auth'>, payload: Payload): Promise<SendResult> {
    const { endpoint, headers, body } = await buildPushHTTPRequest({
      privateJWK: env.VAPID_PRIVATE_KEY,
      subscription: { endpoint: row.endpoint, keys: { p256dh: row.p256dh, auth: row.auth } },
      // A prayer notification is useless once stale: expire after 10 min.
      message: { payload, adminContact: env.VAPID_SUBJECT, options: { ttl: 600, urgency: 'high', topic: payload.tag } },
    })
    const res = await fetch(endpoint, { method: 'POST', headers, body })
    if (res.status === 404 || res.status === 410) return 'gone'
    if (!res.ok) { console.error('push failed', res.status, await res.text().catch(() => '')); return 'error' }
    return 'ok'
  }
  ```
- Callers of `sendPush`: `src/server.ts` (cron) and `src/routes/api/test-push.ts`. Both already delete the row when
  the result is `'gone'`. In `src/server/cron.ts:79`: `if (res === 'gone') { await store.remove(row.endpoint); ok = false; break }`.
- Existing test pattern: `apps/web/test/subscribe.test.ts` (an `it.each` table of rejected bodies). Its `good` fixture
  uses `keys: { p256dh: 'p', auth: 'a' }`. After this plan those keys are invalid, so the fixture must change.
- Code style: terse one-line arrow helpers, no semicolons, single quotes, 2-space indent. Match `subscribe.ts`.

## Facts the executor needs (Web Push spec)

- `keys.p256dh` is the client's P-256 public key, uncompressed: **65 bytes**, first byte `0x04`, base64url-encoded
  (87 chars without padding).
- `keys.auth` is the auth secret: **16 bytes** base64url (22 chars without padding).
- Browsers' push service hosts:
  - Chrome, Edge-Chromium, Opera, Brave and Samsung use `fcm.googleapis.com`.
  - Firefox uses `updates.push.services.mozilla.com`.
  - Safari (macOS and iOS web apps) uses `web.push.apple.com`. Accept any host ending in `.push.apple.com`.
  - Legacy Edge/Windows uses hosts ending in `.notify.windows.com`.

## Commands you will need

| Purpose   | Command                                           | Expected on success |
|-----------|---------------------------------------------------|---------------------|
| Typecheck | `npm run typecheck` (or `cd apps/web && npx tsc --noEmit`) | exit 0 |
| One test  | `cd apps/web && npx vitest run test/subscribe.test.ts test/push.test.ts` | all pass |
| All tests | `npm test`                                        | all pass            |

## Scope

**In scope**:
- `apps/web/src/server/subscribe.ts`
- `apps/web/src/server/push.ts`
- `apps/web/test/subscribe.test.ts`
- `apps/web/test/push.test.ts` (create)

**Out of scope**:
- `src/routes/api/subscribe.ts`, `test-push.ts` and `cron.ts`. Their `'gone'` handling already does the right thing.
- Cleaning up rows already in production D1. A note for the owner goes in the PR description; you don't touch D1.
- Rate limiting. That's a Cloudflare WAF rule, not code.
- `apps/web/test/cron.test.ts` and `habous.test.ts`. They use fake keys like `'k'`, but they never call `sendPush`,
  so they keep working.

## Git workflow

- Branch: `fix/push-endpoint-validation`
- Commit: `fix(web): accept only Web Push service endpoints and well-formed keys`
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Add the validators to `subscribe.ts`

Below `isStr`, add and **export**:

```ts
const PUSH_HOSTS = ['fcm.googleapis.com', 'updates.push.services.mozilla.com']
const PUSH_SUFFIXES = ['.push.apple.com', '.notify.windows.com']
/** A browser push service URL (anything else would let callers make the Worker POST to arbitrary hosts). */
export const isPushEndpoint = (v: unknown): v is string => {
  if (!isStr(v)) return false
  try {
    const u = new URL(v)
    return u.protocol === 'https:' && !u.port && (PUSH_HOSTS.includes(u.hostname) || PUSH_SUFFIXES.some(s => u.hostname.endsWith(s)))
  } catch { return false }
}
/** Byte length of a base64url string, or -1 when it isn't one. */
const b64urlBytes = (s: string) => {
  if (!/^[A-Za-z0-9_-]+={0,2}$/.test(s)) return -1
  try { return atob(s.replace(/-/g, '+').replace(/_/g, '/').replace(/=+$/, '').padEnd(Math.ceil(s.replace(/=+$/, '').length / 4) * 4, '=')).length } catch { return -1 }
}
/** RFC 8291 keys: p256dh is an uncompressed P-256 point (65 bytes), auth a 16-byte secret. */
export const validKeys = (p256dh: unknown, auth: unknown) =>
  isStr(p256dh, 256) && isStr(auth, 256) && b64urlBytes(p256dh) === 65 && b64urlBytes(auth) === 16
```

Then change the two checks in `parseSubscribe` to:

```ts
  if (!isPushEndpoint(sub?.endpoint)) return 'bad endpoint'
  if (!validKeys(sub.keys?.p256dh, sub.keys?.auth)) return 'bad keys'
```

(You may write `b64urlBytes` more readably. The requirement is: it returns the decoded byte length for valid base64url
with or without padding, and -1 otherwise.)

**Verify**: `npm run typecheck` → exit 0.

### Step 2: Treat stored rows with invalid keys as gone in `push.ts`

At the top of `sendPush`, before `buildPushHTTPRequest`:

```ts
  // A row with malformed keys can never be delivered: report it gone so the caller deletes it.
  if (!validKeys(row.p256dh, row.auth)) return 'gone'
```

and `import { validKeys } from './subscribe'`. Do **not** wrap `buildPushHTTPRequest` in a catch that returns
`'gone'`. If `VAPID_PRIVATE_KEY` is misconfigured it would throw for every row, and that would delete every
subscription. Leave other throws to the cron's per-row `catch`.

Don't add the endpoint-host check here. Rows stored before this change keep being sent to until they 404/410.
Mention them in the PR description (see Maintenance notes).

**Verify**: `npm run typecheck` → exit 0.

### Step 3: Update and extend `subscribe.test.ts`

At the top of the file, build valid keys and use them in `good`:

```ts
const b64url = (n: number, first = 1) => Buffer.from(Uint8Array.from({ length: n }, (_, i) => (i === 0 ? first : i))).toString('base64url')
const P256DH = b64url(65, 4), AUTH = b64url(16)
```

Set `good.subscription.keys` to `{ p256dh: P256DH, auth: AUTH }`. Update the endpoint in `good` to
`https://fcm.googleapis.com/fcm/send/abc` and the expectation on line 14 to match.

Add these rows to the `it.each` table:
- `['non-push host', { ...good, subscription: { ...good.subscription, endpoint: 'https://example.com/x' } }]`
- `['lookalike host', { ...good, subscription: { ...good.subscription, endpoint: 'https://fcm.googleapis.com.evil.net/x' } }]`
- `['explicit port', { ...good, subscription: { ...good.subscription, endpoint: 'https://fcm.googleapis.com:8443/x' } }]`
- `['short p256dh', { ...good, subscription: { ...good.subscription, keys: { p256dh: b64url(33, 2), auth: AUTH } } }]`
- `['non-base64 auth', { ...good, subscription: { ...good.subscription, keys: { p256dh: P256DH, auth: 'not base64!' } } }]`

Add one positive `it.each` over the endpoints `https://fcm.googleapis.com/fcm/send/x`,
`https://updates.push.services.mozilla.com/wpush/v2/x`, `https://web.push.apple.com/QH`, and
`https://wns2-par02p.notify.windows.com/w/?token=x`. Each one with `good`'s keys must parse to an object.

**Verify**: `cd apps/web && npx vitest run test/subscribe.test.ts` → all pass (old cases plus about 9 new ones).

### Step 4: Add `test/push.test.ts`

```ts
import { afterEach, describe, expect, it, vi } from 'vitest'
import { sendPush } from '../src/server/push'

describe('sendPush', () => {
  afterEach(() => vi.unstubAllGlobals())
  it('reports a row with malformed keys as gone without calling the network', async () => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    const env = { VAPID_PRIVATE_KEY: '{}', VAPID_SUBJECT: 'mailto:x@example.com' } as unknown as Env
    const res = await sendPush(env, { endpoint: 'https://fcm.googleapis.com/x', p256dh: 'k', auth: 'a' }, { title: 't', body: 'b', tag: 'x' })
    expect(res).toBe('gone')
    expect(fetch).not.toHaveBeenCalled()
  })
})
```

**Verify**: `cd apps/web && npx vitest run test/push.test.ts` → 1 passed.

## Test plan

Covered by Steps 3-4: the host allowlist (good, bad, lookalike, port), key sizes, the base64url check, and malformed
stored keys giving `'gone'` with no fetch. Pattern: the existing `it.each` table in `test/subscribe.test.ts`.

## Done criteria

- [ ] `npm run typecheck` exits 0
- [ ] `npm test` exits 0, and `test/push.test.ts` exists and passes
- [ ] `grep -n "startsWith('https://')" apps/web/src/server/subscribe.ts` returns nothing
- [ ] `git status --porcelain` shows only the four in-scope files (plus `plans/README.md`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `atob` is not defined in the Vitest environment (Node). It should be on Node ≥ 16, so report it if it's missing.
- A real browser's subscription would be rejected. If you have evidence of a push host not in the list (e.g. from
  `@pushforge/builder` docs or tests), stop and report the host rather than guessing a wider pattern.
- Making the change seems to need edits to `cron.ts` or the API routes.

## Maintenance notes

- In the PR description, ask the owner to check the existing rows once:
  `npx wrangler d1 execute salat --remote --command "SELECT substr(endpoint,1,40) FROM subscriptions"`. Any row whose
  host isn't a push service can be deleted by hand.
- If a new browser push service appears (rare), add its host to `PUSH_HOSTS`/`PUSH_SUFFIXES`. Its users would get
  `400 bad endpoint` from `/api/subscribe` until then, and `enablePush()` in `src/lib/client.ts` throws `subscribe failed: 400`.
- Reviewers should check the suffix match always includes the leading dot (`.push.apple.com`), so
  `evilpush.apple.com.attacker` can't pass.
