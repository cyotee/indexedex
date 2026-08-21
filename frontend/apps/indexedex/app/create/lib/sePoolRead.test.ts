import { encodePacked, keccak256 } from 'viem'
import { describe, expect, it } from 'vitest'

import { SQRT_PRICE_1_1 } from './sePool'
import { sqrtPriceX96FromExtsloadWord, uniqueAddresses, V4_POOLS_SLOT, v4PoolStateSlot } from './sePoolRead'

describe('sePoolRead', () => {
  it('hashes poolId with POOLS_SLOT 6', () => {
    const poolId = '0x7622c4c9aa8465e92bf0f6f3d1437e8e1e0a283ae5d2a337f1225845eb9c9dd4' as const
    const expected = keccak256(encodePacked(['bytes32', 'uint256'], [poolId, V4_POOLS_SLOT]))
    expect(v4PoolStateSlot(poolId)).toBe(expected)
  })

  it('reads sqrtPrice from the low 160 bits of slot0', () => {
    const word = `0x${(SQRT_PRICE_1_1).toString(16).padStart(64, '0')}` as const
    expect(sqrtPriceX96FromExtsloadWord(word)).toBe(SQRT_PRICE_1_1)
    expect(sqrtPriceX96FromExtsloadWord('0x'.padEnd(66, '0') as `0x${string}`)).toBe(0n)
  })

  it('dedupes vault addresses', () => {
    const a = '0x0000000000000000000000000000000000000001' as const
    const b = '0x0000000000000000000000000000000000000002' as const
    expect(uniqueAddresses([a, a, b, '0x0000000000000000000000000000000000000000'])).toEqual([a, b])
  })
})
