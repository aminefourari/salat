// Salat service worker: offline app shell + push notifications.
// One cache per deploy: the page registers /sw.js?v=<build id>, so each deploy installs a fresh worker.
const CACHE = `salat-${new URL(location.href).searchParams.get('v') || 'dev'}`
const PAGES = ['/', '/quran', '/adhkar', '/qibla', '/settings', '/month']
const SHELL = [...PAGES, '/manifest.webmanifest', '/icon-192.png']
// Absolute (/assets/x.js in HTML and CSS) or relative (./x.js between chunks, which all live in /assets/).
const ASSET = /(?:\/assets\/|\.\/)([\w.-]+\.(?:json|js|css|woff2))(?![\w.-])/g

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
      // A notification opens /adhkar?c=27 or /quran?s=18: offline, serve that page whatever its query.
      .catch(() => caches.match(request, { ignoreSearch: request.mode === 'navigate' })
        .then(r => r || (request.mode === 'navigate' ? caches.match('/') : Response.error()))),
  )
})

function save(request, res) {
  if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(request, copy)) }
  return res
}

self.addEventListener('push', e => {
  let data = { title: 'Salat', body: '', tag: 'salat', url: '/' }
  try { data = { ...data, ...e.data.json() } } catch {}
  e.waitUntil(self.registration.showNotification(data.title, {
    body: data.body, tag: data.tag, icon: '/icon-192.png', badge: '/icon-192.png', renotify: true, data: { url: data.url },
  }))
})

self.addEventListener('notificationclick', e => {
  e.notification.close()
  // Same-origin path only (the payload comes from our Worker, but never navigate off-site).
  const url = e.notification.data?.url ? new URL(e.notification.data.url, location.origin) : null
  const target = url && url.origin === location.origin ? url.pathname + url.search : null
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      const open = list.find(c => new URL(c.url).origin === location.origin)
      if (!open) return self.clients.openWindow(target ?? '/')
      // navigate() throws for a window this worker doesn't control yet: open the page instead.
      return open.focus().then(c => target && c.navigate(target)).catch(() => self.clients.openWindow(target ?? '/'))
    }),
  )
})

// The browser rotated or expired this device's push subscription: subscribe again and move the server row
// (location and settings live only in the page's storage, so the row is moved rather than re-created).
// Same public key as src/lib/config.ts: update both if the VAPID pair ever changes.
const VAPID_PUBLIC_KEY = 'BIjHbRVBp2kI6TBpgMgz2WAM-6Pkn_x-sgPQFyHB4UeS4qTPv3HoC7iJ9blzaRehHKq9CiJPdMKoqUwjg0dN2y8'
const b64ToBytes = b64 => Uint8Array.from(atob((b64 + '='.repeat((4 - (b64.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))
self.addEventListener('pushsubscriptionchange', e => {
  e.waitUntil((async () => {
    const old = e.oldSubscription
    if (!old) return // nothing to move: the next app open re-syncs
    const sub = e.newSubscription || await self.registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(VAPID_PUBLIC_KEY) })
    await fetch('/api/subscribe', { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ oldEndpoint: old.endpoint, subscription: sub.toJSON() }) })
  })())
})
