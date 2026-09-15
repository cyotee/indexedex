import type { Metadata } from 'next'
import { notFound } from 'next/navigation'

import { getResearchArticle, getResearchSlugs } from '../../content/research'
import { DetfTypesView } from '../components/DetfTypesView'
import { RateProvidersView } from '../components/RateProvidersView'
import { ResearchArticleView } from '../components/ResearchArticleView'

type PageProps = {
  params: Promise<{ slug: string }>
}

export function generateStaticParams() {
  return getResearchSlugs().map((slug) => ({ slug }))
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params
  const article = getResearchArticle(slug)
  if (!article) {
    return { title: 'Research note — IndexedEx' }
  }
  return {
    title: `${article.title} — Research — IndexedEx`,
    description: article.summary,
  }
}

export default async function ResearchArticlePage({ params }: PageProps) {
  const { slug } = await params
  const article = getResearchArticle(slug)
  if (!article) notFound()
  if (article.slug === 'rate-providers') {
    return <RateProvidersView article={article} />
  }
  if (article.slug === 'detf-types') {
    return <DetfTypesView article={article} />
  }
  return <ResearchArticleView article={article} />
}
