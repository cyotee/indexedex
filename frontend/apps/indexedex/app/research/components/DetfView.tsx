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

function leadAndRest(text: string): { lead: string | null; rest: string } {
  const match = text.match(/^\*\*(.+?)\*\*\s*(.*)$/s)
  if (!match) return { lead: null, rest: text }
  return { lead: match[1].replace(/:$/, ''), rest: match[2] }
}

function ResearchHref({ children, href }: { children: string; href: string }) {
  return (
    <Link href={href} className="text-[var(--accent,#4FD44B)] hover:underline">
      {children}
    </Link>
  )
}

/** Turns a path mention like `/research/bond-vs-mint` into a link. */
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

export function DetfView({ article }: { article: ResearchArticle }) {
  const intro = sectionByHeading(article, 'What a DETF is')
  const why = sectionByHeading(article, 'Why that matters')
  const steps = sectionByHeading(article, 'How you use it')
  const claim = sectionByHeading(article, 'What the token is a claim on')
  const rules = sectionByHeading(article, 'You pick the rules')
  const mintBond = sectionByHeading(article, 'Mint or bond')
  const createOrProtocol = sectionByHeading(article, 'Create your own or open Protocol DETF')
  const creatorBond = sectionByHeading(article, 'If you create a DETF')
  const faq = sectionByHeading(article, 'FAQ')

  const whyBullets = why?.bullets ?? []
  const featuredWhy = whyBullets[0]
  const otherWhy = whyBullets.slice(1)
  const featured = featuredWhy ? leadAndRest(featuredWhy) : null

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
            One token
            <br />
            <span className="landing-lab__h1-accent">over a basket.</span>
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

        {why && featured ? (
          <section>
            <p className="landing-section-label">Why DETFs</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              A strategy you can hold as one token.
            </h2>
            {why.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
            <div className="mt-6 grid grid-cols-1 lg:grid-cols-12 gap-4">
              <div className="lg:col-span-5 landing-feature-hero rounded-xl p-6 md:p-7">
                <p className="font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--accent,#4FD44B)]">
                  strategy · primary
                </p>
                <h3 className="mt-3 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                  {featured.lead}
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                  {featured.rest}
                </p>
              </div>
              <div className="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-3">
                {otherWhy.map((b) => {
                  const { lead, rest } = leadAndRest(b)
                  return (
                    <Card key={b} className="h-full" padding="sm">
                      <div className="p-1">
                        <h3 className="font-medium text-[var(--text-primary,#EDEDED)]">{lead ?? b}</h3>
                        {rest ? (
                          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] leading-relaxed">
                            {rest}
                          </p>
                        ) : null}
                      </div>
                    </Card>
                  )
                })}
              </div>
            </div>
          </section>
        ) : null}

        {steps?.bullets ? (
          <section>
            <p className="landing-section-label">The process</p>
            <h2 className="mt-2 mb-3 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              Three steps
            </h2>
            {steps.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mb-5 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
            <div className="landing-steps">
              {steps.bullets.map((b, i) => {
                const { lead, rest } = leadAndRest(b)
                return (
                  <div key={b} className="landing-step">
                    <div className="landing-step__rail" aria-hidden="true" />
                    <div className="landing-step__n relative z-[1]">{String(i + 1).padStart(2, '0')}</div>
                    <h3 className="relative z-[1] mt-2 text-lg font-medium text-[var(--text-primary,#EDEDED)]">
                      {lead ?? `Step ${i + 1}`}
                    </h3>
                    <p className="relative z-[1] mt-2 text-sm text-[var(--text-muted,#9aa3b2)] leading-relaxed">
                      {rest || b}
                    </p>
                  </div>
                )
              })}
            </div>
          </section>
        ) : null}

        {claim ? (
          <section className="landing-lab__panel p-6 md:p-8">
            <p className="landing-section-label">The token</p>
            <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
              {claim.heading}
            </h2>
            {claim.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                <LinkedCopy text={p} />
              </p>
            ))}
          </section>
        ) : null}

        {rules ? (
          <section>
            <p className="landing-section-label">Mint and burn</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              {rules.heading}
            </h2>
            {rules.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
            {rules.bullets ? (
              <div className="mt-5 grid grid-cols-1 md:grid-cols-2 gap-4">
                {rules.bullets.map((b, i) => {
                  const { lead, rest } = leadAndRest(b)
                  const featuredRule = lead === 'Policy'
                  return (
                    <div
                      key={b}
                      className={featuredRule ? 'landing-feature-hero h-full rounded-xl p-6' : undefined}
                    >
                      {featuredRule ? (
                        <>
                          <p className="landing-section-label">Default</p>
                          <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                            {lead}
                          </h3>
                          <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                            {rest}
                          </p>
                        </>
                      ) : (
                        <Card className="h-full">
                          <p className="landing-section-label">{i === 1 ? 'No price gate' : 'Mode'}</p>
                          <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                            {lead}
                          </h3>
                          <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                            {rest}
                          </p>
                        </Card>
                      )}
                    </div>
                  )
                })}
              </div>
            ) : null}
          </section>
        ) : null}

        {mintBond ? (
          <section>
            <p className="landing-section-label">The two paths</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              {mintBond.heading}
            </h2>
            {mintBond.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                <LinkedCopy text={p} />
              </p>
            ))}
            <div className="mt-5">
              <Link href="/research/bond-vs-mint">
                <Button variant="secondary">Mint or bond</Button>
              </Link>
            </div>
          </section>
        ) : null}

        {createOrProtocol ? (
          <section>
            <p className="landing-section-label">What to open</p>
            <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              {createOrProtocol.heading}
            </h2>
            <div className="mt-5 grid grid-cols-1 lg:grid-cols-2 gap-4">
              {createOrProtocol.paragraphs.map((p, i) => (
                <div
                  key={p.slice(0, 40)}
                  className={i === 0 ? 'landing-feature-hero h-full rounded-xl p-6' : undefined}
                >
                  {i === 0 ? (
                    <>
                      <p className="landing-section-label">The platform</p>
                      <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                        Create your own
                      </h3>
                      <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                        <LinkedCopy text={p} />
                      </p>
                    </>
                  ) : (
                    <Card className="h-full">
                      <p className="landing-section-label">Protocol fees</p>
                      <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                        Protocol DETF
                      </h3>
                      <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                        <LinkedCopy text={p} />
                      </p>
                    </Card>
                  )}
                </div>
              ))}
            </div>
          </section>
        ) : null}

        {creatorBond ? (
          <section className="landing-lab__panel p-6 md:p-8">
            <p className="landing-section-label">For creators</p>
            <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
              {creatorBond.heading}
            </h2>
            {creatorBond.paragraphs.map((p) => (
              <p
                key={p.slice(0, 40)}
                className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]"
              >
                {p}
              </p>
            ))}
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
            <Link href="/research/detf-types">
              <Button variant="ghost">DETF types</Button>
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
