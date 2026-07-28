import { describe, expect, it } from 'vitest'
import {
  assembleEarnProducts,
  filterEarnProducts,
  parseFeaturedAddressList,
  resolveFeaturedProducts,
} from './assembleEarnProducts'
import { parseLaunchQuery } from './launchQuery'
import type { EarnProduct } from './types'

const A = '0x1111111111111111111111111111111111111111'
const B = '0x2222222222222222222222222222222222222222'
const C = '0x3333333333333333333333333333333333333333'
const UNKNOWN = '0x4444444444444444444444444444444444444444'

describe('assembleEarnProducts', () => {
  it('merges strategy and DETF lists with strategy precedence on address clash', () => {
    const products = assembleEarnProducts({
      strategy: [
        { address: A, chainId: 11155111, name: 'Vault A', symbol: 'VA', decimals: 18 },
      ],
      protocolDetf: [
        { address: A, chainId: 11155111, name: 'DETF A', symbol: 'DA', decimals: 18 },
        { address: B, chainId: 11155111, name: 'DETF B', symbol: 'DB', decimals: 18 },
      ],
      seigniorageDetf: [
        { address: C, chainId: 11155111, name: 'Seig C', symbol: 'SC', decimals: 18 },
      ],
    })

    expect(products).toHaveLength(3)
    expect(products.map((p) => p.address.toLowerCase()).sort()).toEqual(
      [A, B, C].map((x) => x.toLowerCase()).sort(),
    )
    const a = products.find((p) => p.address.toLowerCase() === A.toLowerCase())
    expect(a?.productType).toBe('strategy')
    expect(a?.symbol).toBe('VA')
    expect(products.find((p) => p.address.toLowerCase() === B.toLowerCase())?.productType).toBe(
      'protocol-detf',
    )
    expect(products.find((p) => p.address.toLowerCase() === C.toLowerCase())?.productType).toBe(
      'seigniorage-detf',
    )
  })

  it('drops zero and invalid addresses', () => {
    const products = assembleEarnProducts({
      strategy: [
        { address: '0x0000000000000000000000000000000000000000', chainId: 1, name: 'Z', symbol: 'Z', decimals: 18 },
        { address: 'not-an-address', chainId: 1, name: 'X', symbol: 'X', decimals: 18 },
        { address: A, chainId: 1, name: 'Ok', symbol: 'OK', decimals: 18 },
      ],
    })
    expect(products).toHaveLength(1)
    expect(products[0].address).toBe(A)
  })

  it('resolves risk from tags only; untagged products omit risk', () => {
    const products = assembleEarnProducts({
      strategy: [
        {
          address: A,
          chainId: 1,
          name: 'Tagged',
          symbol: 'T',
          decimals: 18,
          tags: ['strat', 'risk-experimental'],
        },
        { address: B, chainId: 1, name: 'Plain', symbol: 'P', decimals: 18, tags: ['strat'] },
      ],
    })
    expect(products.find((p) => p.symbol === 'T')?.risk).toBe('experimental')
    expect(products.find((p) => p.symbol === 'P')?.risk).toBeUndefined()
  })
})

describe('filterEarnProducts', () => {
  const catalog: EarnProduct[] = assembleEarnProducts({
    strategy: [{ address: A, chainId: 1, name: 'Alpha Vault', symbol: 'ALP', decimals: 18 }],
    protocolDetf: [{ address: B, chainId: 1, name: 'Beta DETF', symbol: 'BET', decimals: 18 }],
  })

  it('filters by product type', () => {
    const onlyStrategy = filterEarnProducts(catalog, { productType: 'strategy' })
    expect(onlyStrategy).toHaveLength(1)
    expect(onlyStrategy[0].symbol).toBe('ALP')
  })

  it('searches name/symbol/address without hardcoding full catalog size incorrectly', () => {
    const byName = filterEarnProducts(catalog, { search: 'beta' })
    expect(byName.map((p) => p.symbol)).toEqual(['BET'])
    const byAddr = filterEarnProducts(catalog, { search: A.slice(0, 10) })
    expect(byAddr).toHaveLength(1)
    expect(byAddr[0].address.toLowerCase()).toBe(A.toLowerCase())
  })
})

describe('resolveFeaturedProducts', () => {
  it('keeps only candidates present on the live catalog, in candidate order', () => {
    const catalog = assembleEarnProducts({
      strategy: [
        { address: A, chainId: 1, name: 'A', symbol: 'A', decimals: 18 },
        { address: B, chainId: 1, name: 'B', symbol: 'B', decimals: 18 },
      ],
    })
    const featured = resolveFeaturedProducts([UNKNOWN, B, A, B], catalog)
    expect(featured.map((p) => p.address.toLowerCase())).toEqual([
      B.toLowerCase(),
      A.toLowerCase(),
    ])
  })

  it('parseFeaturedAddressList splits env-style strings', () => {
    expect(parseFeaturedAddressList(`${A}, ${B}\n${C}`)).toEqual([A, B, C])
    expect(parseFeaturedAddressList('')).toEqual([])
    expect(parseFeaturedAddressList(undefined)).toEqual([])
  })
})

describe('parseLaunchQuery', () => {
  it('parses launch mode and tokenOut for swap handoff', () => {
    const q = parseLaunchQuery({ launch: '1', tokenOut: A, tokenIn: B })
    expect(q.isLaunchMode).toBe(true)
    expect(q.tokenOut?.toLowerCase()).toBe(A.toLowerCase())
    expect(q.tokenIn?.toLowerCase()).toBe(B.toLowerCase())
  })

  it('rejects invalid tokenOut', () => {
    const q = parseLaunchQuery({ launch: '1', tokenOut: 'nope' })
    expect(q.isLaunchMode).toBe(true)
    expect(q.tokenOut).toBeNull()
  })
})
