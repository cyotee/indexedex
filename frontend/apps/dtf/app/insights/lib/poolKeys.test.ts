import { keccak256, pad, stringToBytes } from 'viem'
import { describe, expect, it } from 'vitest'

import { toPoolId } from '../../swap/lib/v4PoolId'
import type { Address } from '../../swap/lib/v4Types'
import { ZERO_ADDRESS } from '../../swap/lib/v4Types'
import {
  DETF_RESERVE_FEE,
  DETF_RESERVE_TICK_SPACING,
  decodePackedFeeTickHooks,
  decodeSePoolKeySlots,
  detfReservePoolKey,
  poolIdFromKey,
  poolKeyFromTuple,
  poolKeyFromUnknown,
  UNI_V4_SE_POOL_KEY_SLOT,
} from './poolKeys'

const C0 = '0x0000000000000000000000000000000000000001' as Address
const C1 = '0x0000000000000000000000000000000000000002' as Address
const HOOK = '0x0000000000000000000000000000000000000abc' as Address

function packFeeTickHooks(fee: number, tickSpacing: number, hooks: Address): `0x${string}` {
  const tick = tickSpacing < 0 ? tickSpacing + 0x1000000 : tickSpacing
  const v = BigInt(fee) + (BigInt(tick) << 24n) + (BigInt(hooks) << 48n)
  return (`0x${v.toString(16).padStart(64, '0')}`) as `0x${string}`
}

describe('UNI_V4_SE_POOL_KEY_SLOT', () => {
  it('is keccak256 of the repo slot string', () => {
    expect(UNI_V4_SE_POOL_KEY_SLOT).toMatch(/^0x[0-9a-f]{64}$/)
    expect(UNI_V4_SE_POOL_KEY_SLOT).toBe(
      keccak256(stringToBytes('indexedex.protocols.dexes.uniswap.v4.pool.key.aware')),
    )
  })
})

describe('decodePackedFeeTickHooks', () => {
  it('round-trips fee, tick spacing, and hooks', () => {
    const word = packFeeTickHooks(0, 60, HOOK)
    expect(decodePackedFeeTickHooks(word)).toEqual({ fee: 0, tickSpacing: 60, hooks: HOOK })
  })
})

describe('decodeSePoolKeySlots', () => {
  it('reads a stored Uni V4 PoolKey', () => {
    const s0 = pad(C0, { size: 32 })
    const s1 = pad(C1, { size: 32 })
    const s2 = packFeeTickHooks(0, 60, HOOK)
    expect(decodeSePoolKeySlots(s0, s1, s2)).toEqual({
      currency0: C0,
      currency1: C1,
      fee: 0,
      tickSpacing: 60,
      hooks: HOOK,
    })
  })

  it('returns null when both currencies are zero', () => {
    const z = pad(ZERO_ADDRESS, { size: 32 })
    expect(decodeSePoolKeySlots(z, z, packFeeTickHooks(0, 60, HOOK))).toBeNull()
  })
})

describe('detfReservePoolKey', () => {
  it('sorts currencies and uses fee 0 / tick 60', () => {
    const key = detfReservePoolKey({ currency0: C1, currency1: C0, hooks: HOOK })
    expect(key).toEqual({
      currency0: C0,
      currency1: C1,
      fee: DETF_RESERVE_FEE,
      tickSpacing: DETF_RESERVE_TICK_SPACING,
      hooks: HOOK,
    })
    expect(poolIdFromKey(key)).toBe(toPoolId(key!))
  })
})

describe('poolKeyFromTuple', () => {
  it('rejects identical currencies', () => {
    expect(
      poolKeyFromTuple({
        currency0: C0,
        currency1: C0,
        fee: 0,
        tickSpacing: 60,
        hooks: HOOK,
      }),
    ).toBeNull()
  })
})

describe('poolKeyFromUnknown', () => {
  it('accepts a 5-tuple from a contract return', () => {
    const key = poolKeyFromUnknown([C1, C0, 0, 60, HOOK])
    expect(key?.currency0).toBe(C0)
    expect(key?.hooks).toBe(HOOK)
  })
})
