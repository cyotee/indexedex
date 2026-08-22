import Link from 'next/link'

import type { ResearchArticle, ResearchSection } from '../../content/research'
import { Button } from '../../components/ui/Button'
import { Card } from '../../components/ui/Card'

import '../../landing.css'

function sectionByHeading(article: ResearchArticle, heading: string): ResearchSection | undefined {
  return article.sections.find((s) => s.heading === heading)
}

function BoldLead({ text }: { text: string }) {
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

function ChoiceCard({
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
        <>
          <p className="landing-section-label">{kicker}</p>
          <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
            {section.heading}
          </h2>
          {section.paragraphs.map((p) => (
            <p key={p.slice(0, 40)} className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
              {p}
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
      ) : (
        <Card className="h-full">
          <p className="landing-section-label">{kicker}</p>
          <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
            {section.heading}
          </h2>
          {section.paragraphs.map((p) => (
            <p key={p.slice(0, 40)} className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
              {p}
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
        </Card>
      )}
    </div>
  )
}

export function BondVsMintView({ article }: { article: ResearchArticle }) {
  const intro = sectionByHeading(article, 'Start with what you want')
  const mint = sectionByHeading(article, 'Why mint')
  const bond = sectionByHeading(article, 'Why bond')
  const shareMinted = sectionByHeading(article, 'Bond holders share DETF that gets minted')
  const gated = sectionByHeading(article, 'When mint and burn are price-gated')
  const choose = sectionByHeading(article, 'How to choose')
  const faq = sectionByHeading(article, 'FAQ')

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
          <p className="landing-lab__eyebrow mt-5">Mint or bond</p>
          <h1 className="landing-lab__h1 mt-4">
            Which position
            <br />
            <span className="landing-lab__h1-accent">do you want?</span>
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
            <Link href="/staking">
              <Button size="lg" variant="secondary">
                Open Protocol DETF
              </Button>
            </Link>
            <Link href="/research/detf">
              <Button size="lg" variant="ghost">
                How DETFs work
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
              <p key={p.slice(0, 40)} className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                {p}
              </p>
            ))}
          </section>
        ) : null}

        {mint && bond ? (
          <section>
            <p className="landing-section-label">The two paths</p>
            <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              Pick the outcome, then the action.
            </h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <ChoiceCard kicker="Tokens now" section={mint} />
              <ChoiceCard kicker="Maker seat" section={bond} featured />
            </div>
          </section>
        ) : null}

        {shareMinted ? (
          <section className="landing-lab__panel p-6 md:p-8">
            <p className="landing-section-label">Both modes</p>
            <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
              {shareMinted.heading}
            </h2>
            {shareMinted.paragraphs.map((p) => (
              <p key={p.slice(0, 40)} className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                {p}
              </p>
            ))}
          </section>
        ) : null}

        {gated ? (
          <section>
            <p className="landing-section-label">Price-gated or open</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              {gated.heading}
            </h2>
            {gated.paragraphs.map((p) => (
              <p key={p.slice(0, 40)} className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                {p}
              </p>
            ))}
            {gated.bullets ? (
              <div className="mt-5 grid grid-cols-1 md:grid-cols-2 gap-3">
                {gated.bullets.map((b) => (
                  <Card key={b} className="h-full">
                    <p className="text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                      <BoldLead text={b} />
                    </p>
                  </Card>
                ))}
              </div>
            ) : null}
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
                  <div key={b} className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-5">
                    <div className="landing-step__n">{String(i + 1).padStart(2, '0')}</div>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                      {b}
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
            <Link href="/staking">
              <Button variant="secondary">Open Protocol DETF</Button>
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
