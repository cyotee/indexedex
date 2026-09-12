import { describe, expect, it } from 'vitest'

import { formatWad, scaleThresholds } from './thresholdScale'

const WAD = BigInt('1000000000000000000')

describe('scaleThresholds', () => {
  it('places price between burn and mint on a Policy band', () => {
    const s = scaleThresholds(
      (WAD * BigInt(95)) / BigInt(100),
      WAD,
      (WAD * BigInt(105)) / BigInt(100),
    )
    expect(s.inert).toBe(false)
    expect(s.burnPct).toBeLessThan(s.pricePct)
    expect(s.pricePct).toBeLessThan(s.mintPct)
  })

  it('marks inert when price is missing', () => {
    expect(scaleThresholds(WAD, undefined, WAD).inert).toBe(true)
  })
})

describe('formatWad', () => {
  it('formats 1.05 WAD', () => {
    expect(formatWad((WAD * BigInt(105)) / BigInt(100))).toBe('1.05')
  })
})
