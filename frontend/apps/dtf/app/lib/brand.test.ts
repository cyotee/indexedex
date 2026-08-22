import { describe, expect, it } from 'vitest'

import { getBrand, getDefaultBrandId, normalizeBrandId } from './brand'

describe('site identity (DTF app)', () => {
  it('is always dtf', () => {
    expect(getDefaultBrandId()).toBe('dtf')
    expect(normalizeBrandId('indexedex')).toBe('dtf')
    expect(normalizeBrandId(null)).toBe('dtf')
  })

  it('returns Down To Finance brand definition', () => {
    const brand = getBrand()
    expect(brand.id).toBe('dtf')
    expect(brand.name).toBe('Down To Finance')
  })
})
