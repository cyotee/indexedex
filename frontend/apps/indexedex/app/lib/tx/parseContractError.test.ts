import { describe, expect, it } from 'vitest'
import { parseContractError } from './parseContractError'

describe('parseContractError', () => {
  it('maps user rejection (code 4001)', () => {
    expect(parseContractError({ code: 4001, message: 'User rejected the request' })).toBe(
      'Transaction rejected in wallet',
    )
  })

  it('maps user rejected message without code', () => {
    expect(parseContractError(new Error('User denied transaction signature'))).toMatch(
      /rejected/i,
    )
  })

  it('maps ACTION_REJECTED', () => {
    expect(parseContractError({ code: 'ACTION_REJECTED', message: 'denied' })).toBe(
      'Transaction rejected in wallet',
    )
  })

  it('maps insufficient funds', () => {
    expect(parseContractError(new Error('insufficient funds for gas'))).toMatch(/balance/i)
  })

  it('returns safe fallback for unknown errors', () => {
    const msg = parseContractError({ weird: true })
    expect(msg.length).toBeGreaterThan(0)
    expect(msg).not.toMatch(/^0x[a-f0-9]{8}$/i)
  })

  it('prefers shortMessage when present', () => {
    expect(
      parseContractError({
        shortMessage: 'Execution reverted',
        message: 'long stack…',
      }),
    ).toBe('Execution reverted')
  })

  it('handles null/undefined safely', () => {
    expect(parseContractError(null)).toMatch(/failed|try again/i)
    expect(parseContractError(undefined)).toMatch(/failed|try again/i)
  })
})
