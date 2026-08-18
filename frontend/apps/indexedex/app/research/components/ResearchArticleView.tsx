import Link from 'next/link'

import type { ResearchArticle } from '../../content/research'
import { Button } from '../../components/ui/Button'
import { DetfCompositionDiagram } from './diagrams/DetfCompositionDiagram'
import { MermaidDiagram } from './MermaidDiagram'

import '../../landing.css'

function BulletText({ text }: { text: string }) {
  const parts = text.split(/\*\*/)
  if (parts.length < 3) return <>{text}</>
  return (
    <>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <strong key={i} className="font-medium text-[var(--text-primary,#EDEDED)]">
            {part}
          </strong>
        ) : (
          <span key={i}>{part}</span>
        ),
      )}
    </>
  )
}

export function ResearchArticleView({ article }: { article: ResearchArticle }) {
  const faq = article.sections.find((s) => s.heading === 'FAQ' || s.heading === 'Short FAQ')
  const body = article.sections.filter((s) => s !== faq)

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <div className="landing-lab__content space-y-16">
        <section>
          <Link
            href="/learn"
            className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
          >
            Learn
          </Link>
          <p className="landing-lab__eyebrow mt-5">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1 mt-4">{article.title}</h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            {article.summary}
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/create">
              <Button size="lg" className="landing-lab__cta-primary">
                Create DETF
              </Button>
            </Link>
            {article.relatedProductHref ? (
              <Link href={article.relatedProductHref}>
                <Button size="lg" variant="secondary">
                  {article.relatedProductLabel ?? 'How DETFs work'}
                </Button>
              </Link>
            ) : (
              <Link href="/research/detf">
                <Button size="lg" variant="secondary">
                  How DETFs work
                </Button>
              </Link>
            )}
          </div>
        </section>

        {body.map((section, i) => (
          <section key={section.heading ?? `section-${i}`}>
            {section.heading ? (
              <>
                <p className="landing-section-label">Note</p>
                <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
                  {section.heading}
                </h2>
              </>
            ) : null}
            {section.paragraphs.map((p) => (
              <p
                key={p.slice(0, 48)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
            {section.bullets && section.bullets.length > 0 ? (
              <ul className="mt-4 list-disc space-y-2 pl-5 text-sm text-[var(--text-muted,#9aa3b2)]">
                {section.bullets.map((b) => (
                  <li key={b}>
                    <BulletText text={b} />
                  </li>
                ))}
              </ul>
            ) : null}
            {section.diagram ? <DetfCompositionDiagram id={section.diagram} /> : null}
            {section.mermaid ? (
              <MermaidDiagram chart={section.mermaid} caption={section.mermaidCaption} />
            ) : null}
          </section>
        ))}

        {faq?.bullets ? (
          <section>
            <div className="landing-lab-notes">
              <p className="landing-section-label">FAQ</p>
              <h2 className="mt-2 mb-5 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                Quick answers
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {faq.bullets.map((b) => (
                  <div key={b} className="landing-lab-note">
                    <p className="text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                      <BulletText text={b} />
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </section>
        ) : null}

        {article.notClaiming.length > 0 ? (
          <details className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4 group">
            <summary className="cursor-pointer list-none flex items-center justify-between gap-3 text-sm font-medium text-[var(--text-primary,#EDEDED)]">
              Disclaimers
              <span className="font-mono text-[10px] text-[var(--text-muted,#9aa3b2)] group-open:hidden">
                expand
              </span>
              <span className="font-mono text-[10px] text-[var(--text-muted,#9aa3b2)] hidden group-open:inline">
                collapse
              </span>
            </summary>
            <ul className="mt-3 space-y-2 text-xs text-[var(--text-muted,#9aa3b2)] leading-relaxed list-disc pl-4">
              {article.notClaiming.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </details>
        ) : null}

        <section className="pb-4">
          <div className="flex flex-wrap gap-3">
            <Link href="/create">
              <Button>Create DETF</Button>
            </Link>
            <Link href="/research/detf">
              <Button variant="secondary">How DETFs work</Button>
            </Link>
          </div>
          <p className="mt-6 text-xs text-[var(--text-muted,#9aa3b2)]">
            Research notes are educational. Smart contracts and markets involve risk of loss. Not
            investment, legal, or tax advice.
          </p>
        </section>
      </div>
    </div>
  )
}

export default ResearchArticleView
