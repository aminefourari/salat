# Plan 005: The service worker keeps exactly one deploy's assets, precaches everything offline needs, and serves the right page offline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/public/sw.js apps/web/src/routes/__root.tsx`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED (a broken service worker can break offline use for every installed user; verify carefully)
- **Depends on**: plans/001-typecheck-in-ci.md (soft)
- **Category**: bug / perf
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The PWA's service worker (`apps/web/public/sw.js`) has three problems:

1. **Unbounded growth.** The cache name `salat-v9` is only bumped by hand. Every hashed `/assets/*` file ever fetched
   is stored in that one cache and never evicted. That includes the 1.37 MB Quran JSON each time its hash changes,
   and every deploy's JS chunks. On iOS, heavy storage use risks the whole origin being evicted.
2. **Offline gaps.** The install step only precaches the `/assets/` files that appear literally in the shell HTML. The
   Quran/adhkar JSON (imported via `?url` from route chunks), lazy route chunks, and fonts (referenced from CSS) aren't
   precached. Quran and adhkar don't work offline until they've been opened online once.
3. **Wrong page offline.** Push notification taps open `/adhkar?c=27` or `/quran?s=18`. Offline,
   `caches.match(request)` misses because of the query string, and the code falls back to the `/` HTML. That renders
   the times page's HTML at the adhkar URL.

After this plan:
- Each deploy gets its own cache, named after the build id.
- Install copies unchanged hashed files from the old cache (they're immutable) and downloads only new ones.
- Install follows references from HTML → JS/CSS → JS/CSS/JSON/woff2.
- Offline navigations match the page while ignoring the query string.

## Current state

- `apps/web/public/sw.js` is plain JS, served as-is (not processed by Vite). Lines 1-43:
  ```js
  // Salat service worker: offline app shell + push notifications.
  const CACHE = 'salat-v9'
  const SHELL = ['/', '/quran', '/adhkar', '/qibla', '/settings', '/month', '/manifest.webmanifest', '/icon-192.png']

  // Precache the shell pages plus the hashed JS/CSS they reference, so the first offline launch works.
  self.addEventListener('install', e => {
    e.waitUntil((async () => {
      const c = await caches.open(CACHE)
      await c.addAll(SHELL)
      const pages = await Promise.all(['/', '/quran', '/adhkar', '/qibla', '/settings', '/month'].map(async p => (await c.match(p)).text()))
      const assets = [...new Set(pages.join('').match(/\/assets\/[\w.-]+\.(?:js|css|woff2?)/g) || [])]
      await c.addAll(assets)
      await self.skipWaiting()
    })())
  })

  self.addEventListener('activate', e => {
    e.waitUntil(
      caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()),
    )
  })

  self.addEventListener('fetch', e => {
    const { request } = e
    const url = new URL(request.url)
    if (request.method !== 'GET' || url.origin !== location.origin || url.pathname.startsWith('/api/')) return
    if (url.pathname.startsWith('/assets/')) {
      // Hashed build output never changes: cache first.
      e.respondWith(caches.match(request).then(hit => hit || fetch(request).then(res => save(request, res))))
      return
    }
    // Pages and everything else: network first so updates show up, cache when offline.
    e.respondWith(
      fetch(request)
        .then(res => save(request, res))
        .catch(() => caches.match(request).then(r => r || (request.mode === 'navigate' ? caches.match('/') : Response.error()))),
    )
  })

  function save(request, res) {
    if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(request, copy)) }
    return res
  }
  ```
  Lines 45-66 handle `push` and `notificationclick`. **Don't change them.**
- `apps/web/src/routes/__root.tsx:52` registers it:
  ```ts
  if ('serviceWorker' in navigator && !import.meta.env.DEV) navigator.serviceWorker.register('/sw.js').catch(err => console.error('sw', err))
  ```
- `import.meta.env.VITE_BUILD_ID` is the deployed commit SHA, defined for both client and Worker in
  `apps/web/vite.config.ts` (`define`). `src/lib/client.ts` `useNewVersion` already uses it.
- Chunks import each other **relatively** (e.g. `quran-C0QccwWz.js` contains `"./quran-Da8pPDqI.js"`), while HTML and
  CSS use absolute `/assets/…` paths. Route chunks are listed in each page's SSR HTML, not in the entry chunk. The
  scanner below handles both forms.
- A built `dist/client/assets/` contains `*.js`, `*.css`, `quran-*.json`, `adhkar-*.json`, and every font both as
  `.woff2` and `.woff`. Only `.woff2` is needed: every browser that supports service workers supports woff2.
- A browser only re-installs a service worker when the script's bytes **or its registration URL** change. That's why
  this plan versions the URL (`/sw.js?v=<build id>`) rather than editing a constant.

## Commands you will need

| Purpose   | Command | Expected |
|-----------|---------|----------|
| Typecheck | `npm run typecheck` (or `cd apps/web && npx tsc --noEmit`) | exit 0 |
| SW test   | `cd apps/web && npx vitest run test/sw.test.ts` | all pass |
| All tests | `npm test` | all pass |
| Build     | `npm run build` | exit 0 |

## Scope

**In scope**: `apps/web/public/sw.js`, `apps/web/src/routes/__root.tsx` (the `register` line only), and
`apps/web/test/sw.test.ts` (create).

**Out of scope**:
- The `push` / `notificationclick` handlers. `pushsubscriptionchange` is plan 011, which edits the same file, so
  land this plan first.
- Caching cross-origin audio (quran.com, hisnmuslim.com).
- `vite.config.ts`. No build plugin is needed.

## Git workflow

- Branch: `fix/sw-cache`. Commit: `fix(web): one cache per deploy, precache what offline needs, ignore query offline`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Version the registration

In `__root.tsx`, change the register call to:

```ts
navigator.serviceWorker.register(`/sw.js?v=${import.meta.env.VITE_BUILD_ID}`)
```

**Verify**: `npm run typecheck` → exit 0.

### Step 2: Rewrite the top of `sw.js` (lines 1-43)

Target shape (keep the file's style: no semicolons, 2 spaces, single quotes):

```js
// Salat service worker: offline app shell + push notifications.
// One cache per deploy: the page registers /sw.js?v=<build id>, so each deploy installs a fresh worker.
const CACHE = `salat-${new URL(location.href).searchParams.get('v') || 'dev'}`
const PAGES = ['/', '/quran', '/adhkar', '/qibla', '/settings', '/month']
const SHELL = [...PAGES, '/manifest.webmanifest', '/icon-192.png']
// Absolute (/assets/x.js in HTML and CSS) or relative (./x.js between chunks, which all live in /assets/).
const ASSET = /(?:\/assets\/|\.\/)([\w.-]+\.(?:js|css|json|woff2))/g

/** Hashed asset paths referenced by a page, script or stylesheet, as /assets/… paths. */
function assetRefs(text) { return [...new Set([...text.matchAll(ASSET)].map(m => `/assets/${m[1]}`))] }

// Precache the shell, then everything it references, transitively (route chunks, Quran/adhkar JSON, fonts).
// Hashed files never change, so one already in an older cache is copied instead of downloaded again.
self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE)
    await c.addAll(SHELL)
    const todo = assetRefs((await Promise.all(PAGES.map(async p => (await c.match(p)).text()))).join(''))
    const seen = new Set(todo)
    while (todo.length) {
      const path = todo.pop()
      const res = (await caches.match(path)) || (await fetch(path))
      if (!res.ok) continue
      await c.put(path, res.clone())
      if (/\.(?:js|css)$/.test(path)) for (const ref of assetRefs(await res.text())) if (!seen.has(ref)) { seen.add(ref); todo.push(ref) }
    }
    await self.skipWaiting()
  })())
})
```

Keep `activate` exactly as it is: it already deletes every cache but `CACHE`.

In the `fetch` handler, change only the offline fallback for pages to ignore the query string:

```js
      .catch(() => caches.match(request, { ignoreSearch: request.mode === 'navigate' })
        .then(r => r || (request.mode === 'navigate' ? caches.match('/') : Response.error()))),
```

Keep `save()` as it is.

Two notes:
- `caches.match(path)` with no cache name searches all caches, including the previous deploy's. That's the "copy
  instead of download" step.
- Don't `await` the precache of a large file twice: the loop already reuses `res`.

**Verify**: `node --check apps/web/public/sw.js` → no output, exit 0.

### Step 3: Unit-test the reference scanner and cache name

Create `apps/web/test/sw.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import { describe, expect, it } from 'vitest'

const src = readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8')
const load = (search: string) => runInNewContext(`${src}; ({ assetRefs, CACHE })`, {
  self: { addEventListener() {} }, location: { href: `https://salat.example/sw.js${search}`, origin: 'https://salat.example' }, URL,
}) as { assetRefs: (t: string) => string[]; CACHE: string }

describe('service worker', () => {
  it('names its cache after the build id', () => {
    expect(load('?v=abc123').CACHE).toBe('salat-abc123')
    expect(load('').CACHE).toBe('salat-dev')
  })
  it('finds route chunks, data and woff2 fonts, but not .woff', () => {
    const js = 'import("./quran-Da8pPDqI.js");<script src="/assets/quran-C0QccwWz.js">const u="/assets/quran-Dtdzucj6.json";url(/assets/amiri-arabic-400-normal-D0NIBXga.woff2) url(/assets/amiri-arabic-400-normal-C_1DQziU.woff)'
    expect(load('').assetRefs(js).sort()).toEqual(['/assets/amiri-arabic-400-normal-D0NIBXga.woff2', '/assets/quran-C0QccwWz.js', '/assets/quran-Da8pPDqI.js', '/assets/quran-Dtdzucj6.json'])
  })
})
```

**Verify**: `cd apps/web && npx vitest run test/sw.test.ts` → 2 passed.

### Step 4: Check the build actually references assets the way the scanner expects

Run `npm run build`, then:
- `grep -o '/assets/quran-[A-Za-z0-9_-]*\.json' apps/web/dist/client/assets/*.js | head -3` → at least one match. This
  shows the JSON URL is a literal string in a JS chunk.
- `grep -o '/assets/[A-Za-z0-9_.-]*\.woff2' apps/web/dist/client/assets/*.css | head -3` → at least one match.
- `grep -oE '"\./[A-Za-z0-9_-]+\.js"' apps/web/dist/client/assets/*.js | head -3` → relative chunk imports exist (the
  `./` branch of the scanner covers them).

If either grep finds nothing (e.g. the URLs are relative like `./quran-x.json` or built at runtime), STOP and report:
the scanner would miss them.

### Step 5 (manual, if a browser is available): smoke test

`npm run build && cd apps/web && npx vite preview`, open the app, then check in DevTools → Application:
- Cache Storage has exactly one `salat-<sha>` cache, containing a `quran-*.json`.
- With Network set to Offline, reloading `/adhkar?c=27` shows the adhkar page, not the times page.

If you have no browser, say so in your report. Don't skip it silently.

## Test plan

`test/sw.test.ts` (Step 3) covers the scanner and the cache naming. The install loop and offline fallback are covered
by the Step 4 build greps and the Step 5 manual check. There's no SW runtime in Vitest, and adding one isn't worth it.

## Done criteria

- [ ] `node --check apps/web/public/sw.js` exits 0
- [ ] `npm run typecheck` exits 0; `npm test` exits 0, including `test/sw.test.ts`
- [ ] `grep -n "salat-v9" apps/web/public/sw.js` returns nothing
- [ ] `grep -n "sw.js?v=" apps/web/src/routes/__root.tsx` shows one match
- [ ] Step 4 greps each returned a match
- [ ] Only the three in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- Step 4 greps find nothing (see Step 4).
- `VITE_BUILD_ID` isn't defined in the client build (`grep -c "VITE_BUILD_ID" apps/web/dist/client/assets/*.js` finds
  the raw name instead of a SHA).
- You feel the need to change `push`/`notificationclick` handlers.

## Maintenance notes

- Each deploy now re-installs the worker. Unchanged hashed files are copied from the old cache, so the download is
  only the changed files. If the total precache ever gets large (more data files), consider precaching data lazily.
- Users on the old `salat-v9` worker move over on their next visit after deploy: the new registration URL installs
  the new worker, and `activate` deletes `salat-v9`.
- Reviewers: check that `activate` still calls `clients.claim()` and that `skipWaiting()` is still reached when one
  asset fails (the loop `continue`s on `!res.ok`, but a thrown network error during install rejects the install, which
  is the browser's normal retry behaviour).
