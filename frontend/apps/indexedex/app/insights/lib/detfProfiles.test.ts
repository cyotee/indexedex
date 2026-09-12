import { describe, expect, it } from 'vitest'

import { pairAddresses, profileFor } from './detfProfiles'

describe('profileFor', () => {
  it('finds DTF-DETF by address', () => {
    const p = profileFor('0xb5F0543DD9D758F8DD577856A5Df848674af335d')
    expect(p?.symbols).toContain('DTF-DETF')
    expect(p?.family).toBe('one-vault')
    expect(p?.kicker).toMatch(/Protocol DETF/)
    expect(p?.firstBonded).toBe(true)
  })

  it('finds Double Dollar by $$DETF symbol', () => {
    const p = profileFor('0x0000000000000000000000000000000000000000', '$$DETF')
    expect(p?.shape).toMatch(/Three/)
    expect(pairAddresses(p!).map((a) => a.toLowerCase())).toHaveLength(3)
  })

  it('returns undefined for an unknown listing', () => {
    expect(profileFor('0x1111111111111111111111111111111111111111', 'NOPE')).toBeUndefined()
  })
})
