/**
 * Dual product branding: same layout, different name + theme tokens.
 *
 * Brand is chosen at **build/deploy time** via env (not a runtime UI toggle):
 *   NEXT_PUBLIC_DEFAULT_BRAND=pachira|indexedex
 *
 * - pachira   → green theme
 * - indexedex → dark blue theme
 *
 * Configure per Vercel project so each site is a single brand for test users.
 */

export type BrandId = 'pachira' | 'indexedex'

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

/** Normalize unknown / legacy values (`current` → indexedex). */
export function normalizeBrandId(raw: string | null | undefined): BrandId {
  if (raw === 'indexedex' || raw === 'current') return 'indexedex'
  if (raw === 'pachira') return 'pachira'
  return 'pachira'
}

/**
 * Active brand for this build. Baked from NEXT_PUBLIC_DEFAULT_BRAND at build time.
 * Defaults to pachira when unset (local dev convenience).
 */
export function getDefaultBrandId(): BrandId {
  return normalizeBrandId(process.env.NEXT_PUBLIC_DEFAULT_BRAND)
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
