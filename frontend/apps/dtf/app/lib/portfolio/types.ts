import type { BondNftPosition, BondNftClaim } from '../detf/bondNftVault'
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
  claimToken?: `0x${string}`
  tokenId: bigint
  position?: BondNftPosition
  claim?: BondNftClaim
  metadata?: BondNftMetadata
}
