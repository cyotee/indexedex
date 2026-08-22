import { describe, expect, it } from 'vitest'

import { findCandidatePaths } from './v4Route'
import type { Address, V4PoolKey } from './v4Types'
import { ZERO_ADDRESS } from './v4Types'
import { encodeUniversalSwap } from './v4Encode'
import { CMD_V4_SWAP } from './v4Encode'

const A = '0x0000000000000000000000000000000000000001' as Address
const B = '0x0000000000000000000000000000000000000002' as Address
const C = '0x0000000000000000000000000000000000000003' as Address
const HOOK = '0x0000000000000000000000000000000000000abc' as Address

function pool(c0: Address, c1: Address, hooks: Address = ZERO_ADDRESS, fee = 3000): V4PoolKey {
  const [currency0, currency1] = c0.toLowerCase() < c1.toLowerCase() ? [c0, c1] : [c1, c0]
  return { currency0, currency1, fee, tickSpacing: 60, hooks }
}

describe('findCandidatePaths', () => {
  it('finds a single-hop vanilla pool', () => {
    const paths = findCandidatePaths([pool(A, B)], A, B)
    expect(paths).toHaveLength(1)
    expect(paths[0]!.hops).toHaveLength(1)
    expect(paths[0]!.hops[0]!.tokenOut.toLowerCase()).toBe(B.toLowerCase())
    expect(paths[0]!.hops[0]!.pool.hooks).toBe(ZERO_ADDRESS)
  })

  it('includes hooked pools in the same graph as vanilla', () => {
    const paths = findCandidatePaths([pool(A, B, HOOK)], A, B)
    expect(paths).toHaveLength(1)
    expect(paths[0]!.hops[0]!.pool.hooks.toLowerCase()).toBe(HOOK.toLowerCase())
  })

  it('finds a two-hop path through a hooked pool', () => {
    const paths = findCandidatePaths([pool(A, B, HOOK), pool(B, C)], A, C)
    expect(paths.some((p) => p.hops.length === 2)).toBe(true)
    const two = paths.find((p) => p.hops.length === 2)!
    expect(two.hops[0]!.pool.hooks.toLowerCase()).toBe(HOOK.toLowerCase())
    expect(two.hops[1]!.tokenOut.toLowerCase()).toBe(C.toLowerCase())
  })

  it('returns empty when no connecting pools', () => {
    expect(findCandidatePaths([pool(A, B)], A, C)).toEqual([])
  })
})

describe('encodeUniversalSwap', () => {
  it('encodes a V4_SWAP command for a single hop', () => {
    const encoded = encodeUniversalSwap({
      route: {
        hops: [
          {
            pool: pool(A, B),
            tokenIn: A,
            tokenOut: B,
            zeroForOne: A.toLowerCase() < B.toLowerCase(),
          },
        ],
        amountIn: BigInt('1000000000000000000'),
        amountOut: BigInt('900000000000000000'),
      },
      amountOutMinimum: BigInt(1),
      nativeIn: false,
    })
    expect(encoded.commands).toBe(`0x${CMD_V4_SWAP.toString(16).padStart(2, '0')}`)
    expect(encoded.inputs).toHaveLength(1)
    expect(encoded.value).toBe(BigInt(0))
  })

  it('sets msg.value for native input', () => {
    const encoded = encodeUniversalSwap({
      route: {
        hops: [
          {
            pool: pool(ZERO_ADDRESS, B),
            tokenIn: ZERO_ADDRESS,
            tokenOut: B,
            zeroForOne: true,
          },
        ],
        amountIn: BigInt(5),
        amountOut: BigInt(4),
      },
      amountOutMinimum: BigInt(1),
      nativeIn: true,
    })
    expect(encoded.value).toBe(BigInt(5))
  })
})
