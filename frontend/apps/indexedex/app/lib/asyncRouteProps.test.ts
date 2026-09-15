import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it, vi } from 'vitest'

vi.mock('../earn/[address]/EarnDetailClient', () => ({
  default: ({ address }: { address: string }) => createElement('div', { 'data-address': address }),
}))
vi.mock('../insights/InsightsPageClient', () => ({
  default: ({ pathAddress }: { pathAddress: string }) => createElement('div', { 'data-address': pathAddress }),
}))
vi.mock('../research/components/ResearchArticleView', () => ({
  ResearchArticleView: ({ article }: { article: { slug: string } }) => createElement('div', null, article.slug),
}))
vi.mock('../research/components/DetfTypesView', () => ({
  DetfTypesView: ({ article }: { article: { slug: string } }) => createElement('div', null, article.slug),
}))
vi.mock('../research/components/RateProvidersView', () => ({
  RateProvidersView: ({ article }: { article: { slug: string } }) => createElement('div', null, article.slug),
}))
vi.mock('next/navigation', () => ({
  notFound: () => { throw new Error('NEXT_NOT_FOUND') },
  redirect: (destination: string) => { throw new Error(`NEXT_REDIRECT:${destination}`) },
}))

import EarnDetailPage from '../earn/[address]/page'
import InsightsDetfPage from '../insights/[address]/page'
import ResearchArticlePage, { generateMetadata } from '../research/[slug]/page'
import YouPage from '../you/page'

describe('async Next.js route props', () => {
  const address = '0x0000000000000000000000000000000000000001'

  it('resolves Earn address before handing it to the client', async () => {
    const element = await EarnDetailPage({ params: Promise.resolve({ address }) })
    expect(renderToStaticMarkup(element)).toContain(`data-address="${address}"`)
  })

  it('resolves Insights address before handing it to the client', async () => {
    const element = await InsightsDetfPage({ params: Promise.resolve({ address }) })
    expect(renderToStaticMarkup(element)).toContain(`data-address="${address}"`)
  })

  it.each(['detf', 'detf-types', 'rate-providers'])('resolves research route %s', async slug => {
    const element = await ResearchArticlePage({ params: Promise.resolve({ slug }) })
    expect(renderToStaticMarkup(element)).toContain(slug)
    const metadata = await generateMetadata({ params: Promise.resolve({ slug }) })
    expect(metadata.description).toBeTruthy()
  })

  it('keeps missing research articles as not found', async () => {
    await expect(ResearchArticlePage({ params: Promise.resolve({ slug: 'not-a-research-note' }) }))
      .rejects.toThrow('NEXT_NOT_FOUND')
  })

  it('preserves repeated and encoded query values in the portfolio redirect', async () => {
    await expect(YouPage({ searchParams: Promise.resolve({ token: ['one', 'two'], q: 'a & b', absent: undefined }) }))
      .rejects.toThrow('NEXT_REDIRECT:/portfolio?token=one&token=two&q=a+%26+b')
  })

  it('does not append an empty query to the portfolio redirect', async () => {
    await expect(YouPage({ searchParams: Promise.resolve({}) })).rejects.toThrow('NEXT_REDIRECT:/portfolio')
  })
})
