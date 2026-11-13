import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import { describe, expect, it } from 'vitest'

const src = readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8')
const load = (search: string) => runInNewContext(`${src}; ({ assetRefs, CACHE })`, {
  self: { addEventListener() {} }, location: { href: `https://salat.example/sw.js${search}`, origin: 'https://salat.example' }, URL, atob,
}) as { assetRefs: (t: string) => string[]; CACHE: string }

describe('service worker', () => {
  it('names its cache after the build id', () => {
    expect(load('?v=abc123').CACHE).toBe('salat-abc123')
    expect(load('').CACHE).toBe('salat-dev')
  })
  it('finds route chunks (absolute and relative), data and woff2 fonts, but not .woff', () => {
    const js = 'import("./quran-Da8pPDqI.js");<script src="/assets/quran-C0QccwWz.js">const u="/assets/quran-Dtdzucj6.json";url(/assets/amiri-arabic-400-normal-D0NIBXga.woff2) url(/assets/amiri-arabic-400-normal-C_1DQziU.woff)'
    expect(load('').assetRefs(js).sort()).toEqual(['/assets/amiri-arabic-400-normal-D0NIBXga.woff2', '/assets/quran-C0QccwWz.js', '/assets/quran-Da8pPDqI.js', '/assets/quran-Dtdzucj6.json'])
  })
})
