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
