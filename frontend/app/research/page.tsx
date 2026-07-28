import type { Metadata } from 'next'
import Link from 'next/link'

import { listPublishedResearchArticles } from '../content/research'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { PageHeader } from '../components/ui/PageHeader'

export const metadata: Metadata = {
  title: 'Research — IndexedEx',
  description:
    'Measured claims and product education: DETF pattern, DETF types, bond vs mint, rate integrity, and Protocol DETF.',
}

function formatDate(iso: string): string {
  const d = new Date(`${iso}T00:00:00.000Z`)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  })
}

export default function ResearchIndexPage() {
  const articles = listPublishedResearchArticles()
  const detf = articles.find((a) => a.slug === 'detf')

  return (
    <div>
      <PageHeader
        title="Research"
        subtitle="Measured claims. Product education. No invented APYs."
        actions={
          <Link href="/staking">
            <Button size="sm" variant="secondary">
              Open Protocol DETF
            </Button>
          </Link>
        }
      />

      <Card className="mb-8 border-[var(--border-accent,rgba(79,212,75,0.25))]">
        <p className="text-xs uppercase tracking-widest text-[var(--accent,#4FD44B)]">Premier product</p>
        <h2 className="mt-2 text-lg font-medium text-[var(--text-primary,#EDEDED)]">
          Create your own DETFs
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          DETF means Decentralized ETF — the D is decentralized. One onchain share over a real
          multi-asset reserve. IndexedEx ships many package types so you can compose that design —
          bond into protocol-owned depth; Policy price-gates mint/burn, or Open with no price
          restrictions. Protocol DETF is how you earn a share of protocol fees. Not a registered
          securities ETF.
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          {detf ? (
            <Link href={`/research/${detf.slug}`}>
              <Button size="sm">What is a DETF?</Button>
            </Link>
          ) : null}
          <Link href="/staking">
            <Button size="sm" variant="secondary">
              Open Protocol DETF
            </Button>
          </Link>
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
        {articles.map((article) => (
          <Link key={article.slug} href={`/research/${article.slug}`} className="group block h-full">
            <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
                <time dateTime={article.date}>{formatDate(article.date)}</time>
              </p>
              <h2 className="mt-2 text-base font-semibold text-[var(--text-primary,#EDEDED)] group-hover:text-[var(--accent,#4FD44B)]">
                {article.title}
              </h2>
              <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] line-clamp-4">{article.summary}</p>
              <div className="mt-4 flex flex-wrap gap-1.5">
                {article.tags.map((tag) => (
                  <span
                    key={tag}
                    className="rounded-full border border-[var(--border-subtle,rgba(255,255,255,0.08))] px-2 py-0.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]"
                  >
                    {tag}
                  </span>
                ))}
              </div>
              <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">Read note →</p>
            </Card>
          </Link>
        ))}
      </div>

      <p className="mt-10 text-xs text-[var(--text-muted,#9aa3b2)]">
        Canonical hermetic/fork matrices live in the monorepo <code className="font-mono">research/</code>{' '}
        tree. This section publishes claim-safe notes only.
      </p>
    </div>
  )
}
