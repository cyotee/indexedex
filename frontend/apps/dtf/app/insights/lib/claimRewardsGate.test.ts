import { describe, expect, it } from 'vitest'

import {
  addressesMatch,
  bondIdScanCount,
  bondOwnerAddress,
  bondUnlockState,
  claimRewardsBlockedReason,
  claimRewardsButtonEnabled,
  ownedBondIdsFromOwnerReads,
  parseBondTokenId,
  walletCanSignOnChain,
} from './claimRewardsGate'

const OWNER = '0x1111111111111111111111111111111111111111'
const WALLET = '0x1111111111111111111111111111111111111111'
const OTHER = '0x2222222222222222222222222222222222222222'
const ZERO = '0x0000000000000000000000000000000000000000'

describe('parseBondTokenId', () => {
  it('parses decimal and hex ids', () => {
    expect(parseBondTokenId('1')).toBe(1n)
    expect(parseBondTokenId(' 0x3 ')).toBe(3n)
  })

  it('rejects empty and junk', () => {
    expect(parseBondTokenId('')).toBeUndefined()
    expect(parseBondTokenId('  ')).toBeUndefined()
    expect(parseBondTokenId('1.5')).toBeUndefined()
    expect(parseBondTokenId('#1')).toBeUndefined()
  })
})

describe('bondOwnerAddress', () => {
  it('drops the zero address', () => {
    expect(bondOwnerAddress(ZERO)).toBeUndefined()
    expect(bondOwnerAddress(OWNER)).toBe(OWNER)
  })
})

describe('walletCanSignOnChain', () => {
  it('matches mint/bond: wallet chain must equal the app chain', () => {
    expect(
      walletCanSignOnChain({
        isConnected: true,
        appChainId: 46630,
        localWallet: false,
      }),
    ).toBe(false)
  })

  it('requires a reported wallet chain to match', () => {
    expect(
      walletCanSignOnChain({
        isConnected: true,
        walletChainId: 1,
        appChainId: 46630,
        localWallet: false,
      }),
    ).toBe(false)
    expect(
      walletCanSignOnChain({
        isConnected: true,
        walletChainId: 46630,
        appChainId: 46630,
        localWallet: false,
      }),
    ).toBe(true)
  })

  it('allows Anvil wallets against a lab chain', () => {
    expect(
      walletCanSignOnChain({
        isConnected: true,
        walletChainId: 31337,
        appChainId: 46630,
        localWallet: true,
      }),
    ).toBe(true)
  })
})

describe('claimRewardsButtonEnabled', () => {
  it('enables for a signed-in wallet with a token id while the bond is still locked', () => {
    expect(
      claimRewardsButtonEnabled({
        canSign: true,
        tokenId: 1n,
        matured: false,
        pendingRewards: 0n,
        owner: OWNER,
        wallet: WALLET,
      }),
    ).toBe(true)
  })

  it('does not require pending rewards or owner match to show the button', () => {
    expect(
      claimRewardsButtonEnabled({
        canSign: true,
        tokenId: 3n,
        matured: false,
        pendingRewards: 0n,
        owner: OTHER,
        wallet: WALLET,
      }),
    ).toBe(true)
  })

  it('stays off until a token id is entered', () => {
    expect(claimRewardsButtonEnabled({ canSign: true })).toBe(false)
    expect(claimRewardsButtonEnabled({ canSign: false, tokenId: 1n })).toBe(false)
  })
})

describe('claimRewardsBlockedReason', () => {
  it('asks for a token id when the wallet can sign', () => {
    expect(
      claimRewardsBlockedReason({
        isConnected: true,
        walletMatches: true,
        appChainId: 46630,
      }),
    ).toBe('Enter a bond token ID.')
  })
})

describe('bondUnlockState', () => {
  it('treats future unlock as locked', () => {
    expect(bondUnlockState(200n, 100)).toEqual({ locked: true })
    expect(bondUnlockState(100n, 100)).toEqual({ locked: false })
    expect(bondUnlockState(0n, 100)).toEqual({ locked: null })
  })
})

describe('addressesMatch', () => {
  it('is case-insensitive', () => {
    expect(addressesMatch(OWNER, OWNER.toUpperCase())).toBe(true)
    expect(addressesMatch(OWNER, OTHER)).toBe(false)
  })
})

describe('ownedBondIdsFromOwnerReads', () => {
  it('keeps ids whose ownerOf matches the wallet', () => {
    expect(
      ownedBondIdsFromOwnerReads(
        [{ result: OTHER }, { result: OWNER }, { result: ZERO }, { status: 'failure' }],
        WALLET,
      ),
    ).toEqual([2n])
  })
})

describe('bondIdScanCount', () => {
  it('uses nextTokenId when present', () => {
    expect(bondIdScanCount(5n)).toBe(4)
    expect(bondIdScanCount(1n)).toBe(32)
  })
})
