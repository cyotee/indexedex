import { resolveRiskLevel } from '@indexedex/protocol/earn/riskFromTags'
import type {
  Address,
  EarnCatalogInputs,
  EarnFilterOptions,
  EarnProduct,
  EarnProductInput,
  EarnProductType,
} from '@indexedex/protocol/earn/types'

function isHexAddress(value: string): value is Address {
  return /^0x[0-9a-fA-F]{40}$/.test(value)
}

function normalizeAddress(address: string): Address | null {
  if (!isHexAddress(address)) return null
  if (address.toLowerCase() === '0x0000000000000000000000000000000000000000') return null
  return address as Address
}

function toProduct(entry: EarnProductInput, productType: EarnProductType): EarnProduct | null {
  const address = normalizeAddress(entry.address)
  if (!address) return null
  if (!Number.isFinite(entry.chainId) || entry.chainId <= 0) return null
  const risk =
    entry.risk ?? resolveRiskLevel(entry.tags, entry.extensions ?? null)
  return {
    address,
    chainId: entry.chainId,
    name: (entry.name ?? '').trim() || address,
    symbol: (entry.symbol ?? '').trim() || '???',
    decimals: Number.isFinite(entry.decimals) ? entry.decimals : 18,
    display: entry.display,
    productType,
    ...(risk ? { risk } : {}),
  }
}

/**
 * Merge strategy vaults and DETF tokenlist entries into a unified Earn catalog.
 * Later lists do not override an address already claimed by an earlier kind
 * (strategy wins, then protocol DETF).
 */
export function assembleEarnProducts(inputs: EarnCatalogInputs): EarnProduct[] {
  const out: EarnProduct[] = []
  const seen = new Set<string>()

  const pushAll = (list: EarnProductInput[] | undefined, productType: EarnProductType) => {
    if (!list) return
    for (const entry of list) {
      const product = toProduct(entry, productType)
      if (!product) continue
      const key = `${product.chainId}:${product.address.toLowerCase()}`
      if (seen.has(key)) continue
      seen.add(key)
      out.push(product)
    }
  }

  pushAll(inputs.strategy, 'strategy')
  pushAll(inputs.protocolDetf, 'protocol-detf')

  return out
}

/** Filter and optionally search a catalog assembled by {@link assembleEarnProducts}. */
export function filterEarnProducts(
  products: readonly EarnProduct[],
  options: EarnFilterOptions = {},
): EarnProduct[] {
  const typeFilter = options.productType && options.productType !== 'all' ? options.productType : null
  const q = (options.search ?? '').trim().toLowerCase()

  return products.filter((p) => {
    if (typeFilter && p.productType !== typeFilter) return false
    if (!q) return true
    const hay = [p.name, p.symbol, p.display ?? '', p.address].join(' ').toLowerCase()
    return hay.includes(q)
  })
}

/**
 * Keep featured candidate addresses that exist in the live catalog for this chain.
 * Order follows `candidates`; unknown or off-list addresses are dropped.
 */
export function resolveFeaturedProducts(
  candidates: readonly string[],
  products: readonly EarnProduct[],
): EarnProduct[] {
  if (!candidates.length || !products.length) return []
  const byAddress = new Map(products.map((p) => [p.address.toLowerCase(), p]))
  const out: EarnProduct[] = []
  const seen = new Set<string>()
  for (const raw of candidates) {
    if (typeof raw !== 'string') continue
    const key = raw.trim().toLowerCase()
    if (!key || seen.has(key)) continue
    const hit = byAddress.get(key)
    if (!hit) continue
    seen.add(key)
    out.push(hit)
  }
  return out
}

/** Parse comma-separated featured addresses from env (or any string). */
export function parseFeaturedAddressList(raw: string | undefined | null): string[] {
  if (!raw) return []
  return raw
    .split(/[\s,]+/)
    .map((s) => s.trim())
    .filter(Boolean)
}
