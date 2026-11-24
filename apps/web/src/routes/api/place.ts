import { createFileRoute } from '@tanstack/react-router'
import { nearestCity, searchCities } from '../../server/cities'

// Reverse-geocodes (`?lat=&lon=`) and searches towns (`?q=`) on our own Worker (bundled GeoNames data), so nothing leaves it.
export const Route = createFileRoute('/api/place')({
  server: {
    handlers: {
      GET: ({ request }) => {
        const q = new URL(request.url).searchParams
        const cache = { 'cache-control': 'public, max-age=86400' }
        if (q.has('q')) return Response.json({ cities: searchCities(q.get('q')!.slice(0, 60)) }, { headers: cache })
        const lat = Number(q.get('lat')), lon = Number(q.get('lon'))
        if (!q.get('lat') || !q.get('lon') || !(Math.abs(lat) <= 90) || !(Math.abs(lon) <= 180))
          return Response.json({ error: 'bad coordinates' }, { status: 400 })
        return Response.json({ city: nearestCity(lat, lon) }, { headers: cache })
      },
    },
  },
})
