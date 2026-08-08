import { describe, expect, it } from 'vitest'

import { getBrand, getDefaultBrandId, normalizeBrandId } from './brand'

describe('site identity (IndexedEx app)', () => {
  it('is always indexedex', () => {
    expect(getDefaultBrandId()).toBe('indexedex')
    expect(normalizeBrandId('pachira')).toBe('indexedex')
    expect(normalizeBrandId('current')).toBe('indexedex')
    expect(normalizeBrandId(null)).toBe('indexedex')
  })

  it('returns IndexedEx brand definition', () => {
    const brand = getBrand()
    expect(brand.id).toBe('indexedex')
    expect(brand.name).toBe('IndexedEx')
    expect(brand.logoSrc).toContain('indexedex')
  })
})
