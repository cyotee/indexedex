import { describe, expect, it } from 'vitest'

import { SQRT_PRICE_1_1 } from './sePool'
import { readV4PoolInitialized, slot0IsInitialized, uniqueAddresses } from './sePoolRead'

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

  it('dedupes vault addresses', () => {
    const a = '0x0000000000000000000000000000000000000001' as const
    const b = '0x0000000000000000000000000000000000000002' as const
    expect(uniqueAddresses([a, a, b, '0x0000000000000000000000000000000000000000'])).toEqual([a, b])
  })
})
