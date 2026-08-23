'use client'

import Link from 'next/link'
import { useMemo } from 'react'

import { Button } from './components/ui/Button'
import { Card } from './components/ui/Card'
import { OrbitalMorphoUniv4ExampleDiagram } from './research/components/diagrams/DetfCompositionDiagram'
import { loadFeaturedFeeDetfs } from './lib/earn/loadEarnProducts'
import { getLaunchTokenAddress } from './lib/lab'
import { feeDetfStakingHref, getBaseTokensForChain } from '@indexedex/protocol/tokenlists'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'

import './landing.css'

const HOW_IT_WORKS = [
  {
    n: '01',
    t: 'Create',
    d: 'Make a DETF. You pick the rules. It stays off until the first bond.',
  },
  {
    n: '02',
    t: 'Bond',
    d: 'Bond means lock money in. That first bond turns the DETF on.',
  },
  {
    n: '03',
    t: 'Use',
    d: 'Hold the token. Mint more, burn to exit, or trade it.',
  },
] as const

const DISCLAIMERS = [
  'A DETF is a decentralized ETF onchain. It is not a stock ETF or a fund share.',
  'Holding DETF is not legal ownership of stocks or other offchain assets.',
  'Policy and Open do not promise a stable price, easy trades, or a return.',
  'There is no promised APY or guaranteed return.',
  'Fees used to buy back $DTF do not promise a higher price or a profit.',
  'Smart contracts and markets can lose money. Read research. This is not financial advice.',
] as const

function AcrossDefiDiagram() {
  return (
    <div
      className="landing-across"
      role="img"
      aria-label="One DETF token. The basket works in pools, lending, staking, and vaults."
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

export default function HomePage() {
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const featuredFeeDetfs = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 1),
    [selectedChainId, environment],
  )
  const heroFee = featuredFeeDetfs[0]

  const buyDtfHref = useMemo(() => {
    const launch = getLaunchTokenAddress()
    const dtf = getBaseTokensForChain(selectedChainId, environment).find((t) => {
      const symbol = t.symbol.toUpperCase()
      return symbol === 'DTF' || symbol === 'TTDTF' || symbol === 'TTRICH' || symbol === 'RICH'
    })
    const addr = dtf?.address ?? launch
    return addr ? `/swap?launch=1&tokenOut=${addr}` : '/token'
  }, [selectedChainId, environment])

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <section className="relative pb-14 pt-2 md:pt-4 md:pb-20">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-8 items-center">
          <div className="lg:col-span-7">
            <p className="landing-lab__eyebrow">
              DTF · Down To Finance · DETF means Decentralized ETF
            </p>
            <h1 className="landing-lab__h1 mt-4">
              You free tonight?
              <br />
              <span className="landing-lab__h1-accent">We&apos;re Down To Finance.</span>
            </h1>
            <p className="mt-5 max-w-xl text-base md:text-lg text-[var(--text-muted,#9aa3b2)] leading-relaxed">
              A DETF is one token for a basket you pick. The basket works in other apps. Create
              your own, or open one that is already live.
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
                You hold one token. The basket works in other apps.
              </p>
            </div>
          </div>
        </div>
      </section>

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

      <section id="example-basket" className="mb-16 md:mb-20 scroll-mt-24">
        <p className="landing-section-label">Example basket</p>
        <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          One token, many strategies
        </h2>

        <div className="mt-6">
          <OrbitalMorphoUniv4ExampleDiagram />
        </div>
      </section>

      <section id="dtf" className="mb-16 md:mb-20 scroll-mt-24">
        <p className="landing-section-label">App fees buy back $DTF</p>
        <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          Protocol DETF
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          <strong className="font-medium text-[var(--text-primary,#EDEDED)]">$DTF</strong> is the
          token for app fees. When people use Down To Finance, those fees go to buy back $DTF.
        </p>

        {heroFee ? (
          <div className="mt-5 space-y-3">
            <Link
              href={feeDetfStakingHref(heroFee.address)}
              className="landing-feature-hero block group overflow-hidden rounded-xl transition-shadow"
            >
              <div className="p-5 md:p-6 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
                <div>
                  <p className="text-[10px] uppercase tracking-widest text-[var(--accent,#4FD44B)]">
                    $DTF
                  </p>
                  <h3 className="mt-2 text-2xl font-semibold text-[var(--text-primary,#EDEDED)]">
                    Protocol DETF
                  </h3>
                  <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                    $DTF-DETF is the DETF of $DTF. Lock $DTF to earn fees with $DTF-DETF. $DTF-CLAIM
                    is the rebasing claim token.
                  </p>
                </div>
                <span className="inline-flex items-center text-sm font-medium text-[var(--accent,#4FD44B)]">
                  Open $DTF-DETF →
                </span>
              </div>
            </Link>

            <div className="pt-1 flex flex-wrap gap-2">
              <Link href={buyDtfHref}>
                <Button size="sm">Buy $DTF</Button>
              </Link>
              <Link href={feeDetfStakingHref(heroFee.address)}>
                <Button size="sm" variant="secondary">
                  Open $DTF-DETF
                </Button>
              </Link>
            </div>
          </div>
        ) : (
          <Card className="mt-5">
            <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
              No Protocol DETF is listed on this network yet. You can still buy $DTF when a market
              is set.
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <Link href={buyDtfHref}>
                <Button size="sm">Buy $DTF</Button>
              </Link>
              <Link href="/staking">
                <Button variant="secondary" size="sm">
                  Open Protocol DETF
                </Button>
              </Link>
            </div>
          </Card>
        )}
      </section>

      <section className="mb-16 md:mb-20">
        <div className="landing-lab-notes">
          <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
            <div>
              <p className="landing-section-label">Learn</p>
              <h2 className="mt-2 text-xl md:text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
                How DETFs work
              </h2>
              <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
                Five short chapters on how DETFs work.
              </p>
            </div>
            <Link
              href="/learn"
              className="text-sm font-mono text-[var(--accent,#4FD44B)] hover:underline shrink-0"
            >
              Full walk →
            </Link>
          </div>
        </div>
      </section>

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
    </div>
  )
}
