import type { TokenListEntry } from '@indexedex/protocol/tokenlists'

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
  kind: 'protocol'
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
