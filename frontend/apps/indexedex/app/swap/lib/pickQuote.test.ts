import { describe, expect, it } from 'vitest'

import { pickQuote } from './pickQuote'
import type { Address, SwapRoute, V4PoolKey } from './v4Types'
import { ZERO_ADDRESS } from './v4Types'

const A = '0x0000000000000000000000000000000000000001' as Address
const B = '0x0000000000000000000000000000000000000002' as Address
const HOOK = '0x0000000000000000000000000000000000000abc' as Address

function route(hooks: Address, amountOut: bigint): SwapRoute {
  const pool: V4PoolKey = {
    currency0: A,
    currency1: B,
    fee: 3000,
    tickSpacing: 60,
    hooks,
  }
  return {
    hops: [{ pool, tokenIn: A, tokenOut: B, zeroForOne: true }],
    amountIn: BigInt(100),
    amountOut,
  }
}

const uni = (amountOut: bigint) =>
  ({
    amountOut,
    to: A,
    data: '0x1234' as `0x${string}`,
    value: BigInt(0),
    source: 'uniswap-api' as const,
  })

describe('pickQuote', () => {
  it('keeps a hooked local route against a slightly better Uniswap quote', () => {
    expect(pickQuote(route(HOOK, BigInt(100)), uni(BigInt(101)))).toBe('local')
  })

  it('uses Uniswap when vanilla local is worse', () => {
    expect(pickQuote(route(ZERO_ADDRESS, BigInt(100)), uni(BigInt(120)))).toBe('uniswap')
  })

  it('uses Uniswap if it is the only quote', () => {
    expect(pickQuote(null, uni(BigInt(50)))).toBe('uniswap')
  })
})
