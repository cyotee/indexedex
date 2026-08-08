/**
 * Fixed site identity for the Pachira app.
 * Site = app (no runtime brand toggle / NEXT_PUBLIC_DEFAULT_BRAND product model).
 */
export type SiteId = 'pachira'

export type SiteDefinition = {
  id: SiteId
  name: string
  title: string
  description: string
  tagline: string
  manifestoLabel: string
  logoSrc: string
  logoAlt: string
}

export const SITE: SiteDefinition = {
  id: 'pachira',
  name: 'Pachira',
  title: 'Pachira - Composed Indexed Liquidity',
  description: 'Deposit into strategy vaults and DETFs. Composed indexed liquidity.',
  tagline: 'Composed indexed liquidity. Deposit once — strategies route the rest.',
  manifestoLabel: '// pachira manifesto',
  logoSrc: '/logo.svg',
  logoAlt: 'Pachira',
}

export function getSite(): SiteDefinition {
  return SITE
}

export function applySiteToDocument() {
  if (typeof document === 'undefined') return
  document.documentElement.setAttribute('data-theme', SITE.id)
  document.documentElement.setAttribute('data-brand', SITE.id)
  if (typeof document.title === 'string') {
    document.title = SITE.title
  }
}
