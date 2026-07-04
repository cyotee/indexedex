/**
 * Dual product branding: same layout, different name + theme tokens.
 *
 * - pachira   → green theme (existing look)
 * - indexedex → dark blue theme
 *
 * Deploy defaults:
 *   NEXT_PUBLIC_DEFAULT_BRAND=pachira|indexedex
 * Optional lock (hide toggle on a dedicated deploy):
 *   NEXT_PUBLIC_BRAND_LOCKED=true
 */

export type BrandId = 'pachira' | 'indexedex'

export const BRAND_STORAGE_KEY = 'style-theme'

export type BrandDefinition = {
  id: BrandId
  /** Short product name in chrome */
  name: string
  /** <title> / meta */
  title: string
  description: string
  tagline: string
  manifestoLabel: string
  logoSrc: string
  logoAlt: string
}

export const BRANDS: Record<BrandId, BrandDefinition> = {
  pachira: {
    id: 'pachira',
    name: 'Pachira',
    title: 'Pachira - Composed Indexed Liquidity',
    description: 'Deposit into strategy vaults and DETFs. Composed indexed liquidity.',
    tagline: 'Composed indexed liquidity. Deposit once — strategies route the rest.',
    manifestoLabel: '// pachira manifesto',
    logoSrc: '/logo.svg',
    logoAlt: 'Pachira',
  },
  indexedex: {
    id: 'indexedex',
    name: 'IndexedEx',
    title: 'IndexedEx - Composed Indexed Liquidity',
    description: 'Modular DeFi vault infrastructure. Deposit, earn, route.',
    tagline: 'Modular vault infrastructure. Deposit once — strategies route the rest.',
    manifestoLabel: '// indexedex manifesto',
    logoSrc: '/logo-indexedex.png',
    logoAlt: 'IndexedEx',
  },
}

/** Normalize legacy storage values (`current` → indexedex). */
export function normalizeBrandId(raw: string | null | undefined): BrandId {
  if (raw === 'indexedex' || raw === 'current') return 'indexedex'
  return 'pachira'
}

export function getDefaultBrandId(): BrandId {
  const fromEnv = process.env.NEXT_PUBLIC_DEFAULT_BRAND
  if (fromEnv === 'indexedex' || fromEnv === 'pachira') return fromEnv
  return 'pachira'
}

export function isBrandLocked(): boolean {
  return process.env.NEXT_PUBLIC_BRAND_LOCKED === 'true'
}

export function getBrand(id: BrandId = getDefaultBrandId()): BrandDefinition {
  return BRANDS[id]
}

export function applyBrandToDocument(id: BrandId) {
  if (typeof document === 'undefined') return
  document.documentElement.setAttribute('data-theme', id)
  document.documentElement.setAttribute('data-brand', id)
  if (typeof document.title === 'string') {
    document.title = BRANDS[id].title
  }
}

export function readStoredBrandId(): BrandId {
  if (typeof window === 'undefined') return getDefaultBrandId()
  try {
    if (isBrandLocked()) return getDefaultBrandId()
    return normalizeBrandId(window.localStorage.getItem(BRAND_STORAGE_KEY))
  } catch {
    return getDefaultBrandId()
  }
}

export function writeStoredBrandId(id: BrandId) {
  if (typeof window === 'undefined') return
  if (isBrandLocked()) return
  try {
    window.localStorage.setItem(BRAND_STORAGE_KEY, id)
  } catch {
    // ignore
  }
}

export function otherBrand(id: BrandId): BrandId {
  return id === 'pachira' ? 'indexedex' : 'pachira'
}
