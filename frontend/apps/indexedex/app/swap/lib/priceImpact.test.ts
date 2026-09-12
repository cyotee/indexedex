import { describe, expect, it } from 'vitest'

import { formatPriceImpact, priceImpactBps } from './priceImpact'

describe('priceImpactBps', () => {
  it('returns 0 when execution matches the mid', () => {
    const q96 = BigInt(1) << BigInt(96)
    const bps = priceImpactBps({
      amountIn: BigInt(1e18),
      amountOut: BigInt(1e18),
      sqrtPriceX96: q96,
      zeroForOne: true,
    })
    expect(bps).toBe(0)
  })

  it('is positive when the swap gets less than mid', () => {
    const q96 = BigInt(1) << BigInt(96)
    const bps = priceImpactBps({
      amountIn: BigInt(100),
      amountOut: BigInt(99),
      sqrtPriceX96: q96,
      zeroForOne: true,
    })
    expect(bps).toBe(100)
  })

  it('formats Uniswap-style percents', () => {
    expect(formatPriceImpact(0)).toBe('<0.01%')
    expect(formatPriceImpact(50)).toBe('0.50%')
  })
})
