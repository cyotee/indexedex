import { describe, expect, it } from 'vitest'

import { getBrand, getDefaultBrandId, normalizeBrandId } from './brand'

describe('site identity (Pachira app)', () => {
  it('is always pachira', () => {
    expect(getDefaultBrandId()).toBe('pachira')
    expect(normalizeBrandId('indexedex')).toBe('pachira')
    expect(normalizeBrandId(null)).toBe('pachira')
  })

  it('returns Pachira brand definition', () => {
    const brand = getBrand()
    expect(brand.id).toBe('pachira')
    expect(brand.name).toBe('Pachira')
  })
})
