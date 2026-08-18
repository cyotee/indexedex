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
  title: 'IndexedEx - Run your plan as one token',
  description:
    'IndexedEx lets you run a money plan as one DETF token. The basket puts that money to work in other apps.',
  tagline:
    'Run a money plan as one token. The basket works in other apps.',
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
