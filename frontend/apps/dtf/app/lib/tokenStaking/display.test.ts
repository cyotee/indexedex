import { describe, expect, it } from 'vitest'

import { parseUnits } from 'viem'

import { claimAfterWrapDisplay, formatTokenAmount, migrationLabel, migrationPending } from './display'

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
