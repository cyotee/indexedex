import { describe, expect, it } from 'vitest'
import { getBrand, normalizeBrandId, otherBrand } from './brand'

describe('normalizeBrandId', () => {
  it('maps legacy current → indexedex', () => {
    expect(normalizeBrandId('current')).toBe('indexedex')
    expect(normalizeBrandId('indexedex')).toBe('indexedex')
    expect(normalizeBrandId('pachira')).toBe('pachira')
    expect(normalizeBrandId(null)).toBe('pachira')
  })
})

describe('brand definitions', () => {
  it('exposes distinct names and shared product shape', () => {
    expect(getBrand('pachira').name).toBe('Pachira')
    expect(getBrand('indexedex').name).toBe('IndexedEx')
    expect(otherBrand('pachira')).toBe('indexedex')
    expect(otherBrand('indexedex')).toBe('pachira')
  })
})
