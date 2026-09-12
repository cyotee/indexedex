import { afterEach, describe, expect, it, vi } from 'vitest'

afterEach(() => {
  vi.unstubAllEnvs()
  vi.resetModules()
})

describe('wallet chain configuration', () => {
  it.each([4663, 46630])('exposes only the configured local fork (%s)', async (id) => {
    vi.stubEnv('NEXT_PUBLIC_LOCAL_RPC_URL', 'http://127.0.0.1:8545')
    const { getWalletChains } = await import('./localRpc')
    const chains = getWalletChains(id)
    expect(chains).toHaveLength(1)
    expect(chains[0].id).toBe(id)
    expect(chains[0].name).toContain('Local Anvil')
    expect(chains[0].rpcUrls.default.http).toEqual(['http://127.0.0.1:8545'])
    expect(chains[0].blockExplorers).toBeUndefined()
  }, 30_000)

  it('uses public Robinhood networks only when no local RPC is configured', async () => {
    vi.stubEnv('NEXT_PUBLIC_LOCAL_RPC_URL', '')
    const { getWalletChains } = await import('./localRpc')
    const chains = getWalletChains(46630)
    expect(chains.map((chain) => chain.id)).toEqual([46630, 4663])
    expect(chains.every((chain) => chain.rpcUrls.default.http[0].startsWith('https://'))).toBe(true)
  }, 30_000)
})
