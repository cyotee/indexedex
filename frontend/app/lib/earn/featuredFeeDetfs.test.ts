import { afterEach, describe, expect, it, vi } from 'vitest'
import { CHAIN_ID_BASE_SEPOLIA, CHAIN_ID_SEPOLIA } from '@indexedex/protocol/addresses'
import feeList11155111 from '@indexedex/protocol/addresses/chain/11155111/featured-fee-detfs.tokenlist.json'
import feeList84532 from '@indexedex/protocol/addresses/chain/84532/featured-fee-detfs.tokenlist.json'

describe('featured-fee-detfs tokenlist + Earn exclude', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('parses featured-fee-detfs list for Sepolia with valid non-zero addresses', async () => {
    const { getFeaturedFeeDetfsForChain } = await import('@indexedex/protocol/tokenlists')
    const list = getFeaturedFeeDetfsForChain(CHAIN_ID_SEPOLIA, 'local_testing')
    const expected = (feeList11155111.tokens as Array<{ address: string }>).map((t) =>
      t.address.toLowerCase(),
    )
    expect(list.length).toBeGreaterThan(0)
    expect(list.map((t) => t.address.toLowerCase())).toEqual(expected)
    for (const t of list) {
      expect(t.address).toMatch(/^0x[0-9a-fA-F]{40}$/)
      expect(t.address.toLowerCase()).not.toBe('0x0000000000000000000000000000000000000000')
      expect(t.symbol.trim().length).toBeGreaterThan(0)
    }
  })

  it('parses featured-fee-detfs list for Base Sepolia', async () => {
    const { getFeaturedFeeDetfsForChain } = await import('@indexedex/protocol/tokenlists')
    const list = getFeaturedFeeDetfsForChain(CHAIN_ID_BASE_SEPOLIA, 'public_sepolia')
    const expected = (feeList84532.tokens as Array<{ address: string }>).map((t) =>
      t.address.toLowerCase(),
    )
    expect(list.map((t) => t.address.toLowerCase())).toEqual(expected)
  })

  it('isFeaturedFeeDetfAddress matches list membership case-insensitively', async () => {
    const { isFeaturedFeeDetfAddress, getFeaturedFeeDetfsForChain } = await import('@indexedex/protocol/tokenlists')
    const [hero] = getFeaturedFeeDetfsForChain(CHAIN_ID_SEPOLIA, 'local_testing')
    expect(hero).toBeTruthy()
    expect(isFeaturedFeeDetfAddress(CHAIN_ID_SEPOLIA, 'local_testing', hero.address)).toBe(true)
    expect(isFeaturedFeeDetfAddress(CHAIN_ID_SEPOLIA, 'local_testing', hero.address.toUpperCase())).toBe(
      true,
    )
    expect(
      isFeaturedFeeDetfAddress(
        CHAIN_ID_SEPOLIA,
        'local_testing',
        '0x0000000000000000000000000000000000000001',
      ),
    ).toBe(false)
  })

  it('Earn catalog excludes featured fee-detf addresses', async () => {
    const { loadEarnProductsForChain } = await import('./loadEarnProducts')
    const { getFeaturedFeeDetfsForChain } = await import('@indexedex/protocol/tokenlists')
    const feeAddrs = new Set(
      getFeaturedFeeDetfsForChain(CHAIN_ID_SEPOLIA, 'local_testing').map((t) =>
        t.address.toLowerCase(),
      ),
    )
    expect(feeAddrs.size).toBeGreaterThan(0)

    const products = loadEarnProductsForChain(CHAIN_ID_SEPOLIA, 'local_testing')
    for (const p of products) {
      expect(feeAddrs.has(p.address.toLowerCase())).toBe(false)
    }
  })

  it('loadFeaturedFeeDetfs returns up to max cards in list order', async () => {
    const { loadFeaturedFeeDetfs } = await import('./loadEarnProducts')
    const { getFeaturedFeeDetfsForChain } = await import('@indexedex/protocol/tokenlists')
    const full = getFeaturedFeeDetfsForChain(CHAIN_ID_SEPOLIA, 'local_testing')
    const featured = loadFeaturedFeeDetfs(CHAIN_ID_SEPOLIA, 'local_testing', 3)
    expect(featured.length).toBe(Math.min(3, full.length))
    if (full[0] && featured[0]) {
      expect(featured[0].address.toLowerCase()).toBe(full[0].address.toLowerCase())
    }
  })

  it('feeDetfStakingHref points at staking with detf query', async () => {
    const { feeDetfStakingHref } = await import('@indexedex/protocol/tokenlists')
    const addr = '0xD6359e57572AF5685AbE48C6Fd928826c887096f'
    expect(feeDetfStakingHref(addr)).toBe(`/staking?detf=${addr}`)
  })
})
