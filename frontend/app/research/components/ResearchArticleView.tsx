import Link from 'next/link'

import type { ResearchArticle } from '../../content/research'
import { Button } from '../../components/ui/Button'
import { Card } from '../../components/ui/Card'
import { PageHeader } from '../../components/ui/PageHeader'
import { DetfCompositionDiagram } from './diagrams/DetfCompositionDiagram'

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

export function ResearchArticleView({ article }: { article: ResearchArticle }) {
  return (
    <article>
      <div className="mb-4">
        <Link
          href="/research"
          className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
        >
          ← Research
        </Link>
      </div>

      <PageHeader
        title={article.title}
        subtitle={article.summary}
        actions={
          article.relatedProductHref ? (
            <Link href={article.relatedProductHref}>
              <Button size="sm" variant="secondary">
                {article.relatedProductLabel ?? 'Open product'}
              </Button>
            </Link>
          ) : null
        }
      />

      <div className="mb-6 flex flex-wrap items-center gap-2 text-xs text-[var(--text-muted,#9aa3b2)]">
        <time dateTime={article.date}>{formatDate(article.date)}</time>
        <span aria-hidden="true">·</span>
        {article.tags.map((tag) => (
          <span
            key={tag}
            className="rounded-full border border-[var(--border-subtle,rgba(255,255,255,0.08))] px-2 py-0.5 font-mono text-[10px] uppercase tracking-wide"
          >
            {tag}
          </span>
        ))}
      </div>

      {article.claims.length > 0 ? (
        <Card className="mb-6">
          <p className="text-xs uppercase tracking-widest text-[var(--accent,#4FD44B)]">What this note shows</p>
          <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-[var(--text-primary,#EDEDED)]">
            {article.claims.map((c) => (
              <li key={c}>{c}</li>
            ))}
          </ul>
        </Card>
      ) : null}

      <div className="space-y-8">
        {article.sections.map((section, i) => (
          <section key={section.heading ?? `section-${i}`}>
            {section.heading ? (
              <h2 className="text-lg font-medium text-[var(--text-primary,#EDEDED)]">{section.heading}</h2>
            ) : null}
            {section.paragraphs.map((p) => (
              <p
                key={p.slice(0, 48)}
                className={`text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)] ${
                  section.heading || section.paragraphs[0] !== p ? 'mt-3' : 'mt-0'
                }`}
              >
                {p}
              </p>
            ))}
            {section.bullets && section.bullets.length > 0 ? (
              <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-[var(--text-muted,#9aa3b2)]">
                {section.bullets.map((b) => (
                  <li key={b}>{b}</li>
                ))}
              </ul>
            ) : null}
            {section.diagram ? <DetfCompositionDiagram id={section.diagram} /> : null}
          </section>
        ))}
      </div>

      {article.notClaiming.length > 0 ? (
        <Card className="mt-10 border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)]/60">
          <p className="text-xs uppercase tracking-widest text-[var(--text-muted,#9aa3b2)]">Not claiming</p>
          <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-[var(--text-muted,#9aa3b2)]">
            {article.notClaiming.map((c) => (
              <li key={c}>{c}</li>
            ))}
          </ul>
        </Card>
      ) : null}

      {article.relatedProductHref ? (
        <div className="mt-8">
          <Link href={article.relatedProductHref}>
            <Button>{article.relatedProductLabel ?? 'Continue'}</Button>
          </Link>
        </div>
      ) : null}

      <footer className="mt-10 space-y-2 border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] pt-6 text-xs text-[var(--text-muted,#9aa3b2)]">
        {article.sourceNote ? <p>Sources: {article.sourceNote}</p> : null}
        <p>
          Research notes are educational. Smart contracts and markets involve risk of loss. Not investment,
          legal, or tax advice.
        </p>
      </footer>
    </article>
  )
}

export default ResearchArticleView
