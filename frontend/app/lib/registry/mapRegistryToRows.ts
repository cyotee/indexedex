import type { EarnProduct } from '../earn/types'
import type { Address } from './pickRegistryQuery'

export type SearchResultSource = 'preferred' | 'registry'

export type VaultSearchRow = {
  address: Address
  chainId: number
  name: string
  symbol: string
  decimals: number
  display?: string
  /** Preferred list product type when known; registry-only rows use strategy as neutral. */
  productType: EarnProduct['productType'] | 'registry'
  source: SearchResultSource
}

/**
 * Merge registry addresses with preferred tokenlist metadata when available.
 * Pure: no RPC.
 */
export function mapRegistryAddressesToRows(
  addresses: readonly string[],
  chainId: number,
  preferred: readonly EarnProduct[],
): VaultSearchRow[] {
  const byAddr = new Map(preferred.map((p) => [p.address.toLowerCase(), p]))
  const out: VaultSearchRow[] = []
  const seen = new Set<string>()

  for (const raw of addresses) {
    if (typeof raw !== 'string' || !/^0x[0-9a-fA-F]{40}$/.test(raw)) continue
    const key = raw.toLowerCase()
    if (seen.has(key)) continue
    seen.add(key)
    const hit = byAddr.get(key)
    if (hit) {
      out.push({
        address: hit.address,
        chainId: hit.chainId,
        name: hit.name,
        symbol: hit.symbol,
        decimals: hit.decimals,
        display: hit.display,
        productType: hit.productType,
        source: 'registry',
      })
    } else {
      const short = `${raw.slice(0, 6)}…${raw.slice(-4)}`
      out.push({
        address: raw as Address,
        chainId,
        name: `Vault ${short}`,
        symbol: 'VAULT',
        decimals: 18,
        display: `Registered vault (${short})`,
        productType: 'registry',
        source: 'registry',
      })
    }
  }
  return out
}

export function preferredToRows(preferred: readonly EarnProduct[]): VaultSearchRow[] {
  return preferred.map((p) => ({
    address: p.address,
    chainId: p.chainId,
    name: p.name,
    symbol: p.symbol,
    decimals: p.decimals,
    display: p.display,
    productType: p.productType,
    source: 'preferred' as const,
  }))
}
