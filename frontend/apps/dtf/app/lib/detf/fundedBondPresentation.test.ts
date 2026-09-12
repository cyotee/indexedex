import { describe, expect, it } from 'vitest'
import { fundedBondClaimAvailability, fundedBondRole } from './fundedBondPresentation'

describe('funded bond claims', () => {
  it('enables partially vested principal without a maturity gate', () => {
    expect(fundedBondClaimAvailability({ tokenId: 3n, principalDue: 50_000_000_000n, rewardsDue: 0n })).toEqual({ rewards: false, combined: true })
  })
  it('permits reward-only claims before any principal vests', () => {
    expect(fundedBondClaimAvailability({ tokenId: 3n, principalDue: 0n, rewardsDue: 10_000_000_000n })).toEqual({ rewards: true, combined: true })
  })
  it('does not offer an NFT claim for standing fee and creator roles', () => {
    expect(fundedBondRole(1n)).toBe('Fee recipient')
    expect(fundedBondRole(2n)).toBe('Creator')
    for (const tokenId of [0n, 1n, 2n]) expect(fundedBondClaimAvailability({ tokenId, principalDue: 1n, rewardsDue: 1n })).toEqual({ rewards: false, combined: false })
  })
  it('disables empty, unread and pending claims', () => {
    expect(fundedBondClaimAvailability({ tokenId: 3n })).toEqual({ rewards: false, combined: false })
    expect(fundedBondClaimAvailability({ tokenId: 3n, principalDue: 1n, rewardsDue: 1n, pending: true })).toEqual({ rewards: false, combined: false })
  })
})
