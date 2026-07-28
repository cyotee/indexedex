import { describe, expect, it } from 'vitest'
import {
  sanitizeShareAddress,
  sanitizeShareAmount,
  sanitizeShareCulture,
  sanitizeSharePosition,
  sanitizeShareSymbol,
  sharePositionPlainText,
  stripUnsafeText,
} from './sanitizeShareFields'

describe('sanitizeShareFields', () => {
  it('strips markup and control characters', () => {
    expect(stripUnsafeText('<script>alert(1)</script> CHIR', 64)).toBe('scriptalert(1)/script CHIR')
    expect(stripUnsafeText('a\u0000b', 10)).toBe('ab')
  })

  it('sanitizes symbols without HTML', () => {
    expect(sanitizeShareSymbol('CHIR')).toBe('CHIR')
    // Prefer last ticker-like token; never retain markup characters.
    expect(sanitizeShareSymbol('<img src=x onerror=1>WETH')).toBe('WETH')
    expect(sanitizeShareSymbol('<img src=x onerror=1>WETH')).not.toMatch(/<|>/)
    expect(sanitizeShareSymbol(null)).toBe('—')
  })

  it('sanitizes amount labels to numeric forms', () => {
    expect(sanitizeShareAmount('1.5')).toBe('1.5')
    expect(sanitizeShareAmount('12.34 CHIR')).toBe('12.34 CHIR')
    expect(sanitizeShareAmount('<b>9</b>')).toBe('—')
    expect(sanitizeShareAmount('—')).toBe('—')
  })

  it('accepts only 20-byte hex addresses', () => {
    const ok = '0xD6359e57572AF5685AbE48C6Fd928826c887096f'
    expect(sanitizeShareAddress(ok)).toBe(ok)
    expect(sanitizeShareAddress('0xdead')).toBe('')
    expect(sanitizeShareAddress('<svg onload=1>')).toBe('')
  })

  it('never embeds culture unless showCulture', () => {
    const base = sanitizeSharePosition({
      kind: 'vault-share',
      symbol: 'sWETH',
      amountLabel: '1.0',
      cultureLine: 'employ the bags',
      showCulture: false,
    })
    expect(base.cultureLine).toBe('')
    expect(sharePositionPlainText(base)).not.toMatch(/employ/i)

    const withCulture = sanitizeSharePosition({
      kind: 'bond-nft',
      symbol: 'CHIR',
      amountLabel: '2.0',
      detailLabel: 'Bond #3',
      address: '0xD6359e57572AF5685AbE48C6Fd928826c887096f',
      brandName: 'Pachira',
      cultureLine: 'the index is empty until you fill it',
      showCulture: true,
    })
    expect(withCulture.cultureLine).toMatch(/index/)
    const text = sharePositionPlainText(withCulture)
    expect(text).toContain('Bond #3')
    expect(text).toContain('0xD6359e57572AF5685AbE48C6Fd928826c887096f')
    expect(text).not.toMatch(/<|>/)
  })

  it('rejects culture XSS payload after sanitize', () => {
    expect(sanitizeShareCulture('<img src=x onerror=alert(1)>bags')).not.toMatch(/<|>/)
  })
})
