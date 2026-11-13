import { describe, expect, it } from 'vitest'
import { habousMonthToFetch, mergeHabous, type HabousDays } from '../src/lib/habous-days'

// Same cases as apps/macos/SalatTests/HabousTests.swift.
const place = '33.573,-7.590'
const nov: HabousDays = { place, days: Object.fromEntries(Array.from({ length: 30 }, (_, i) => [`2026-11-${String(i + 1).padStart(2, '0')}`, [0, 0, 0, 0, 0, 0]])) }
const empty: HabousDays = { place: '', days: {} }

describe('habousMonthToFetch', () => {
  it('asks for the missing month only', () => {
    expect(habousMonthToFetch(empty, place, '2026-11-11')).toBe('2026-11')
    expect(habousMonthToFetch(nov, place, '2026-11-11')).toBe('') // cached: no request
    expect(habousMonthToFetch(nov, place, '2026-11-30')).toBe('2026-12') // tomorrow is in December
    expect(habousMonthToFetch(nov, '34.020,-6.840', '2026-11-11')).toBe('2026-11') // another place
  })
  it('never asks without a place, or for a place with no Habous city', () => {
    expect(habousMonthToFetch(nov, '', '2026-11-11')).toBe('')
    expect(habousMonthToFetch({ place, days: {}, none: true }, place, '2026-11-11')).toBe('')
    expect(habousMonthToFetch({ place: 'x', days: {}, none: true }, place, '2026-11-11')).toBe('2026-11')
  })
})

describe('mergeHabous', () => {
  it('keeps recent days for the same place only', () => {
    const old: HabousDays = { place, days: { '2026-11-09': [1], '2026-11-10': [2], '2026-11-11': [3] } }
    expect(Object.keys(mergeHabous(old, place, { '2026-11-12': [4] }, '2026-11-10').days).sort()).toEqual(['2026-11-10', '2026-11-11', '2026-11-12'])
    expect(Object.keys(mergeHabous(old, '1.000,2.000', { '2026-11-12': [4] }, '2026-11-10').days)).toEqual(['2026-11-12'])
    expect(mergeHabous({ ...old, none: true }, place, {}, '2026-11-10').none).toBeUndefined()
  })
})
