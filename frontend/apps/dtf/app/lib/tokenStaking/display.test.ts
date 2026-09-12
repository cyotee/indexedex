import { describe, expect, it } from 'vitest'

import { parseUnits } from 'viem'

import { claimAfterWrapDisplay, formatTokenAmount, parsePositiveAmount, migrationLabel, migrationPending } from './display'

describe('token staking display', () => {
  it('formats amounts without trailing zeros', () => {
    expect(formatTokenAmount(parseUnits('12.3400', 18))).toBe('12.34')
    expect(formatTokenAmount(0n)).toBe('0')
  })

  it('treats Staking and Migrating as pending wrap', () => {
    expect(migrationPending(0)).toBe(true)
    expect(migrationPending(1)).toBe(true)
    expect(migrationPending(2)).toBe(false)
    expect(migrationLabel(0)).toBe('Pending')
    expect(migrationLabel(1)).toBe('Wrapping')
    expect(migrationLabel(2)).toBe('Done')
  })

  it('shows "-" for claim until Wrapped', () => {
    expect(claimAfterWrapDisplay(0, 1n)).toBe('-')
    expect(claimAfterWrapDisplay(1, 1n)).toBe('-')
    expect(claimAfterWrapDisplay(2, parseUnits('1.5', 18))).toBe('1.5')
    expect(claimAfterWrapDisplay(2, undefined)).toBe('-')
  })
})


describe('migration amount precision', () => {
  it.each(['', '0', '0.000000000', '-1', '1e9', '1.0000000001', ' 1', '.1', '1.'])('rejects invalid or inexact nine-decimal input %s', (input) => {
    expect(parsePositiveAmount(input, 9)).toBeUndefined()
  })
  it('preserves every native unit of DTF and SY without number conversion', () => {
    expect(parsePositiveAmount('220032706.803999006035614295', 18)).toBe(220032706803999006035614295n)
    expect(parsePositiveAmount('0.000000001', 9)).toBe(1n)
    expect(parsePositiveAmount('9'.repeat(90), 18)).toBeUndefined()
  })
})
