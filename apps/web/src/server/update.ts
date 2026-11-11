// Mac app updates: the latest GitHub Release of this repo, served through our Worker so the app never calls
// a third party (CLAUDE.md). The zip is streamed from GitHub; the app checks its SHA-256 before installing.
const REPO = 'aminefourari/salat'
const UA = 'salat-worker'

export type UpdateInfo = { version: string; sha256: string; size: number; notes: string }

const SEMVER = /^\d+\.\d+\.\d+$/
export const isVersion = (v: unknown): v is string => typeof v === 'string' && SEMVER.test(v)
export const zipUrl = (v: string) => `https://github.com/${REPO}/releases/download/v${v}/Salat-v${v}.zip`

/** The update the app should offer, from GitHub's `releases/latest` JSON; null when it has no usable zip. */
export function parseRelease(r: any): UpdateInfo | null {
  const version = typeof r?.tag_name === 'string' ? r.tag_name.replace(/^v/, '') : ''
  if (!isVersion(version) || r.draft || r.prerelease) return null
  const asset = (r.assets ?? []).find((a: any) => a?.name === `Salat-v${version}.zip`)
  const sha256 = /^sha256:([0-9a-f]{64})$/.exec(asset?.digest ?? '')?.[1]
  if (!sha256) return null
  return { version, sha256, size: Number(asset.size) || 0, notes: String(r.body ?? '').slice(0, 2000) }
}

/** GitHub's latest release, cached at the edge for 10 min (the unauthenticated API allows 60 calls/h per IP). */
export async function latestRelease(): Promise<UpdateInfo | null> {
  const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
    headers: { 'user-agent': UA, accept: 'application/vnd.github+json' },
    cf: { cacheTtl: 600, cacheEverything: true },
  })
  return res.ok ? parseRelease(await res.json()) : null
}

/** Streams the zip of release `v` (follows GitHub's redirect to its CDN). */
export async function downloadZip(v: string): Promise<Response> {
  const res = await fetch(zipUrl(v), { headers: { 'user-agent': UA }, redirect: 'follow', cf: { cacheTtl: 86_400, cacheEverything: true } })
  if (!res.ok || !res.body) return Response.json({ error: 'not found' }, { status: res.status === 404 ? 404 : 502 })
  return new Response(res.body, {
    headers: { 'content-type': 'application/zip', 'content-length': res.headers.get('content-length') ?? '', 'cache-control': 'public, max-age=86400' },
  })
}
