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
  title: 'IndexedEx — Create your own DETF',
  description: 'Create and explore DETFs (Decentralized ETFs). Hold a strategy in a single token with IndexedEx.',
  tagline: 'Your whole strategy, in a single token.',
  manifestoLabel: 'How DETFs work',
  logoSrc: '/logo.svg',
  logoAlt: 'IndexedEx',
}
export function getSite(): SiteDefinition { return SITE }
export function applySiteToDocument() {
  if (typeof document === 'undefined') return
  document.documentElement.setAttribute('data-theme', SITE.id)
  document.documentElement.setAttribute('data-brand', SITE.id)
  if (typeof document.title === 'string') document.title = SITE.title
}
