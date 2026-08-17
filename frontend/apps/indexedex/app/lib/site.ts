/**
 * Fixed site identity for the IndexedEx app.
 * Site = app (no runtime brand toggle / NEXT_PUBLIC_DEFAULT_BRAND product model).
 */
export type SiteId = 'indexedex'

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
  id: 'indexedex',
  name: 'IndexedEx',
  title: 'IndexedEx - Deploy your own DETF',
  description:
    'A strategy protocol. Deploy a DETF: one token over a basket that manages assets in other protocols.',
  tagline:
    'A strategy protocol. Deploy a DETF: one token over a basket that works in other protocols.',
  manifestoLabel: '// indexedex manifesto',
  logoSrc: '/logo-indexedex.png',
  logoAlt: 'IndexedEx',
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
