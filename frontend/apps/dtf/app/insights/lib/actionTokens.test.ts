import { describe, expect, it } from 'vitest'

import {
  actionTokenOptionLabel,
  asAddr,
  collectActionTokenAddresses,
  collectSeVaultReadAddresses,
} from './actionTokens'

const P0 = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206' as const
const P1 = '0x00a7413b2d28BAfe10d9182299Ad6d58F90E2665' as const
const SE = '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099' as const
const VT = '0x1111111111111111111111111111111111111111' as const
const ZERO = '0x0000000000000000000000000000000000000000' as const

describe('collectActionTokenAddresses', () => {
  it('uses weighted pairTokens when the singular pairToken view is missing', () => {
    expect(
      collectActionTokenAddresses({
        pairTokens: [P0, P1],
        pairToken: undefined,
      }),
    ).toEqual([P0, P1])
  })

  it('dedupes pair tokens, SE shares, and nested vault tokens', () => {
    expect(
      collectActionTokenAddresses({
        pairTokens: [P0, P1],
        acceptedBondTokens: [P0],
        vaultShares: [SE, ZERO],
        standardExchanges: [SE],
        seVaultTokens: [[P0, VT]],
        pairToken: P0,
      }),
    ).toEqual([P0, P1, SE, VT])
  })

  it('exports asAddr for non-zero hex addresses', () => {
    expect(asAddr(P0)).toBe(P0)
    expect(asAddr(ZERO)).toBeNull()
    expect(asAddr('nope')).toBeNull()
  })

  it('falls back to singular pair views', () => {
    expect(
      collectActionTokenAddresses({
        pairToken: P0,
        pair0: P1,
      }),
    ).toEqual([P0, P1])
  })

  it('reads one-vault SE tokens when standardExchanges is empty', () => {
    expect(
      collectSeVaultReadAddresses({
        standardExchanges: [],
        underlyingVault: SE,
        standardExchangeVault: SE,
      }),
    ).toEqual([SE])
    expect(
      collectActionTokenAddresses({
        pairToken: P0,
        underlyingVault: SE,
        seVaultTokens: [[P0, VT]],
        exclude: [P0],
      }),
    ).toEqual([SE, VT])
  })

  it('includes vault share and rateAsset, then drops the DETF itself', () => {
    const detf = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117' as const
    expect(
      collectActionTokenAddresses({
        pairToken: P0,
        rateAsset: P0,
        standardExchangeVaultShare: SE,
        seVaultTokens: [[P0, VT, detf]],
        exclude: [detf],
      }),
    ).toEqual([P0, SE, VT])
  })

  it('marks the vault share in the dropdown label', () => {
    expect(actionTokenOptionLabel({ address: SE, symbol: 'SE-DTF' }, SE)).toBe('SE-DTF (vault token)')
    expect(actionTokenOptionLabel({ address: P0, symbol: 'WETH' }, SE)).toBe('WETH')
  })
})
