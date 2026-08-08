import { describe, expect, it } from 'vitest'
import { formatUnits } from 'viem'
import { formatBondAmount } from './formatBondAmount'

describe('formatBondAmount', () => {
  it('formats 18-decimal shares via formatUnits (not raw wei string)', () => {
    const shares = BigInt('1500000000000000000') // 1.5e18
    const formatted = formatBondAmount(shares, 18)
    expect(formatted).toBe(formatUnits(shares, 18))
    expect(formatted).toBe('1.5')
    expect(formatted).not.toBe(shares.toString())
  })

  it('formats zero and large values without wei dump', () => {
    expect(formatBondAmount(BigInt(0), 18)).toBe('0')
    const large = BigInt('123456789012345678901234567')
    const out = formatBondAmount(large, 18)
    expect(out).toBe(formatUnits(large, 18))
    expect(out.includes('e') || out.includes('.') || /^\d+$/.test(out)).toBe(true)
    expect(out).not.toBe(large.toString())
  })

  it('returns em dash for missing amounts', () => {
    expect(formatBondAmount(undefined)).toBe('—')
    expect(formatBondAmount(null)).toBe('—')
  })
})
