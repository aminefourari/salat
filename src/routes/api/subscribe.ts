import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { parseSubscribe } from '../../server/subscribe'

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
          `INSERT INTO subscriptions (endpoint, p256dh, auth, lat, lon, tz, method, asr, lang, notify_start, notify_reminder, last_sent_at, updated_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?12)
           ON CONFLICT(endpoint) DO UPDATE SET p256dh=?2, auth=?3, lat=?4, lon=?5, tz=?6, method=?7, asr=?8, lang=?9,
             notify_start=?10, notify_reminder=?11, updated_at=?12`,
        ).bind(r.endpoint, r.p256dh, r.auth, r.lat, r.lon, r.tz, r.method, r.asr, r.lang, r.notify_start, r.notify_reminder, now).run()
        return json({ ok: true })
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
