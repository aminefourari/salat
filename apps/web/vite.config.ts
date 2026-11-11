import { execSync } from 'node:child_process'
import { defineConfig } from 'vite'

import { tanstackStart } from '@tanstack/react-start/plugin/vite'

import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { cloudflare } from '@cloudflare/vite-plugin'

// The deployed commit, shared by the browser bundle and the Worker (the config is evaluated once per
// environment, so it can't be a timestamp): the page compares its own with /api/version to notice that a
// newer version was deployed (lib/client.ts useNewVersion).
const BUILD_ID = (() => {
  try { return process.env.GITHUB_SHA || execSync('git rev-parse HEAD').toString().trim() } catch { return 'dev' }
})()

const config = defineConfig({
  define: { 'import.meta.env.VITE_BUILD_ID': JSON.stringify(BUILD_ID) },
  resolve: { tsconfigPaths: true },
  plugins: [
    cloudflare({ viteEnvironment: { name: 'ssr' } }),
    tailwindcss(),
    tanstackStart(),
    viteReact(),
  ],
})

export default config
