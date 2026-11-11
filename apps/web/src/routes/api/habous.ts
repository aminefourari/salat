import { createFileRoute } from '@tanstack/react-router'
import { nextDate } from '../../lib/prayer'
import { habousCity, habousDays } from '../../server/habous'

const KEYS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const

// Official Habous times for `date` and the next day near (lat, lon), as epoch ms in KEYS order.
export const Route = createFileRoute('/api/habous')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const q = new URL(request.url).searchParams
        const lat = Number(q.get('lat')), lon = Number(q.get('lon')), date = q.get('date') ?? ''
        if (!q.get('lat') || !q.get('lon') || !(Math.abs(lat) <= 90) || !(Math.abs(lon) <= 180) || !/^\d{4}-\d{2}-\d{2}$/.test(date))
          return Response.json({ error: 'bad request' }, { status: 400 })
        // 404: no listed city near, the client calculates for good. 502: Habous down, the client retries later.
        if (habousCity(lat, lon) == null) return Response.json({ error: 'no habous city near' }, { status: 404 })
        const days = await habousDays(lat, lon, [date, nextDate(date)])
        if (!days) return Response.json({ error: 'habous unavailable' }, { status: 502 })
        const body = Object.fromEntries([...days].map(([d, t]) => [d, KEYS.map(k => t[k].getTime())]))
        return Response.json({ days: body }, { headers: { 'cache-control': 'public, max-age=3600' } })
      },
    },
  },
})
