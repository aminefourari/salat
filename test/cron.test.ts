import { describe, expect, it } from 'vitest'
import { computeDay, type Settings } from '../src/lib/prayer'
import { runCron, type Row, type Store } from '../src/server/cron'
import { t } from '../src/lib/i18n'

const settings: Settings = { method: 'aachen', asr: 'standard', lang: 'fr' }
const isha = computeDay(53.4319, 11.1903, '2026-11-08', 'Europe/Berlin', settings).isha
const now = new Date(isha.getTime() + 10_000)

const row = (endpoint: string, lang = 'fr'): Row => ({
  endpoint, p256dh: 'k', auth: 'a', lat: 53.4319, lon: 11.1903, tz: 'Europe/Berlin',
  method: 'aachen', asr: 'standard', lang, notify_start: 1, notify_reminder: 1,
  last_sent_at: now.getTime() - 60_000, updated_at: 0,
})

function memStore(rows: Row[]): Store & { rows: Row[] } {
  return {
    rows,
    all: async () => rows,
    markSent: async (e, at) => { rows.find(r => r.endpoint === e)!.last_sent_at = at },
    remove: async e => { rows.splice(rows.findIndex(r => r.endpoint === e), 1) },
  }
}

describe('runCron', () => {
  it('sends one localized notification and marks it sent', async () => {
    const store = memStore([row('https://p/1')])
    const sent: { endpoint: string; body: string }[] = []
    await runCron(store, now, async (r, p) => { sent.push({ endpoint: r.endpoint, body: p.body }); return 'ok' })
    expect(sent).toEqual([{ endpoint: 'https://p/1', body: "C'est l'heure de Isha — 18:21" }])
    expect(store.rows[0].last_sent_at).toBe(now.getTime())
    await runCron(store, new Date(now.getTime() + 30_000), async () => { throw new Error('should not send') })
  })

  it('deletes gone subscriptions', async () => {
    const store = memStore([row('https://p/1')])
    await runCron(store, now, async () => 'gone')
    expect(store.rows).toEqual([])
  })

  it('keeps going when one row throws', async () => {
    const store = memStore([row('https://p/bad'), row('https://p/2', 'ar')])
    const sent: string[] = []
    await runCron(store, now, async r => { if (r.endpoint.endsWith('bad')) throw new Error('boom'); sent.push(r.endpoint); return 'ok' })
    expect(sent).toEqual(['https://p/2'])
  })

  it('has reminder copy in all languages', () => {
    expect(t('en', 'notif.reminder', { prayer: t('en', 'isha'), time: '18:21' })).toBe('Isha in 10 minutes — 18:21')
    expect(t('ar', 'isha')).toBe('العشاء')
  })
})
