import type { Metadata } from 'next'
import { notFound } from 'next/navigation'

import { getResearchArticle, getResearchSlugs } from '../../content/research'
import { ResearchArticleView } from '../components/ResearchArticleView'

type PageProps = {
  params: { slug: string }
}

export function generateStaticParams() {
  return getResearchSlugs().map((slug) => ({ slug }))
}

export function generateMetadata({ params }: PageProps): Metadata {
  const article = getResearchArticle(params.slug)
  if (!article) {
    return { title: 'Research note — IndexedEx' }
  }
  return {
    title: `${article.title} — Research — IndexedEx`,
    description: article.summary,
  }
}

export default function ResearchArticlePage({ params }: PageProps) {
  const article = getResearchArticle(params.slug)
  if (!article) notFound()
  return <ResearchArticleView article={article} />
}
