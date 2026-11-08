import { describe, expect, it } from 'vitest'
import { compass8, kaabaDistanceKm, qibla, turnDelta } from '../src/lib/prayer'

describe('qibla helpers', () => {
  it('bearing and distance from Hagenow', () => {
    expect(qibla(53.4319, 11.1903)).toBeCloseTo(134.5, 0)
    expect(Math.round(kaabaDistanceKm(53.4319, 11.1903) / 10) * 10).toBe(4310)
  })
  it('turnDelta takes the short way round', () => {
    expect(turnDelta(135, 100)).toBe(35)
    expect(turnDelta(10, 350)).toBe(20)
    expect(turnDelta(350, 10)).toBe(-20)
    expect(turnDelta(90, 270)).toBe(-180)
  })
  it('compass8 names the direction', () => {
    expect([0, 44, 135, 180, 300, 359].map(compass8)).toEqual([0, 1, 3, 4, 7, 0])
  })
})
