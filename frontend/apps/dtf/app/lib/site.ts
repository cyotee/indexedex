export type SiteId = 'dtf'
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
  id: 'dtf',
  name: 'Down To Finance',
  title: 'Down To Finance — Make an Olympus out of anything',
  description: 'DTF = Down To Finance. DETFs (Decentralized ETFs). Meme energy. Real rules. No promised APY.',
  tagline: 'You free tonight? We’re Down To Finance.',
  manifestoLabel: '// dtf manifesto · (3,3) is a vibe not a yield',
  logoSrc: '/logo.svg',
  logoAlt: 'Down To Finance',
}
export function getSite(): SiteDefinition { return SITE }
export function applySiteToDocument() {
  if (typeof document === 'undefined') return
  document.documentElement.setAttribute('data-theme', SITE.id)
  document.documentElement.setAttribute('data-brand', SITE.id)
  if (typeof document.title === 'string') document.title = SITE.title
}
