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
