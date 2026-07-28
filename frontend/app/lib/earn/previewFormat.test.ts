import { describe, expect, it } from 'vitest'
import { formatPreviewAmount } from './previewFormat'

describe('formatPreviewAmount', () => {
  it('uses provided decimals (6) not hardcoded 18', () => {
    // 1_500_000 at 6 decimals = 1.5
    expect(formatPreviewAmount(BigInt(1_500_000), 6)).toBe('1.5')
  })

  it('uses 18 decimals for vault shares', () => {
    expect(formatPreviewAmount(BigInt('1000000000000000000'), 18)).toBe('1')
  })

  it('falls back to 18 for invalid decimals', () => {
    expect(formatPreviewAmount(BigInt('1000000000000000000'), Number.NaN)).toBe('1')
  })
})
