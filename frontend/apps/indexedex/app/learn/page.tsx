import Link from 'next/link'

import { listPublishedResearchArticles } from '../content/research'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'

import '../landing.css'

export const metadata = {
  title: 'Learn — IndexedEx',
  description: 'How DETFs work, in short chapters. No invented APYs.',
}

const CHAPTERS = [
  {
    n: '01',
    slug: 'detf',
    title: 'What a DETF is',
    blurb: 'One token for a basket. The basket works in other apps.',
  },
  {
    n: '02',
    slug: 'detf-types',
    title: 'Pick a basket shape',
    blurb: 'Four types. Bond, mint, and burn stay the same.',
  },
  {
    n: '03',
    slug: 'bond-vs-mint',
    title: 'Mint or bond',
    blurb: 'Tokens you can move now, or the cheaper maker seat.',
  },
  {
    n: '04',
    slug: 'rate-providers',
    title: 'How the price stays honest',
    blurb: 'Keep vault-share prices current, or let traders catch up.',
  },
  {
    n: '05',
    slug: 'uniswap-v4-markets',
    title: 'The market under the token',
    blurb: 'Real Uniswap V4 pools people can trade.',
  },
] as const

export default function LearnPage() {
  const notes = listPublishedResearchArticles()
  const bySlug = new Map(notes.map((n) => [n.slug, n]))

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <div className="landing-lab__content space-y-12">
        <section>
          <p className="landing-lab__eyebrow">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1 mt-4">
            How it works.
            <br />
            <span className="landing-lab__h1-accent">One walk.</span>
          </h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            Five short chapters. Read them in order, or jump in. No invented APYs.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/create">
              <Button size="lg" className="landing-lab__cta-primary">
                Create DETF
              </Button>
            </Link>
            <Link href="/explore">
              <Button size="lg" variant="secondary">
                Use a live DETF
              </Button>
            </Link>
          </div>
        </section>

        <section>
          <p className="landing-section-label">Chapters</p>
          <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
            Start here, then go deeper.
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {CHAPTERS.map((ch) => {
              const note = bySlug.get(ch.slug)
              return (
                <Link key={ch.slug} href={`/research/${ch.slug}`} className="group block h-full">
                  <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
                    <p className="landing-step__n">{ch.n}</p>
                    <h3 className="mt-2 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">
                      {ch.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                      {ch.blurb}
                    </p>
                    {note ? (
                      <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)] line-clamp-2">
                        {note.summary}
                      </p>
                    ) : null}
                    <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">Read chapter →</p>
                  </Card>
                </Link>
              )
            })}
          </div>
        </section>

        <p className="pb-4 text-xs text-[var(--text-muted,#9aa3b2)]">
          Old /research links still work. They open the same chapters.
        </p>
      </div>
    </div>
  )
}
