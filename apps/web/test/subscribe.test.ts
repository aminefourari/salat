import { describe, expect, it } from 'vitest'
import { parseResubscribe, parseSubscribe } from '../src/server/subscribe'

const b64url = (n: number, first = 1) => Buffer.from(Uint8Array.from({ length: n }, (_, i) => (i === 0 ? first : i))).toString('base64url')
const P256DH = b64url(65, 4), AUTH = b64url(16)
const good = {
  subscription: { endpoint: 'https://fcm.googleapis.com/fcm/send/abc', keys: { p256dh: P256DH, auth: AUTH } },
  lat: 53.43, lon: 11.19, tz: 'Europe/Berlin',
  settings: { method: 'auto', asr: 'standard', lang: 'ar' }, notifyStart: true, notifyReminder: false,
}

describe('parseSubscribe', () => {
  it('accepts a valid body', () => {
    const r = parseSubscribe(good)
    expect(typeof r).toBe('object')
    expect(r).toMatchObject({ endpoint: 'https://fcm.googleapis.com/fcm/send/abc', method: 'auto', lang: 'ar', notify_start: 1, notify_reminder: 0, adjust: '{}', notify_adhkar: 0 })
  })
  it('stores the per-prayer mask, all prayers by default', () => {
    expect(parseSubscribe(good)).toMatchObject({ notify_prayers: 31 })
    expect(parseSubscribe({ ...good, notifyPrayers: 6 })).toMatchObject({ notify_prayers: 6 })
  })
  it('stores offsets and the new switches', () => {
    const r = parseSubscribe({ ...good, settings: { ...good.settings, adjust: { maghrib: -5 } }, notifyAdhkar: true, notifyFriday: true })
    expect(r).toMatchObject({ adjust: '{"maghrib":-5}', notify_adhkar: 1, notify_friday: 1 })
  })
  it.each([
    ['http endpoint', { ...good, subscription: { ...good.subscription, endpoint: 'http://x' } }],
    ['lat out of range', { ...good, lat: 91 }],
    ['bad tz', { ...good, tz: 'Mars/Olympus' }],
    ['bad method', { ...good, settings: { ...good.settings, method: 'nope' } }],
    ['bad lang', { ...good, settings: { ...good.settings, lang: 'xx' } }],
    ['missing keys', { ...good, subscription: { endpoint: 'https://x' } }],
    ['not an object', 'hello'],
    ['adjust out of range', { ...good, settings: { ...good.settings, adjust: { fajr: 31 } } }],
    ['adjust not an integer', { ...good, settings: { ...good.settings, adjust: { fajr: 1.5 } } }],
    ['adjust unknown prayer', { ...good, settings: { ...good.settings, adjust: { sunrise: 2 } } }],
    ['prayers out of range', { ...good, notifyPrayers: 32 }],
    ['prayers not an integer', { ...good, notifyPrayers: 1.5 }],
    ['non-push host', { ...good, subscription: { ...good.subscription, endpoint: 'https://example.com/x' } }],
    ['lookalike host', { ...good, subscription: { ...good.subscription, endpoint: 'https://fcm.googleapis.com.evil.net/x' } }],
    ['explicit port', { ...good, subscription: { ...good.subscription, endpoint: 'https://fcm.googleapis.com:8443/x' } }],
    ['short p256dh', { ...good, subscription: { ...good.subscription, keys: { p256dh: b64url(33, 2), auth: AUTH } } }],
    ['non-base64 auth', { ...good, subscription: { ...good.subscription, keys: { p256dh: P256DH, auth: 'not base64!' } } }],
  ])('rejects %s', (_, body) => {
    expect(typeof parseSubscribe(body)).toBe('string')
  })
  it.each([
    'https://fcm.googleapis.com/fcm/send/x',
    'https://updates.push.services.mozilla.com/wpush/v2/x',
    'https://web.push.apple.com/QH',
    'https://wns2-par02p.notify.windows.com/w/?token=x',
  ])('accepts the push service %s', endpoint => {
    expect(typeof parseSubscribe({ ...good, subscription: { ...good.subscription, endpoint } })).toBe('object')
  })
})

describe('parseResubscribe', () => {
  it('moves a row to a rotated subscription', () => {
    expect(parseResubscribe({ oldEndpoint: 'https://fcm.googleapis.com/old', subscription: good.subscription }))
      .toEqual({ oldEndpoint: 'https://fcm.googleapis.com/old', endpoint: good.subscription.endpoint, p256dh: P256DH, auth: AUTH })
  })
  it.each([
    ['missing old endpoint', { subscription: good.subscription }],
    ['non-push new endpoint', { oldEndpoint: 'x', subscription: { ...good.subscription, endpoint: 'https://example.com/x' } }],
    ['bad keys', { oldEndpoint: 'x', subscription: { ...good.subscription, keys: { p256dh: 'p', auth: 'a' } } }],
    ['not an object', null],
  ])('rejects %s', (_, body) => {
    expect(typeof parseResubscribe(body)).toBe('string')
  })
})
