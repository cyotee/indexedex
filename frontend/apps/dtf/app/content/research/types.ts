export type ResearchArticleStatus = 'published' | 'draft'

/** Optional composition diagram id — rendered by ResearchArticleView. */
export type ResearchDiagramId =
  | 'single-standard-exchange'
  | 'multi-vault-weighted'
  | 'multi-vault-stable'
  | 'mixed-buffer-multi-vault-stable'

export type ResearchSection = {
  heading?: string
  paragraphs: string[]
  bullets?: string[]
  /** Composition diagram under the section body (optional). */
  diagram?: ResearchDiagramId
  /** Mermaid flowchart source (optional; client-rendered). Use ConstProd, never a two-letter constant-product shorthand. */
  mermaid?: string
  mermaidCaption?: string
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
