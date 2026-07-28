import type { TokenListEntry } from '../tokenlists'

export type TokenBalance = {
  token: TokenListEntry
  balance: bigint
}

export type BondNftMetadata = {
  name?: string
  description?: string
  image?: string
  rawTokenUri?: string
}

export type BondPosition = {
  kind: 'seigniorage' | 'protocol'
  detf: TokenListEntry
  nftVault: `0x${string}`
  protocolNftId?: bigint
  claimToken?: `0x${string}`
  rewardToken?: `0x${string}`
  tokenId: bigint
  lockInfo?: {
    sharesAwarded: bigint
    rewardPerShare: bigint
    bonusPercentage: bigint
    unlockTime: bigint
  }
  pendingRewards?: bigint
  metadata?: BondNftMetadata
}
