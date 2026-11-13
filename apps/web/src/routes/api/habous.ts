import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { d1HabousStore, habousCity, habousDays, monthInWindow } from '../../server/habous'

const KEYS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const

// Official Habous times for every day of `month` (YYYY-MM) near (lat, lon), as epoch ms in KEYS order.
// Clients fetch a month once and keep it.
export const Route = createFileRoute('/api/habous')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const q = new URL(request.url).searchParams
        const lat = Number(q.get('lat')), lon = Number(q.get('lon')), month = q.get('month') ?? ''
        if (!q.get('lat') || !q.get('lon') || !(Math.abs(lat) <= 90) || !(Math.abs(lon) <= 180) || !/^\d{4}-(0[1-9]|1[0-2])$/.test(month))
          return Response.json({ error: 'bad request' }, { status: 400 })
        // Clients only ask for today's or tomorrow's month; anything else would make us hammer habous.gov.ma.
        if (!monthInWindow(month, new Date())) return Response.json({ error: 'month out of range' }, { status: 400 })
        // 404: no listed city near, the client calculates for good. 502: Habous down, the client retries later.
        if (habousCity(lat, lon) == null) return Response.json({ error: 'no habous city near' }, { status: 404 })
        const days = await habousDays(d1HabousStore(env.DB), lat, lon, Array.from({ length: 31 }, (_, i) => `${month}-${String(i + 1).padStart(2, '0')}`))
        if (!days) return Response.json({ error: 'habous unavailable' }, { status: 502 })
        const body = Object.fromEntries([...days].map(([d, t]) => [d, KEYS.map(k => t[k].getTime())]))
        return Response.json({ days: body }, { headers: { 'cache-control': 'public, max-age=86400' } })
      },
    },
  },
})
