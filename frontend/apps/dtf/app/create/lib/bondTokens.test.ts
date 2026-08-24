import { describe, expect, it } from 'vitest'

import {
  defaultFirstBondToken,
  firstBondTokenAddresses,
  firstBondTokenOptionLabel,
  resolveVaultShare,
  ZERO_ADDRESS,
} from './bondTokens'

const SE = '0x1111111111111111111111111111111111111111' as const
const SHARE = '0x2222222222222222222222222222222222222222' as const
const PAIR = '0x3333333333333333333333333333333333333333' as const
const OTHER = '0x4444444444444444444444444444444444444444' as const
const DETF = '0x5555555555555555555555555555555555555555' as const

describe('resolveVaultShare', () => {
  it('uses the share when it is set', () => {
    expect(resolveVaultShare(SE, SHARE)).toBe(SHARE)
  })

  it('falls back to the SE vault when share is zero', () => {
    expect(resolveVaultShare(SE, ZERO_ADDRESS)).toBe(SE)
    expect(resolveVaultShare(SE, undefined)).toBe(SE)
  })
})

describe('firstBondTokenAddresses', () => {
  it('lists the vault token first, then SE vaultTokens()', () => {
    expect(
      firstBondTokenAddresses({
        seVault: SE,
        vaultShare: SHARE,
        seVaultTokens: [PAIR, OTHER],
        detf: DETF,
      }),
    ).toEqual([SHARE, PAIR, OTHER])
  })

  it('uses the SE vault as the vault token when share is unset', () => {
    expect(
      firstBondTokenAddresses({
        seVault: SE,
        vaultShare: ZERO_ADDRESS,
        seVaultTokens: [PAIR, OTHER],
        detf: DETF,
      }),
    ).toEqual([SE, PAIR, OTHER])
  })

  it('drops the DETF token, zeros, and duplicates', () => {
    expect(
      firstBondTokenAddresses({
        seVault: SE,
        vaultShare: SE,
        seVaultTokens: [PAIR, SE, ZERO_ADDRESS, DETF, PAIR],
        detf: DETF,
      }),
    ).toEqual([SE, PAIR])
  })
})

describe('defaultFirstBondToken', () => {
  it('prefers the configured pair token when it is in the list', () => {
    expect(defaultFirstBondToken([SE, PAIR, OTHER], PAIR)).toBe(PAIR)
  })

  it('falls back to the first token', () => {
    expect(defaultFirstBondToken([SE, OTHER], PAIR)).toBe(SE)
    expect(defaultFirstBondToken([], PAIR)).toBe('')
  })
})

describe('firstBondTokenOptionLabel', () => {
  it('marks the vault token', () => {
    expect(
      firstBondTokenOptionLabel({ address: SE, symbol: 'SE-TT', vaultShare: SE }),
    ).toBe('SE-TT (vault token)')
    expect(
      firstBondTokenOptionLabel({ address: PAIR, symbol: 'TTAAPL', vaultShare: SE }),
    ).toBe('TTAAPL')
  })
})
