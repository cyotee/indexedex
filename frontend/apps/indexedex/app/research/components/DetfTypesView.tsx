import Link from 'next/link'

import type { ResearchArticle, ResearchSection } from '../../content/research'
import { Button } from '../../components/ui/Button'
import { Card } from '../../components/ui/Card'
import { DetfCompositionDiagram } from './diagrams/DetfCompositionDiagram'

import '../../landing.css'

function sectionByHeading(article: ResearchArticle, heading: string): ResearchSection | undefined {
  return article.sections.find((s) => s.heading === heading)
}

function BoldLead({ text }: { text: string }) {
  const parts = text.split(/\*\*/)
  if (parts.length < 3) return <LinkedCopy text={text} />
  return (
    <>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <strong key={i} className="font-medium text-[var(--text-primary,#EDEDED)]">
            {part}
          </strong>
        ) : (
          <LinkedCopy key={i} text={part} />
        ),
      )}
    </>
  )
}

function ResearchHref({ children, href }: { children: string; href: string }) {
  return (
    <Link href={href} className="text-[var(--accent,#4FD44B)] hover:underline">
      {children}
    </Link>
  )
}

function LinkedCopy({ text }: { text: string }) {
  const parts = text.split(/(\/[a-z0-9][a-z0-9\-/?#]*)/gi)
  return (
    <>
      {parts.map((part, i) =>
        part.startsWith('/') ? (
          <ResearchHref key={`${part}-${i}`} href={part}>
            {part}
          </ResearchHref>
        ) : (
          <span key={`${part.slice(0, 16)}-${i}`}>{part}</span>
        ),
      )}
    </>
  )
}

function TypeCard({
  kicker,
  section,
  featured,
}: {
  kicker: string
  section: ResearchSection
  featured?: boolean
}) {
  return (
    <div className={featured ? 'landing-feature-hero h-full rounded-xl p-6' : undefined}>
      {featured ? (
        <TypeCardBody kicker={kicker} section={section} />
      ) : (
        <Card className="h-full">
          <TypeCardBody kicker={kicker} section={section} />
        </Card>
      )}
    </div>
  )
}

function TypeCardBody({ kicker, section }: { kicker: string; section: ResearchSection }) {
  return (
    <>
      <p className="landing-section-label">{kicker}</p>
      <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">{section.heading}</h2>
      {section.paragraphs.map((p) => (
        <p key={p.slice(0, 40)} className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          <LinkedCopy text={p} />
        </p>
      ))}
      {section.bullets ? (
        <ul className="mt-4 list-disc space-y-2 pl-5 text-sm text-[var(--text-muted,#9aa3b2)]">
          {section.bullets.map((b) => (
            <li key={b}>
              <BoldLead text={b} />
            </li>
          ))}
        </ul>
      ) : null}
    </>
  )
}

export function DetfTypesView({ article }: { article: ResearchArticle }) {
  const intro = sectionByHeading(article, 'Start with the basket')
  const same = sectionByHeading(article, 'What stays the same')
  const basket = sectionByHeading(article, 'What sits in the basket')
  const oneVault = sectionByHeading(article, 'One vault')
  const weighted = sectionByHeading(article, 'Several vaults, fixed weights')
  const grouped = sectionByHeading(article, 'Several similar vaults, grouped')
  const cash = sectionByHeading(article, 'One cash token plus vaults')
  const choose = sectionByHeading(article, 'How to choose')
  const faq = sectionByHeading(article, 'FAQ')

  const types = [
    { kicker: 'Simplest', section: oneVault, featured: true },
    { kicker: 'Fixed mix', section: weighted, featured: false },
    { kicker: 'Like-kind', section: grouped, featured: false },
    { kicker: 'Cash family', section: cash, featured: false },
  ].filter((t): t is { kicker: string; section: ResearchSection; featured: boolean } => Boolean(t.section))

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
            href="/research"
            className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
          >
            Research
          </Link>
          <p className="landing-lab__eyebrow mt-5">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1 mt-4">
            Pick the
            <br />
            <span className="landing-lab__h1-accent">basket shape.</span>
          </h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            {article.summary}
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/create">
              <Button size="lg" className="landing-lab__cta-primary">
                Create DETF
              </Button>
            </Link>
            <Link href="/research/detf">
              <Button size="lg" variant="secondary">
                How DETFs work
              </Button>
            </Link>
            <Link href="/research/bond-vs-mint">
              <Button size="lg" variant="ghost">
                Mint or bond
              </Button>
            </Link>
          </div>
        </section>

        {intro ? (
          <section>
            <p className="landing-section-label">Start here</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              {intro.heading}
            </h2>
            {intro.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
          </section>
        ) : null}

        {same ? (
          <section>
            <p className="landing-section-label">Every type</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              {same.heading}
            </h2>
            {same.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
            {same.bullets ? (
              <div className="mt-5 grid grid-cols-1 md:grid-cols-2 gap-3">
                {same.bullets.map((b, i) => (
                  <div
                    key={b}
                    className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-5"
                  >
                    <div className="landing-step__n">{String(i + 1).padStart(2, '0')}</div>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">{b}</p>
                  </div>
                ))}
              </div>
            ) : null}
          </section>
        ) : null}

        {basket ? (
          <section className="landing-lab__panel p-6 md:p-8">
            <p className="landing-section-label">Building blocks</p>
            <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
              {basket.heading}
            </h2>
            {basket.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                <LinkedCopy text={p} />
              </p>
            ))}
          </section>
        ) : null}

        {types.length === 4 ? (
          <section>
            <p className="landing-section-label">The four types</p>
            <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              Match the type to the basket.
            </h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {types.map((t) => (
                <TypeCard key={t.section.heading} kicker={t.kicker} section={t.section} featured={t.featured} />
              ))}
            </div>
          </section>
        ) : null}

        {types.some((t) => t.section.diagram) ? (
          <section>
            <p className="landing-section-label">How they look</p>
            <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              The reserve for each type.
            </h2>
            <div className="space-y-8">
              {types.map((t) =>
                t.section.diagram ? (
                  <div key={`diagram-${t.section.heading}`}>
                    <p className="mb-2 text-sm font-medium text-[var(--text-primary,#EDEDED)]">
                      {t.section.heading}
                    </p>
                    <DetfCompositionDiagram id={t.section.diagram} />
                  </div>
                ) : null,
              )}
            </div>
          </section>
        ) : null}

        {choose?.bullets ? (
          <section>
            <p className="landing-section-label">Decide</p>
            <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              How to choose
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {choose.bullets.map((b, i) => (
                <div
                  key={b}
                  className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-5"
                >
                  <div className="landing-step__n">{String(i + 1).padStart(2, '0')}</div>
                  <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                    <LinkedCopy text={b} />
                  </p>
                </div>
              ))}
            </div>
          </section>
        ) : null}

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
                      <BoldLead text={b} />
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
            <Link href="/earn">
              <Button variant="ghost">Browse vaults</Button>
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
