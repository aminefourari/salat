import { describe, expect, it } from 'vitest'
import { parseSubscribe } from '../src/server/subscribe'

const good = {
  subscription: { endpoint: 'https://fcm.googleapis.com/x', keys: { p256dh: 'p', auth: 'a' } },
  lat: 53.43, lon: 11.19, tz: 'Europe/Berlin',
  settings: { method: 'auto', asr: 'standard', lang: 'ar' }, notifyStart: true, notifyReminder: false,
}

describe('parseSubscribe', () => {
  it('accepts a valid body', () => {
    const r = parseSubscribe(good)
    expect(typeof r).toBe('object')
    expect(r).toMatchObject({ endpoint: 'https://fcm.googleapis.com/x', method: 'auto', lang: 'ar', notify_start: 1, notify_reminder: 0 })
  })
  it.each([
    ['http endpoint', { ...good, subscription: { ...good.subscription, endpoint: 'http://x' } }],
    ['lat out of range', { ...good, lat: 91 }],
    ['bad tz', { ...good, tz: 'Mars/Olympus' }],
    ['bad method', { ...good, settings: { ...good.settings, method: 'nope' } }],
    ['bad lang', { ...good, settings: { ...good.settings, lang: 'de' } }],
    ['missing keys', { ...good, subscription: { endpoint: 'https://x' } }],
    ['not an object', 'hello'],
  ])('rejects %s', (_, body) => {
    expect(typeof parseSubscribe(body)).toBe('string')
  })
})
