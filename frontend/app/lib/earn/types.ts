export type Address = `0x${string}`

/** Earn catalog product kinds merged from tokenlists. */
export type EarnProductType = 'strategy' | 'protocol-detf' | 'seigniorage-detf'

export type EarnProduct = {
  address: Address
  chainId: number
  name: string
  symbol: string
  decimals: number
  display?: string
  productType: EarnProductType
}

export type EarnProductInput = {
  address: string
  chainId: number
  name: string
  symbol: string
  decimals: number
  display?: string
}

export type EarnCatalogInputs = {
  strategy?: EarnProductInput[]
  protocolDetf?: EarnProductInput[]
  seigniorageDetf?: EarnProductInput[]
}

export type EarnFilterOptions = {
  /** When set (and not 'all'), only products of this type remain. */
  productType?: EarnProductType | 'all'
  /** Case-insensitive match against name, symbol, display, or address. */
  search?: string
}

export const EARN_PRODUCT_TYPE_LABEL: Record<EarnProductType, string> = {
  strategy: 'Strategy',
  'protocol-detf': 'Protocol DETF',
  'seigniorage-detf': 'Seigniorage DETF',
}
