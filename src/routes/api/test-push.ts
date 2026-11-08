import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { t } from '../../lib/i18n'
import type { Lang } from '../../lib/prayer'
import type { Row } from '../../server/cron'
import { sendPush } from '../../server/push'

// Sends a test notification to the caller's own, already-registered subscription only.
export const Route = createFileRoute('/api/test-push')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const b: any = await request.json().catch(() => null)
        if (typeof b?.endpoint !== 'string') return Response.json({ error: 'bad endpoint' }, { status: 400 })
        const row = await env.DB.prepare('SELECT * FROM subscriptions WHERE endpoint = ?').bind(b.endpoint).first<Row>()
        if (!row) return Response.json({ error: 'not subscribed' }, { status: 404 })
        const lang = row.lang as Lang
        const res = await sendPush(env, row, { title: 'Salat', body: t(lang, 'testBody'), tag: 'test' })
        if (res === 'gone') await env.DB.prepare('DELETE FROM subscriptions WHERE endpoint = ?').bind(row.endpoint).run()
        return Response.json({ result: res }, { status: res === 'ok' ? 200 : 502 })
      },
    },
  },
})
