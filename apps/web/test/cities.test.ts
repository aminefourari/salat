import { describe, expect, it } from 'vitest'
import { nearestCity, searchCities } from '../src/server/cities'

describe('nearestCity', () => {
  it('finds the town for GPS coordinates', () => {
    expect(nearestCity(53.4319, 11.1903)).toEqual({ name: 'Hagenow', country: 'DE' })
    expect(nearestCity(33.5731, -7.5898)).toEqual({ name: 'Casablanca', country: 'MA' })
    expect(nearestCity(50.7766, 6.0834)?.name).toBe('Aachen')
    expect(nearestCity(48.857, 2.352)?.name).toBe('Paris')
  })
  it('handles the antimeridian', () => {
    expect(nearestCity(-18.07, -179.9, 200)?.name).toBe('Levuka')
    expect(nearestCity(-18.07, -179.9)).toBeNull()
  })
  it('returns null far from any town', () => {
    expect(nearestCity(0, -140)).toBeNull()
  })
})

describe('searchCities', () => {
  it('matches a prefix, ignoring case and accents, shortest first', () => {
    const r = searchCities('casablanca')
    expect(r).toContainEqual({ name: 'Casablanca', country: 'MA', lat: 33.59, lon: -7.61 })
    expect(searchCities('AACHEN')[0].name).toBe('Aachen')
    expect(searchCities('sale').some(c => c.name === 'Salé')).toBe(true)
    expect(r.length).toBeLessThanOrEqual(8)
  })
  it('returns nothing for a blank query', () => {
    expect(searchCities('  ')).toEqual([])
  })
})
