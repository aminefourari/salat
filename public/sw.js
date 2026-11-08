// Salat service worker: offline app shell + push notifications.
const CACHE = 'salat-v5'
const SHELL = ['/', '/qibla', '/settings', '/manifest.webmanifest', '/icon-192.png']

// Precache the shell pages plus the hashed JS/CSS they reference, so the first offline launch works.
self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE)
    await c.addAll(SHELL)
    const pages = await Promise.all(['/', '/qibla', '/settings'].map(async p => (await c.match(p)).text()))
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
  let data = { title: 'Salat', body: '', tag: 'salat' }
  try { data = { ...data, ...e.data.json() } } catch {}
  e.waitUntil(self.registration.showNotification(data.title, {
    body: data.body, tag: data.tag, icon: '/icon-192.png', badge: '/icon-192.png', renotify: true,
  }))
})

self.addEventListener('notificationclick', e => {
  e.notification.close()
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      const open = list.find(c => new URL(c.url).origin === location.origin)
      return open ? open.focus() : self.clients.openWindow('/')
    }),
  )
})
