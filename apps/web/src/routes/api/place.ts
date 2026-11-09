import { createFileRoute } from '@tanstack/react-router'
import { nearestCity } from '../../server/cities'

// Reverse-geocodes on our own Worker (bundled GeoNames data), so coordinates never leave the user's account.
export const Route = createFileRoute('/api/place')({
  server: {
    handlers: {
      GET: ({ request }) => {
        const q = new URL(request.url).searchParams
        const lat = Number(q.get('lat')), lon = Number(q.get('lon'))
        if (!q.get('lat') || !q.get('lon') || !(Math.abs(lat) <= 90) || !(Math.abs(lon) <= 180))
          return Response.json({ error: 'bad coordinates' }, { status: 400 })
        return Response.json({ city: nearestCity(lat, lon) }, { headers: { 'cache-control': 'public, max-age=86400' } })
      },
    },
  },
})
