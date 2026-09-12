import { describe, expect, it } from 'vitest'

import {
  displayTokenLabel,
  displayTokenSymbol,
  displayTokenTicker,
  isRetiredRichBrand,
  omitRetiredRichEntries,
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

  it('maps RICH aliases to DTF, not a DETF ticker', () => {
    expect(displayTokenSymbol('RICH')).toBe('DTF')
    expect(displayTokenSymbol('$RICH')).toBe('DTF')
    expect(displayTokenSymbol('ttrich')).toBe('DTF')
    expect(displayTokenSymbol('RICHIR')).toBe('DTF-CLAIM')
    expect(displayTokenLabel('$RICH vault')).toBe('$DTF vault')
    expect(displayTokenLabel('TTRICHIR claim')).toBe('DTF-CLAIM claim')
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

  it('detects retired RICH tickers', () => {
    expect(isRetiredRichBrand('RICH')).toBe(true)
    expect(isRetiredRichBrand('$RICH')).toBe(true)
    expect(isRetiredRichBrand('ttrich')).toBe(true)
    expect(isRetiredRichBrand('RICHIR')).toBe(true)
    expect(isRetiredRichBrand('TTRICHIR')).toBe(true)
    expect(isRetiredRichBrand('DTF-DETF')).toBe(false)
    expect(isRetiredRichBrand('DTF')).toBe(false)
    expect(isRetiredRichBrand('WETH')).toBe(false)
  })

  it('drops RICH-labeled DETF picker rows and keeps DTF-DETF', () => {
    const out = omitRetiredRichEntries([
      { symbol: 'RICH', name: 'RICH', address: '0x1' },
      { symbol: 'RICH', name: 'Rich Token', address: '0x2' },
      { symbol: 'DTF-DETF', name: 'Protocol DETF', address: '0x3' },
      { symbol: '$$DETF', name: 'Double Dollar', address: '0x4' },
    ])
    expect(out.map((row) => row.symbol)).toEqual(['DTF-DETF', '$$DETF'])
  })
})
