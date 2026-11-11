import { createFileRoute } from '@tanstack/react-router'

// The deployed build's id; an open page with another id offers to reload (lib/client.ts useNewVersion).
export const Route = createFileRoute('/api/version')({
  server: {
    handlers: {
      GET: () => Response.json({ build: import.meta.env.VITE_BUILD_ID }, { headers: { 'cache-control': 'no-store' } }),
    },
  },
})
