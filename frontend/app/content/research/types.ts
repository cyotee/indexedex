export type ResearchArticleStatus = 'published' | 'draft'

export type ResearchSection = {
  heading?: string
  paragraphs: string[]
  bullets?: string[]
}

export type ResearchArticle = {
  slug: string
  title: string
  summary: string
  /** ISO date YYYY-MM-DD */
  date: string
  tags: string[]
  status: ResearchArticleStatus
  sections: ResearchSection[]
  /** Short “what we show” */
  claims: string[]
  /** Mandatory honesty list */
  notClaiming: string[]
  relatedProductHref?: string
  relatedProductLabel?: string
  /** Monorepo path pointers for transparency */
  sourceNote?: string
}
