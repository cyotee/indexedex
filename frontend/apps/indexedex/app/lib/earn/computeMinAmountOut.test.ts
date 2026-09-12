import { describe, expect, it } from 'vitest'
import { computeMinAmountOut } from './computeMinAmountOut'

describe('computeMinAmountOut', () => {
  it('returns 0 when preview missing', () => {
    expect(computeMinAmountOut(undefined, 0.5)).toBe(BigInt(0))
    expect(computeMinAmountOut(null, 0.5)).toBe(BigInt(0))
    expect(computeMinAmountOut(BigInt(0), 0.5)).toBe(BigInt(0))
  })

  it('applies 0.5% slippage', () => {
    const out = BigInt(10_000)
    // 0.5% → 50 bps → 9950
    expect(computeMinAmountOut(out, 0.5)).toBe(BigInt(9950))
  })

  it('clamps slippage to 0–5%', () => {
    const out = BigInt(10_000)
    expect(computeMinAmountOut(out, -1)).toBe(BigInt(10_000))
    expect(computeMinAmountOut(out, 10)).toBe(BigInt(9500)) // 5%
  })

  it('0% slippage returns full preview', () => {
    expect(computeMinAmountOut(BigInt(12345), 0)).toBe(BigInt(12345))
  })
})
