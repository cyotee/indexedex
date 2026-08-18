'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'

import { Button } from './components/ui/Button'
import { Card } from './components/ui/Card'
import { listPublishedResearchArticles } from './content/research'
import { loadFeaturedFeeDetfs } from './lib/earn/loadEarnProducts'
import { feeDetfStakingHref } from '@indexedex/protocol/tokenlists'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useBrand } from './lib/brandContext'

import './landing.css'

const BENEFITS = [
  {
    featured: true,
    t: 'The basket works in other apps',
    d: 'Your DETF is not a list of idle tokens. The basket puts money to work in other apps. That is the main difference. You make a DETF to run that plan as one token.',
    tag: 'plan',
  },
  {
    featured: false,
    t: 'One token for the whole basket',
    d: 'Hold, move, or sell one token. You do not have to manage each app yourself.',
    tag: 'simpler',
  },
  {
    featured: false,
    t: 'People can trade the token',
    d: 'The DETF token sits in a market. That market is how the assets behind it stay useful. It is not a side listing.',
    tag: 'market',
  },
  {
    featured: false,
    t: 'You pick the rules',
    d: 'Policy can pause mint and burn when the price is near the target. Open never does. Fees can still apply.',
    tag: 'rules',
  },
  {
    featured: false,
    t: 'The rules stay put',
    d: 'After it goes live, nobody rewrites the rules. A bad setup means a new DETF.',
    tag: 'trust',
  },
] as const

const HOW_IT_WORKS = [
  {
    n: '01',
    t: 'Create',
    d: 'Make a DETF. You get a bond you cannot cash out. It can collect a cut of new DETF. The DETF stays off until someone bonds.',
  },
  {
    n: '02',
    t: 'Bond',
    d: 'Bond means lock money in. That first bond turns the DETF on and fills the assets behind it.',
  },
  {
    n: '03',
    t: 'Use',
    d: 'Hold the token. Mint more. Or burn to exit. People can still trade the token.',
  },
] as const

const DISCLAIMERS = [
  'A DETF is a decentralized ETF onchain. It is not a stock ETF or a fund share.',
  'Holding DETF is not legal ownership of stocks or other offchain assets.',
  'Policy and Open do not promise a stable price, easy trades, or a return.',
  'There is no promised APY or guaranteed return.',
  'Smart contracts and markets can lose money. Read research. This is not financial advice.',
] as const

type BandMode = 'policy' | 'open'

function AcrossDefiDiagram() {
  return (
    <div
      className="landing-across"
      role="img"
      aria-label="One DETF basket at work across DeFi: trade pools, lending, staking, and vaults."
    >
      <svg className="landing-across__wires" viewBox="0 0 320 320" aria-hidden="true">
        <line x1="160" y1="160" x2="160" y2="52" />
        <line x1="160" y1="160" x2="268" y2="160" />
        <line x1="160" y1="160" x2="160" y2="268" />
        <line x1="160" y1="160" x2="52" y2="160" />
      </svg>
      <div className="landing-across__hub">
        <span className="landing-across__kicker">You hold</span>
        <strong className="landing-across__title">DETF token</strong>
        <span className="landing-across__sub">one basket</span>
      </div>
      <div className="landing-across__node landing-across__node--n">
        <span>Trade</span>
        <small>pools</small>
      </div>
      <div className="landing-across__node landing-across__node--e">
        <span>Lend</span>
        <small>books</small>
      </div>
      <div className="landing-across__node landing-across__node--s">
        <span>Vaults</span>
        <small>receipts</small>
      </div>
      <div className="landing-across__node landing-across__node--w">
        <span>Stake</span>
        <small>locks</small>
      </div>
    </div>
  )
}

function PolicyBandExperiment() {
  const [mode, setMode] = useState<BandMode>('policy')

  return (
    <div className="landing-bleed">
      <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4 mb-5">
        <div>
          <p className="landing-section-label">Mint and burn</p>
          <h2 className="mt-2 text-xl md:text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
            Choose when people can enter and exit
          </h2>
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] max-w-xl">
            Every DETF picks a mode when you make it.{' '}
            <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Policy</strong> can
            pause mint and burn when the price is near the target.{' '}
            <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Open</strong> never
            pauses for price. Fees can still apply. Neither mode promises a stable price or a
            return.
          </p>
        </div>
        <div className="landing-mode-toggle" role="group" aria-label="Threshold mode preview">
          <button
            type="button"
            data-active={mode === 'policy'}
            onClick={() => setMode('policy')}
          >
            Policy
          </button>
          <button type="button" data-active={mode === 'open'} onClick={() => setMode('open')}>
            Open
          </button>
        </div>
      </div>

      <div className="landing-band" data-mode={mode}>
        <div className="landing-band__zone landing-band__zone--burn">burn</div>
        <div className="landing-band__zone landing-band__zone--dead">near target</div>
        <div className="landing-band__zone landing-band__zone--mint">mint</div>
        <div className="landing-band__zone landing-band__zone--open">mint and burn stay open</div>
      </div>
      <div className="landing-band__labels">
        {mode === 'policy' ? (
          <>
            <span>burn when price is low</span>
            <span>paused near target</span>
            <span>mint when price is high</span>
          </>
        ) : (
          <>
            <span>mint stays open</span>
            <span>no pause for price</span>
            <span>burn stays open</span>
          </>
        )}
      </div>

      <p className="mt-4 text-xs leading-relaxed text-[var(--text-muted,#9aa3b2)]">
        You choose Policy or Open when you create the DETF.{' '}
        <Link href="/research/detf" className="text-[var(--accent,#4FD44B)] hover:underline">
          Read how DETFs work
        </Link>
      </p>
    </div>
  )
}

export default function HomePage() {
  const { brand } = useBrand()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const featuredFeeDetfs = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 3),
    [selectedChainId, environment],
  )
  const heroFee = featuredFeeDetfs[0]
  const secondaryFees = featuredFeeDetfs.slice(1)

  const researchNotes = useMemo(() => listPublishedResearchArticles().slice(0, 3), [])

  const featuredBenefit = BENEFITS.find((b) => b.featured)!
  const otherBenefits = BENEFITS.filter((b) => !b.featured)

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      {/* Above the fold */}
      <section className="relative pb-14 pt-2 md:pt-4 md:pb-20">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-8 items-center">
          <div className="lg:col-span-7">
            <p className="landing-lab__eyebrow">
              DETF means Decentralized ETF
            </p>
            <h1 className="landing-lab__h1 mt-4">
              Run your plan
              <br />
              <span className="landing-lab__h1-accent">as one token.</span>
            </h1>
            <p className="mt-5 max-w-xl text-base md:text-lg text-[var(--text-muted,#9aa3b2)] leading-relaxed">
              A DETF is one token for a basket you pick. That basket puts money to work in other
              apps. People can trade the token. That market is how the assets behind it stay
              useful. This is not a stock ETF. Want a cut of app fees instead? Open{' '}
              <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Protocol DETF</strong>.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/create">
                <Button size="lg" className="landing-lab__cta-primary">
                  Create DETF
                </Button>
              </Link>
              <Link href="/explore">
                <Button size="lg" variant="secondary">
                  {heroFee ? `Open ${heroFee.symbol}` : 'Explore DETFs'}
                </Button>
              </Link>
              <Link href="/learn">
                <Button size="lg" variant="ghost">
                  How DETFs work
                </Button>
              </Link>
            </div>
          </div>

          <div className="lg:col-span-5">
            <div className="landing-lab__panel p-6 md:p-8">
              <AcrossDefiDiagram />
              <p className="mt-6 text-center text-xs text-[var(--text-muted,#9aa3b2)] leading-relaxed">
                One basket at work across DeFi. You hold one token. The basket puts money to work
                in other apps.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Why / benefits */}
      <section className="mb-16 md:mb-20">
        <p className="landing-section-label">Why DETFs</p>
        <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          A plan you can hold as one token.
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          IndexedEx lets you run a money plan as a DETF. One token. One basket. The basket works
          in other apps. You own a piece of the assets behind that token.
        </p>

        <div className="mt-6 grid grid-cols-1 lg:grid-cols-12 gap-4">
          <div className="lg:col-span-5 landing-feature-hero rounded-xl p-6 md:p-7">
            <p className="font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--accent,#4FD44B)]">
              {featuredBenefit.tag} · primary
            </p>
            <h3 className="mt-3 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
              {featuredBenefit.t}
            </h3>
            <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
              {featuredBenefit.d}
            </p>
          </div>
          <div className="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-3">
            {otherBenefits.map((b) => (
              <Card key={b.t} className="h-full" padding="sm">
                <div className="p-1">
                  <p className="font-mono text-[10px] uppercase tracking-[0.14em] text-[var(--text-muted,#9aa3b2)]">
                    {b.tag}
                  </p>
                  <h3 className="mt-2 font-medium text-[var(--text-primary,#EDEDED)]">{b.t}</h3>
                  <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] leading-relaxed">
                    {b.d}
                  </p>
                </div>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* How it works — timeline */}
      <section className="mb-16 md:mb-20">
        <p className="landing-section-label">The process</p>
        <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          Three steps
        </h2>
        <div className="landing-steps">
          {HOW_IT_WORKS.map((s) => (
            <div key={s.n} className="landing-step">
              <div className="landing-step__rail" aria-hidden="true" />
              <div className="landing-step__n relative z-[1]">{s.n}</div>
              <h3 className="relative z-[1] mt-2 text-lg font-medium text-[var(--text-primary,#EDEDED)]">
                {s.t}
              </h3>
              <p className="relative z-[1] mt-2 text-sm text-[var(--text-muted,#9aa3b2)] leading-relaxed">
                {s.d}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* Policy / Open modes */}
      <section id="modes" className="mb-16 md:mb-20 scroll-mt-24">
        <PolicyBandExperiment />
      </section>

      {/* Protocol DETF — protocol fees path (Wave 2 — e2e: heading + staking links) */}
      <section className="mb-16 md:mb-20">
        <p className="landing-section-label">Share of protocol fees</p>
        <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          Protocol DETF
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          Same DETF design. Use it to take a cut of app fees. Mint, bond, or leave when you are
          ready. Fees may apply. Amounts are not promises.
        </p>

        {featuredFeeDetfs.length === 0 ? (
          <Card className="mt-5">
            <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
              No Protocol DETF configured on this network.
            </p>
            <Link href="/staking" className="inline-block mt-3">
              <Button variant="secondary" size="sm">
                Open Protocol DETF
              </Button>
            </Link>
          </Card>
        ) : (
          <div className="mt-5 space-y-3">
            {heroFee ? (
              <Link
                href={feeDetfStakingHref(heroFee.address)}
                className="landing-feature-hero block group overflow-hidden rounded-xl transition-shadow"
              >
                <div className="p-5 md:p-6 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
                  <div>
                    <p className="text-[10px] uppercase tracking-widest text-[var(--accent,#4FD44B)]">
                      Fee share
                    </p>
                    {/* Product brand is Protocol DETF — not the deploy package name from lists. */}
                    <h3 className="mt-2 text-2xl font-semibold text-[var(--text-primary,#EDEDED)]">
                      Protocol DETF
                    </h3>
                    <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                      {heroFee.symbol}
                    </p>
                  </div>
                  <span className="inline-flex items-center text-sm font-medium text-[var(--accent,#4FD44B)]">
                    Open {heroFee.symbol} →
                  </span>
                </div>
              </Link>
            ) : null}

            {secondaryFees.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {secondaryFees.map((p) => (
                  <Link
                    key={p.address}
                    href={feeDetfStakingHref(p.address)}
                    className="block group"
                  >
                    <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
                      <p className="text-[10px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">
                        Protocol DETF
                      </p>
                      <h3 className="mt-2 text-base font-semibold text-[var(--text-primary,#EDEDED)]">
                        {p.symbol}
                      </h3>
                      <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                        Protocol DETF token
                      </p>
                      <p className="mt-3 text-sm text-[var(--accent,#4FD44B)]">Open {p.symbol} →</p>
                    </Card>
                  </Link>
                ))}
              </div>
            ) : null}

            {heroFee ? (
              <div className="pt-1">
                <Link href={feeDetfStakingHref(heroFee.address)}>
                  <Button size="sm">Open {heroFee.symbol}</Button>
                </Link>
              </div>
            ) : null}
          </div>
        )}
      </section>

      {/* Research */}
      <section className="mb-16 md:mb-20">
        <div className="landing-lab-notes">
          <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-5">
            <div>
              <p className="landing-section-label">Learn</p>
              <h2 className="mt-2 text-xl md:text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
                How DETFs work
              </h2>
            </div>
            <Link
              href="/learn"
              className="text-sm font-mono text-[var(--accent,#4FD44B)] hover:underline shrink-0"
            >
              Full walk →
            </Link>
          </div>

          {researchNotes.length === 0 ? (
            <p className="text-sm text-[var(--text-muted,#9aa3b2)]">No published notes yet.</p>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              {researchNotes.map((note, i) => (
                <Link key={note.slug} href={`/research/${note.slug}`} className="landing-lab-note">
                  <p className="font-mono text-[10px] text-[var(--text-muted,#9aa3b2)]">
                    {String(i + 1).padStart(2, '0')} · {note.slug}
                  </p>
                  <h3 className="mt-2 text-base font-semibold text-[var(--text-primary,#EDEDED)]">
                    {note.title}
                  </h3>
                  <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] line-clamp-3 leading-relaxed">
                    {note.summary}
                  </p>
                  <p className="mt-4 font-mono text-xs text-[var(--accent,#4FD44B)]">Read note →</p>
                </Link>
              ))}
            </div>
          )}
        </div>
      </section>

      {/* Secondary Earn */}
      <section className="mb-12">
        <Card className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-[var(--surface-2,#1c2030)]">
          <div>
            <p className="landing-section-label" style={{ color: 'var(--text-muted, #9aa3b2)' }}>
              Also on {brand.name}
            </p>
            <h2 className="mt-1 text-base font-medium text-[var(--text-primary,#EDEDED)]">
              Building-block vaults
            </h2>
            <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)] max-w-xl">
              Deposit into vaults a DETF can put in its basket. Those vaults are how the plan
              reaches other apps. Use a live DETF from Explore. Or pick vaults when you Create.
            </p>
          </div>
          <Link href="/earn">
            <Button variant="secondary">Browse vaults</Button>
          </Link>
        </Card>
      </section>

      {/* Disclaimers */}
      <section className="mb-10">
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
            {DISCLAIMERS.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </details>
      </section>

      {/* Closing strip */}
      <section className="pb-4">
        <div className="rounded-xl border border-dashed border-[var(--border-subtle,rgba(255,255,255,0.12))] bg-transparent px-4 py-4 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          DETF means Decentralized ETF. Run your plan as a basket that works in other apps. Open
          Protocol DETF for a cut of app fees. We only claim what the chain can prove.
        </div>
      </section>
    </div>
  )
}
