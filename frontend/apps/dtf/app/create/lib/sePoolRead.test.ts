import { describe, expect, it } from 'vitest'

import { SQRT_PRICE_1_1 } from './sePool'
import { lookupV4PoolKeyById, readV4PoolInitialized, slot0IsInitialized, uniqueAddresses } from './sePoolRead'

describe('sePoolRead', () => {
  it('treats a nonzero sqrt price as initialized', () => {
    expect(slot0IsInitialized(SQRT_PRICE_1_1)).toBe(true)
    expect(slot0IsInitialized(0n)).toBe(false)
    expect(slot0IsInitialized(undefined)).toBe(false)
  })

  it('treats StateView getSlot0 with a price as initialized', async () => {
    const live = await readV4PoolInitialized(
      {
        readContract: async () => [SQRT_PRICE_1_1, 0, 0, 3000] as const,
      },
      '0xF3334192D15450CdD385c8B70e03f9A6bD9E673b',
      '0x7335aabde881aeefbd3ebfd064f33798f2f17b6a31446821977c7eb7098cfb85',
    )
    expect(live).toBe(true)
  })

  it('treats StateView getSlot0 zeros as not initialized', async () => {
    const live = await readV4PoolInitialized(
      {
        readContract: async () => [0n, 0, 0, 0] as const,
      },
      '0xF3334192D15450CdD385c8B70e03f9A6bD9E673b',
      '0x7335aabde881aeefbd3ebfd064f33798f2f17b6a31446821977c7eb7098cfb85',
    )
    expect(live).toBe(false)
  })

  it('looks up a V4 pool key from an Initialize log', async () => {
    const eth = '0x0000000000000000000000000000000000000000' as const
    const dtf = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01' as const
    const hooks = '0xe5E702641EA86f4ae6cC3cdaED2B886F976Be044' as const
    const got = await lookupV4PoolKeyById({
      client: {
        getBlockNumber: async () => 100n,
        getLogs: async () =>
          [
            {
              args: {
                currency0: dtf,
                currency1: eth,
                fee: 0,
                tickSpacing: 200,
                hooks,
              },
            },
          ] as never,
      },
      poolManager: '0x0000000000000000000000000000000000000001',
      poolId: '0x1975619ad4179048b8574d0679588c8eb132637a45fc0062c840b2640b7adcbc',
    })
    expect('error' in got).toBe(false)
    if ('error' in got) return
    expect(got.currency0).toBe(eth)
    expect(got.currency1.toLowerCase()).toBe(dtf.toLowerCase())
    expect(got.fee).toBe(0)
    expect(got.tickSpacing).toBe(200)
  })

  it('reports a missing V4 pool ID', async () => {
    const got = await lookupV4PoolKeyById({
      client: {
        getBlockNumber: async () => 10n,
        getLogs: async () => [],
      },
      poolManager: '0x0000000000000000000000000000000000000001',
      poolId: '0x1975619ad4179048b8574d0679588c8eb132637a45fc0062c840b2640b7adcbc',
    })
    expect(got).toEqual({ error: 'No Uniswap V4 pool with that ID on this network.' })
  })

  it('dedupes vault addresses', () => {
    const a = '0x0000000000000000000000000000000000000001' as const
    const b = '0x0000000000000000000000000000000000000002' as const
    expect(uniqueAddresses([a, a, b, '0x0000000000000000000000000000000000000000'])).toEqual([a, b])
  })
})
