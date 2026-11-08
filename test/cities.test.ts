import { describe, expect, it } from 'vitest'
import { nearestCity } from '../src/server/cities'

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
