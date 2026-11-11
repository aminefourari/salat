import { createFileRoute } from '@tanstack/react-router'
import { downloadZip, isVersion, latestRelease } from '../../server/update'

// Mac app updates. GET → {version, sha256, size, notes} of the latest release; GET ?v=1.2.3 → that release's zip.
export const Route = createFileRoute('/api/update')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const v = new URL(request.url).searchParams.get('v')
        if (v !== null) return isVersion(v) ? downloadZip(v) : Response.json({ error: 'bad version' }, { status: 400 })
        const info = await latestRelease().catch(() => null)
        if (!info) return Response.json({ error: 'no release' }, { status: 502 })
        return Response.json(info, { headers: { 'cache-control': 'public, max-age=600' } })
      },
    },
  },
})
