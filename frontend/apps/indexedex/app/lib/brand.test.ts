import { describe, expect, it } from 'vitest'

import { getBrand, getDefaultBrandId, normalizeBrandId } from './brand'

describe('site identity (IndexedEx app)', () => {
  it('is always indexedex', () => {
    expect(getDefaultBrandId()).toBe('indexedex')
    expect(normalizeBrandId('indexedex')).toBe('indexedex')
    expect(normalizeBrandId(null)).toBe('indexedex')
  })

  it('returns IndexedEx brand definition', () => {
    const brand = getBrand()
    expect(brand.id).toBe('indexedex')
    expect(brand.name).toBe('IndexedEx')
  })
})
