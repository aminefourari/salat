import { afterEach, describe, expect, it, vi } from 'vitest'
import { sendPush } from '../src/server/push'

describe('sendPush', () => {
  afterEach(() => vi.unstubAllGlobals())
  it('reports a row with malformed keys as gone without calling the network', async () => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    const env = { VAPID_PRIVATE_KEY: '{}', VAPID_SUBJECT: 'mailto:x@example.com' } as unknown as Env
    const res = await sendPush(env, { endpoint: 'https://fcm.googleapis.com/x', p256dh: 'k', auth: 'a' }, { title: 't', body: 'b', tag: 'x' })
    expect(res).toBe('gone')
    expect(fetch).not.toHaveBeenCalled()
  })
})
