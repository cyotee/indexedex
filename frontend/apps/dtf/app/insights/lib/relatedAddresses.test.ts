import { describe, expect, it } from 'vitest'

import { collectDetfRelatedAddresses } from './relatedAddresses'

const DETF = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117' as const
const RATE = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206' as const
const PAIR = '0x00a7413b2d28BAfe10d9182299Ad6d58F90E2665' as const
const SE = '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099' as const
const SHARE = '0x1111111111111111111111111111111111111111' as const
const VT = '0x2222222222222222222222222222222222222222' as const
const CLAIM = '0x3333333333333333333333333333333333333333' as const
const POOL = '0x4444444444444444444444444444444444444444' as const
const BOND = '0x5555555555555555555555555555555555555555' as const
const PROTO = '0x6666666666666666666666666666666666666666' as const
const ZERO = '0x0000000000000000000000000000000000000000' as const

describe('collectDetfRelatedAddresses', () => {
  it('puts the DETF token first and skips the zero address', () => {
    const rows = collectDetfRelatedAddresses({
      detf: DETF,
      rateAsset: RATE,
      pairToken: ZERO,
      underlyingVault: SE,
    })
    expect(rows[0]).toEqual({ role: 'DETF token', address: DETF })
    expect(rows.map((r) => r.role)).toEqual(['DETF token', 'Rate asset', 'Underlying vault'])
  })

  it('dedupes by address; first role wins', () => {
    const rows = collectDetfRelatedAddresses({
      detf: DETF,
      rateAsset: RATE,
      pairTokens: [RATE, PAIR],
      pairToken: PAIR,
      vaultShares: [SHARE],
      standardExchangeVaultShare: SHARE,
      underlyingVault: SE,
      standardExchanges: [SE],
      seVaultTokens: [[RATE, VT, DETF]],
      claimToken: CLAIM,
      reservePool: POOL,
      bondNftVault: BOND,
      protocolNftVault: PROTO,
    })
    expect(rows).toEqual([
      { role: 'DETF token', address: DETF },
      { role: 'Rate asset', address: RATE },
      { role: 'Pair token', address: PAIR },
      { role: 'Vault share', address: SHARE },
      { role: 'Underlying vault', address: SE },
      { role: 'Vault token', address: VT },
      { role: 'Claim token', address: CLAIM },
      { role: 'Reserve pool', address: POOL },
      { role: 'Bond NFT', address: BOND },
      { role: 'Protocol NFT', address: PROTO },
    ])
  })

  it('includes nested SE vault tokens when pair lists are empty', () => {
    expect(
      collectDetfRelatedAddresses({
        detf: DETF,
        seVaultTokens: [[VT], [undefined, ZERO, PAIR]],
      }),
    ).toEqual([
      { role: 'DETF token', address: DETF },
      { role: 'Vault token', address: VT },
      { role: 'Vault token', address: PAIR },
    ])
  })
})
