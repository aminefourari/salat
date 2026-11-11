import { describe, expect, it } from 'vitest'
import { isVersion, parseRelease } from '../src/server/update'

const release = {
  tag_name: 'v1.2.0', draft: false, prerelease: false, body: 'notes',
  assets: [{ name: 'Salat-v1.2.0.zip', size: 11065932, digest: `sha256:${'a'.repeat(64)}` }],
}

describe('parseRelease', () => {
  it('reads version, digest and size', () => {
    expect(parseRelease(release)).toEqual({ version: '1.2.0', sha256: 'a'.repeat(64), size: 11065932, notes: 'notes' })
  })
  it.each([
    ['no digest', { ...release, assets: [{ ...release.assets[0], digest: undefined }] }],
    ['wrong asset name', { ...release, assets: [{ ...release.assets[0], name: 'other.zip' }] }],
    ['prerelease', { ...release, prerelease: true }],
    ['odd tag', { ...release, tag_name: 'nightly' }],
    ['garbage', null],
  ])('rejects %s', (_, r) => expect(parseRelease(r)).toBeNull())
})

it('only accepts plain x.y.z versions (they go into a GitHub URL)', () => {
  expect(isVersion('1.2.3')).toBe(true)
  for (const v of ['1.2', '1.2.3/../x', 'v1.2.3', '', null]) expect(isVersion(v)).toBe(false)
})
