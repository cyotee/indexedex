import type { Metadata } from 'next'
import Link from 'next/link'

import { listPublishedResearchArticles } from '../content/research'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { PageHeader } from '../components/ui/PageHeader'

export const metadata: Metadata = {
  title: 'Research — IndexedEx',
  description:
    'How DETFs work: one token over a basket, create or join Protocol DETF, Policy vs Open, and related notes.',
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
        subtitle="How DETFs work, in plain language. No invented APYs."
        actions={
          <Link href="/staking">
            <Button size="sm" variant="secondary">
              Open Protocol DETF
            </Button>
          </Link>
        }
      />

      <Card className="mb-8 border-[var(--border-accent,rgba(79,212,75,0.25))]">
        <p className="text-xs uppercase tracking-widest text-[var(--accent,#4FD44B)]">Start here</p>
        <h2 className="mt-2 text-lg font-medium text-[var(--text-primary,#EDEDED)]">
          Deploy your own strategy as a DETF
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          A DETF (Decentralized ETF) is one token over a basket that manages assets in other
          protocols. That token is a claim on a share of the managed reserve. The token also sits
          in market liquidity so the reserve can be managed. Create it, bond to turn it on, then
          mint or burn. Want a share of protocol fees instead? Open Protocol DETF.
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          <Link href="/create">
            <Button size="sm">Create DETF</Button>
          </Link>
          {detf ? (
            <Link href={`/research/${detf.slug}`}>
              <Button size="sm" variant="secondary">
                How DETFs work
              </Button>
            </Link>
          ) : null}
          <a href="/research/DETF_LITEPAPAPER.pdf" download>
            <Button size="sm" variant="secondary">
              Download litepaper PDF
            </Button>
          </a>
          <Link href="/staking">
            <Button size="sm" variant="secondary">
              Open Protocol DETF
            </Button>
          </Link>
        </div>
      </Card>

      <Card className="mb-8">
        <p className="text-xs uppercase tracking-widest text-[var(--accent,#4FD44B)]">Litepaper</p>
        <h2 className="mt-2 text-lg font-medium text-[var(--text-primary,#EDEDED)]">
          DETF Litepaper — July 2026
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          Longer write-up of the process: off to live, Policy vs Open, and where rewards can come
          from. Not a prospectus and not a yield forecast.
        </p>
        <div className="mt-4">
          <a href="/research/DETF_LITEPAPAPER.pdf" download>
            <Button size="sm">Download PDF</Button>
          </a>
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
