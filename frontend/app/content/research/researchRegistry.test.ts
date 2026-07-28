import { describe, expect, it } from 'vitest'

import {
  getResearchArticle,
  getResearchSlugs,
  listPublishedResearchArticles,
  RESEARCH_ARTICLES,
} from './index'

describe('research registry', () => {
  it('registers four seed articles with unique slugs', () => {
    expect(RESEARCH_ARTICLES).toHaveLength(4)
    const slugs = RESEARCH_ARTICLES.map((a) => a.slug)
    expect(new Set(slugs).size).toBe(slugs.length)
    expect(slugs).toEqual(
      expect.arrayContaining(['detf', 'detf-types', 'bond-vs-mint', 'rate-providers']),
    )
    expect(slugs).not.toContain('preview-execution')
  })

  it('lists published articles including detf', () => {
    const published = listPublishedResearchArticles()
    expect(published.some((a) => a.slug === 'detf')).toBe(true)
    expect(published.some((a) => a.slug === 'detf-types')).toBe(true)
    expect(published.some((a) => a.slug === 'bond-vs-mint')).toBe(true)
    expect(published.every((a) => a.status === 'published' || a.status === 'draft')).toBe(true)
  })

  it('bond-vs-mint separates liquid mint from seigniorage bond path', () => {
    const article = getResearchArticle('bond-vs-mint')
    expect(article).toBeDefined()
    expect(article!.claims.some((c) => /free DETF ERC-20|Minting against the primary/i.test(c))).toBe(
      true,
    )
    expect(article!.claims.some((c) => /Bonding|bond position|rebasing claim/i.test(c))).toBe(true)
    expect(article!.notClaiming.some((c) => /guaranteed|APY/i.test(c))).toBe(true)
  })

  it('detf-types covers the five composition families in plain language', () => {
    const article = getResearchArticle('detf-types')
    expect(article).toBeDefined()
    expect(article!.claims.some((c) => /five DETF composition types/i.test(c))).toBe(true)
    expect(
      article!.sections.some((s) => s.heading != null && /Single Standard Exchange/i.test(s.heading)),
    ).toBe(true)
    expect(
      article!.sections.some((s) => s.heading != null && /Single Vault DETF/i.test(s.heading)),
    ).toBe(true)
    expect(
      article!.sections.some((s) => s.heading != null && /Multi-vault weighted/i.test(s.heading)),
    ).toBe(true)
    expect(
      article!.sections.some((s) => s.heading != null && /Multi-vault stable \(composed\)/i.test(s.heading)),
    ).toBe(true)
    expect(article!.sections.some((s) => s.heading != null && /Mixed-buffer/i.test(s.heading))).toBe(
      true,
    )
    expect(
      article!.sections.some(
        (s) =>
          s.heading != null &&
          /composed/i.test(s.heading) &&
          s.paragraphs.some((p) => /same SE vault shares|two intermediate/i.test(p)),
      ),
    ).toBe(true)
    expect(article!.notClaiming.some((c) => /Protocol DETF/i.test(c))).toBe(true)
  })

  it('detf article documents Policy vs Open (narrative spine)', () => {
    const detf = getResearchArticle('detf')
    expect(detf).toBeDefined()
    expect(detf!.claims.some((c) => /Policy/i.test(c) && /Open/i.test(c))).toBe(true)
    expect(
      detf!.claims.some((c) => /no price restrictions/i.test(c) || /Open mode has no price/i.test(c)),
    ).toBe(true)
    expect(detf!.notClaiming.some((c) => /Open removes price gates/i.test(c))).toBe(true)
    expect(detf!.sections.some((s) => s.heading != null && /Policy vs Open/i.test(s.heading))).toBe(
      true,
    )
  })

  it('resolves each registered slug', () => {
    for (const slug of getResearchSlugs()) {
      const article = getResearchArticle(slug)
      expect(article).toBeDefined()
      expect(article?.title.length).toBeGreaterThan(0)
      expect(article?.sections.length).toBeGreaterThan(0)
      expect(article?.notClaiming.length).toBeGreaterThan(0)
    }
  })

  it('returns undefined for unknown slug', () => {
    expect(getResearchArticle('not-a-real-slug')).toBeUndefined()
  })
})
