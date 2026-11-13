import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { parseResubscribe, parseSubscribe } from '../../server/subscribe'

const json = (data: unknown, status = 200) => Response.json(data, { status })

export const Route = createFileRoute('/api/subscribe')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const r = parseSubscribe(await request.json().catch(() => null))
        if (typeof r === 'string') return json({ error: r }, 400)
        const now = Date.now()
        // New rows start "sent up to now" so nothing old is replayed; updates keep their last_sent_at.
        await env.DB.prepare(
          `INSERT INTO subscriptions (endpoint, p256dh, auth, lat, lon, tz, method, asr, lang, notify_start, notify_reminder,
             notify_adhkar, notify_friday, adjust, notify_prayers, last_sent_at, updated_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?13, ?14, ?15, ?16, ?12, ?12)
           ON CONFLICT(endpoint) DO UPDATE SET p256dh=?2, auth=?3, lat=?4, lon=?5, tz=?6, method=?7, asr=?8, lang=?9,
             notify_start=?10, notify_reminder=?11, notify_adhkar=?13, notify_friday=?14, adjust=?15, notify_prayers=?16, updated_at=?12`,
        ).bind(r.endpoint, r.p256dh, r.auth, r.lat, r.lon, r.tz, r.method, r.asr, r.lang, r.notify_start, r.notify_reminder, now,
          r.notify_adhkar, r.notify_friday, r.adjust, r.notify_prayers).run()
        return json({ ok: true })
      },
      // The service worker's pushsubscriptionchange: same device, new endpoint. Knowing the old endpoint is the
      // ownership proof (as for DELETE). If the new endpoint already has a row (the page synced first), drop the old.
      PATCH: async ({ request }) => {
        const r = parseResubscribe(await request.json().catch(() => null))
        if (typeof r === 'string') return json({ error: r }, 400)
        const res = await env.DB.batch([
          env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?2 AND EXISTS (SELECT 1 FROM subscriptions WHERE endpoint = ?1)').bind(r.endpoint, r.oldEndpoint),
          env.DB.prepare('UPDATE subscriptions SET endpoint = ?1, p256dh = ?2, auth = ?3, updated_at = ?4 WHERE endpoint = ?5')
            .bind(r.endpoint, r.p256dh, r.auth, Date.now(), r.oldEndpoint),
        ])
        return json({ ok: true, moved: (res[1].meta.changes ?? 0) > 0 })
      },
      DELETE: async ({ request }) => {
        const b: any = await request.json().catch(() => null)
        if (typeof b?.endpoint !== 'string') return json({ error: 'bad endpoint' }, 400)
        await env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?').bind(b.endpoint).run()
        return json({ ok: true })
      },
    },
  },
})
