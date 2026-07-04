import { describe, expect, it } from 'vitest'
import { CHAIN_ID_SEPOLIA } from '../addressArtifacts'
import {
  filterEarnProducts,
  loadEarnProductsForChain,
  loadFeaturedEarnProducts,
  findEarnProduct,
} from './loadEarnProducts'
import strategyList from '../../addresses/chain/11155111/strategy-vaults.tokenlist.json'

/**
 * Integration-style unit tests: drive real loadEarnProductsForChain against
 * committed Sepolia tokenlist fixtures (no hardcoded catalog reimplementation).
 */
describe('loadEarnProductsForChain (committed tokenlists)', () => {
  it('returns products whose addresses appear on the strategy vault tokenlist for Sepolia', () => {
    const products = loadEarnProductsForChain(CHAIN_ID_SEPOLIA)
    const strategyOnList = new Set(
      (strategyList.tokens as Array<{ chainId: number; address: string }>)
        .filter((t) => t.chainId === CHAIN_ID_SEPOLIA)
        .map((t) => t.address.toLowerCase()),
    )

    const strategyProducts = products.filter((p) => p.productType === 'strategy')
    // Every strategy product must come from the real list (not invented).
    for (const p of strategyProducts) {
      expect(strategyOnList.has(p.address.toLowerCase())).toBe(true)
    }

    // If the fixture has vaults, catalog must surface at least one strategy product.
    if (strategyOnList.size > 0) {
      expect(strategyProducts.length).toBeGreaterThan(0)
    }
  })

  it('findEarnProduct resolves a known address from the fixture when present', () => {
    const first = (strategyList.tokens as Array<{ chainId: number; address: string }>).find(
      (t) => t.chainId === CHAIN_ID_SEPOLIA,
    )
    if (!first) return
    const hit = findEarnProduct(CHAIN_ID_SEPOLIA, first.address)
    expect(hit).toBeDefined()
    expect(hit!.address.toLowerCase()).toBe(first.address.toLowerCase())
    expect(hit!.productType).toBe('strategy')
  })

  it('loadFeaturedEarnProducts only returns addresses on the live catalog', () => {
    const catalog = loadEarnProductsForChain(CHAIN_ID_SEPOLIA)
    const featured = loadFeaturedEarnProducts(CHAIN_ID_SEPOLIA)
    const catalogSet = new Set(catalog.map((p) => p.address.toLowerCase()))
    for (const f of featured) {
      expect(catalogSet.has(f.address.toLowerCase())).toBe(true)
    }
  })

  it('filterEarnProducts strategy type matches productType field on real rows', () => {
    const catalog = loadEarnProductsForChain(CHAIN_ID_SEPOLIA)
    const filtered = filterEarnProducts(catalog, { productType: 'strategy' })
    expect(filtered.every((p) => p.productType === 'strategy')).toBe(true)
    expect(filtered.length).toBe(catalog.filter((p) => p.productType === 'strategy').length)
  })
})
