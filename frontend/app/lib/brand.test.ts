import { afterEach, describe, expect, it, vi } from 'vitest'
import { getBrand, getDefaultBrandId, normalizeBrandId } from './brand'

describe('normalizeBrandId', () => {
  it('maps legacy current → indexedex', () => {
    expect(normalizeBrandId('current')).toBe('indexedex')
    expect(normalizeBrandId('indexedex')).toBe('indexedex')
    expect(normalizeBrandId('pachira')).toBe('pachira')
    expect(normalizeBrandId(null)).toBe('pachira')
    expect(normalizeBrandId('unknown')).toBe('pachira')
  })
})

describe('brand definitions', () => {
  it('exposes distinct names and shared product shape', () => {
    expect(getBrand('pachira').name).toBe('Pachira')
    expect(getBrand('indexedex').name).toBe('IndexedEx')
    expect(getBrand('pachira').logoSrc).toBe('/logo.svg')
    expect(getBrand('indexedex').logoSrc).toBe('/logo-indexedex.png')
  })
})

describe('getDefaultBrandId', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('defaults to pachira when env unset', () => {
    vi.stubEnv('NEXT_PUBLIC_DEFAULT_BRAND', '')
    expect(getDefaultBrandId()).toBe('pachira')
  })

  it('reads indexedex from env', () => {
    vi.stubEnv('NEXT_PUBLIC_DEFAULT_BRAND', 'indexedex')
    expect(getDefaultBrandId()).toBe('indexedex')
  })

  it('reads pachira from env', () => {
    vi.stubEnv('NEXT_PUBLIC_DEFAULT_BRAND', 'pachira')
    expect(getDefaultBrandId()).toBe('pachira')
  })
})
