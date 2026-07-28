import { afterEach, describe, expect, it, vi } from 'vitest'
import { CHAIN_ID_SEPOLIA } from '../addresses'
import strategyList from '../addresses/chain/11155111/strategy-vaults.tokenlist.json'
import protocolList from '../addresses/chain/11155111/protocol-detfs.tokenlist.json'

/**
 * Wave 1.5 — prove local_testing env resolves platform overrides + chain tokenlists.
 * Drives the real getAddressArtifacts / loadEarnProducts entry points (no reimplementation).
 */
describe('local_testing address artifacts', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('getArtifactBundle registers local_testing for Sepolia', async () => {
    const { getArtifactBundle } = await import('../addresses')
    const bundle = getArtifactBundle('local_testing', CHAIN_ID_SEPOLIA)
    expect(bundle).not.toBeNull()
    expect(bundle!.environment).toBe('local_testing')
    expect(bundle!.chainId).toBe(CHAIN_ID_SEPOLIA)
  })

  it('getAddressArtifacts(local_testing) returns platform with router/permit2 from chain override', async () => {
    const { getAddressArtifacts, setDefaultDeploymentEnvironment } = await import('./addressArtifacts')
    setDefaultDeploymentEnvironment('local_testing')
    const arts = getAddressArtifacts(CHAIN_ID_SEPOLIA, 'local_testing')
    const platform = arts.platform as Record<string, unknown>
    expect(
      (platform.balancerV3StandardExchangeRouter as string | undefined) ||
        (platform.permit2 as string | undefined),
    ).toBeTruthy()
    // Chain platform override from deployments must surface (networkProfile or keys)
    expect(Number(platform.chainId)).toBe(CHAIN_ID_SEPOLIA)
  })

  it('Earn catalog under local_testing includes strategy vaults from chain tokenlist', async () => {
    const { loadEarnProductsForChain } = await import('./earn/loadEarnProducts')
    const products = loadEarnProductsForChain(CHAIN_ID_SEPOLIA, 'local_testing')
    const strategyOnList = new Set(
      (strategyList.tokens as Array<{ address: string }>).map((t) => t.address.toLowerCase()),
    )
    const strategyProducts = products.filter((p) => p.productType === 'strategy')
    expect(strategyProducts.length).toBeGreaterThan(0)
    for (const p of strategyProducts) {
      expect(strategyOnList.has(p.address.toLowerCase())).toBe(true)
    }
  })

  it('Earn catalog under local_testing does not include featured fee-detf protocol addresses', async () => {
    const { loadEarnProductsForChain } = await import('./earn/loadEarnProducts')
    const { getFeaturedFeeDetfsForChain } = await import('./tokenlists')
    const products = loadEarnProductsForChain(CHAIN_ID_SEPOLIA, 'local_testing')
    const feeAddrs = new Set(
      getFeaturedFeeDetfsForChain(CHAIN_ID_SEPOLIA, 'local_testing').map((t) =>
        t.address.toLowerCase(),
      ),
    )
    // Protocol DETF list may still list CHIR; Wave 2 keeps fee DETFs off Earn grid.
    for (const p of products) {
      expect(feeAddrs.has(p.address.toLowerCase())).toBe(false)
    }
    // Non-fee products from protocol list (if any) may still appear; at minimum catalog loads.
    expect(Array.isArray(products)).toBe(true)
    void protocolList
  })
})
