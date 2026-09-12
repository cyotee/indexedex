import { bondVsMintArticle } from './articles/bond-vs-mint'
import { detfArticle } from './articles/detf'
import { detfTypesArticle } from './articles/detf-types'
import { rateProvidersArticle } from './articles/rate-providers'
import { uniswapV4MarketsArticle } from './articles/uniswap-v4-markets'
import type { ResearchArticle } from './types'

export type {
  ResearchArticle,
  ResearchArticleStatus,
  ResearchDiagramId,
  ResearchSection,
} from './types'

/** All registered articles (published + draft). */
export const RESEARCH_ARTICLES: ResearchArticle[] = [
  detfArticle,
  uniswapV4MarketsArticle,
  detfTypesArticle,
  bondVsMintArticle,
  rateProvidersArticle,
]

function isLabUnlocked(): boolean {
  return process.env.NEXT_PUBLIC_SHOW_DEBUG === 'true'
}

/** Articles visible in the public index and routes. */
export function listPublishedResearchArticles(): ResearchArticle[] {
  const includeDrafts = isLabUnlocked()
  return RESEARCH_ARTICLES.filter(
    (a) => a.status === 'published' || (includeDrafts && a.status === 'draft'),
  ).sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : a.title.localeCompare(b.title)))
}

export function getResearchArticle(slug: string): ResearchArticle | undefined {
  const article = RESEARCH_ARTICLES.find((a) => a.slug === slug)
  if (!article) return undefined
  if (article.status === 'draft' && !isLabUnlocked()) return undefined
  return article
}

export function getResearchSlugs(): string[] {
  return listPublishedResearchArticles().map((a) => a.slug)
}
