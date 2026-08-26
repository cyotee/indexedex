import { getAddress } from 'viem'
import { describe, expect, it } from 'vitest'

import {
  BUY_CLAIM_SELECTOR,
  DEPOSIT_CLAIM_SELECTOR,
  claimMintPathFromFacets,
  collectStakeTokenAddresses,
  formatTokenAmount,
  insightsStakingHref,
  resolveClaimMintPath,
} from './claimMint'

const DETF = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117' as const
const PAIR = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206' as const
const FACET = '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099' as const
const ZERO = '0x0000000000000000000000000000000000000000' as const

describe('claim mint path', () => {
  it('uses 4-byte selectors', () => {
    expect(DEPOSIT_CLAIM_SELECTOR).toMatch(/^0x[0-9a-f]{8}$/)
    expect(BUY_CLAIM_SELECTOR).toMatch(/^0x[0-9a-f]{8}$/)
    expect(DEPOSIT_CLAIM_SELECTOR).not.toBe(BUY_CLAIM_SELECTOR)
  })

  it('prefers depositClaim when that facet is wired', () => {
    expect(
      claimMintPathFromFacets({ depositClaimFacet: FACET, buyClaimFacet: FACET }),
    ).toBe('depositClaim')
  })

  it('uses buyClaim when only that facet is wired', () => {
    expect(
      claimMintPathFromFacets({ depositClaimFacet: ZERO, buyClaimFacet: FACET }),
    ).toBe('buyClaim')
  })

  it('falls back to weighted depositClaim when loupe is empty', () => {
    expect(resolveClaimMintPath({ weighted: true })).toBe('depositClaim')
    expect(resolveClaimMintPath({ weighted: false })).toBe('buyClaim')
  })
})

describe('collectStakeTokenAddresses', () => {
  it('limits buyClaim to the DETF token', () => {
    expect(
      collectStakeTokenAddresses({
        path: 'buyClaim',
        detf: DETF,
        actionTokens: [PAIR, DETF],
      }),
    ).toEqual([DETF])
  })

  it('adds DETF after pair tokens for depositClaim', () => {
    expect(
      collectStakeTokenAddresses({
        path: 'depositClaim',
        detf: DETF,
        actionTokens: [PAIR],
      }),
    ).toEqual([PAIR, DETF])
  })

  it('dedupes DETF if it is already an action token', () => {
    expect(
      collectStakeTokenAddresses({
        path: 'depositClaim',
        detf: DETF,
        actionTokens: [DETF, PAIR],
      }),
    ).toEqual([DETF, PAIR])
  })
})

describe('formatTokenAmount', () => {
  it('trims long fractions', () => {
    expect(formatTokenAmount(1_500_000_000_000_000_000n)).toBe('1.5')
  })

  it('dashes missing values', () => {
    expect(formatTokenAmount(undefined)).toBe('—')
  })
})

describe('insightsStakingHref', () => {
  it('keeps Protocol DETF /staking separate', () => {
    expect(insightsStakingHref(DETF)).toBe(`/insights/${getAddress(DETF)}?tab=stake`)
    expect(insightsStakingHref(DETF)).not.toMatch(/^\/staking(\?|$)/)
    expect(insightsStakingHref(DETF)).not.toMatch(/[?&]detf=/)
  })
})
