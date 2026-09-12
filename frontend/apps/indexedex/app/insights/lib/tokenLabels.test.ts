import { describe, expect, it } from 'vitest'

import { indexTokens, isZero, labelFor, shortAddr } from './tokenLabels'

const sample = {
  chainId: 46630,
  address: '0xd97e3BCF599A5dbc893387680868d4Ad76E81206' as const,
  name: 'Test Token WETH',
  symbol: 'TTWETH',
  decimals: 18,
}

describe('tokenLabels', () => {
  it('resolves a listed address to symbol and name', () => {
    const idx = indexTokens([[sample]])
    expect(labelFor(idx, sample.address)).toEqual({ symbol: 'TTWETH', name: 'Test Token WETH' })
  })

  it('falls back to a short address when unknown', () => {
    const idx = indexTokens([[]])
    const lab = labelFor(idx, '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099')
    expect(lab?.symbol).toBe(shortAddr('0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099'))
  })

  it('treats the zero address as missing', () => {
    expect(isZero('0x0000000000000000000000000000000000000000')).toBe(true)
    expect(labelFor(indexTokens([[]]), '0x0000000000000000000000000000000000000000')).toBeNull()
  })
})
