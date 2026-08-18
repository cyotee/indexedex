import type { RiskLevel } from './riskFromTags'

export type Address = `0x${string}`

/**
 * Earn catalog product kinds.
 * - `strategy` — SE / buffer vaults
 * - `detf` — standard DETF instances (lab / non-fee)
 * - `protocol-detf` — fee DETF only (product brand “Protocol DETF”; usually lives on /staking)
 */
export type EarnProductType = 'strategy' | 'detf' | 'protocol-detf'

export type { RiskLevel }

export type EarnProduct = {
  address: Address
  chainId: number
  name: string
  symbol: string
  decimals: number
  display?: string
  productType: EarnProductType
  /** From tokenlist risk-* tags / extensions.risk only; omit when untagged. */
  risk?: RiskLevel
}

export type EarnProductInput = {
  address: string
  chainId: number
  name: string
  symbol: string
  decimals: number
  display?: string
  /** Uniswap-style tokenlist tags (may include risk-*, fee-detf). */
  tags?: string[]
  extensions?: Record<string, unknown>
  /** Pre-resolved risk; if omitted, assembled from tags/extensions. */
  risk?: RiskLevel
}

export type EarnCatalogInputs = {
  strategy?: EarnProductInput[]
  protocolDetf?: EarnProductInput[]
}

export type EarnFilterOptions = {
  /** When set (and not 'all'), only products of this type remain. */
  productType?: EarnProductType | 'all'
  /** Case-insensitive match against name, symbol, display, or address. */
  search?: string
}

export const EARN_PRODUCT_TYPE_LABEL: Record<EarnProductType, string> = {
  strategy: 'Vault',
  detf: 'DETF',
  'protocol-detf': 'Protocol DETF',
}
