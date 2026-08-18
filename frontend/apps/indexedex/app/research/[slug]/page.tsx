import type { Metadata } from 'next'
import { notFound } from 'next/navigation'

import { getResearchArticle, getResearchSlugs } from '../../content/research'
import { BondVsMintView } from '../components/BondVsMintView'
import { DetfTypesView } from '../components/DetfTypesView'
import { DetfView } from '../components/DetfView'
import { RateProvidersView } from '../components/RateProvidersView'
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
  if (article.slug === 'bond-vs-mint') {
    return <BondVsMintView article={article} />
  }
  if (article.slug === 'detf') {
    return <DetfView article={article} />
  }
  if (article.slug === 'rate-providers') {
    return <RateProvidersView article={article} />
  }
  if (article.slug === 'detf-types') {
    return <DetfTypesView article={article} />
  }
  return <ResearchArticleView article={article} />
}
