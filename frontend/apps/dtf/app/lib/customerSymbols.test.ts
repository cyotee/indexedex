import { describe, expect, it } from 'vitest'

import {
  displayTokenLabel,
  displayTokenSymbol,
  displayTokenTicker,
  relabelChirEntry,
  relabelChirList,
} from './customerSymbols'

describe('customerSymbols', () => {
  it('maps CHIR aliases to DTF-DETF', () => {
    expect(displayTokenSymbol('CHIR')).toBe('DTF-DETF')
    expect(displayTokenSymbol('$CHIR')).toBe('DTF-DETF')
    expect(displayTokenSymbol('ttchir')).toBe('DTF-DETF')
    expect(displayTokenTicker('CHIR')).toBe('$DTF-DETF')
    expect(displayTokenTicker(undefined)).toBe('$DTF-DETF')
  })

  it('rewrites CHIR inside labels without eating TTCHIR', () => {
    expect(displayTokenLabel('$CHIR vault')).toBe('$DTF-DETF vault')
    expect(displayTokenLabel('TTCHIR (0xabc)')).toBe('DTF-DETF (0xabc)')
  })

  it('leaves other symbols alone', () => {
    expect(displayTokenSymbol('WETH')).toBe('WETH')
    expect(displayTokenSymbol('DTF-DETF')).toBe('DTF-DETF')
  })

  it('relabels list entries including Protocol DETF CHIR names', () => {
    const out = relabelChirList([
      { symbol: 'CHIR', name: 'Protocol DETF CHIR', display: 'CHIR' },
      { symbol: 'WETH', name: 'Wrapped Ether' },
    ])
    expect(out[0]).toEqual({ symbol: 'DTF-DETF', name: 'Protocol DETF', display: 'DTF-DETF' })
    expect(out[1]).toEqual({ symbol: 'WETH', name: 'Wrapped Ether' })
  })

  it('relabelChirEntry is copy-safe', () => {
    const src = { symbol: 'CHIR', name: 'CHIR' }
    const out = relabelChirEntry(src)
    expect(src.symbol).toBe('CHIR')
    expect(out.symbol).toBe('DTF-DETF')
  })
})
