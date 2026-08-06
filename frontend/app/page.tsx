'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'

import { Button } from './components/ui/Button'
import { Card } from './components/ui/Card'
import { listPublishedResearchArticles } from './content/research'
import { loadEarnProductsForChain, loadFeaturedFeeDetfs } from './lib/earn/loadEarnProducts'
import { feeDetfStakingHref } from './lib/tokenlists'
import { useSelectedNetwork } from './lib/networkSelection'
import { useDeploymentEnvironment } from './lib/deploymentEnvironment'
import { useBrand } from './lib/brandContext'

import './landing.css'

const PROOF_CHIPS = [
  { k: 'offer', v: 'many DETF types' },
  { k: 'state', v: 'inert → live' },
  { k: 'pricing', v: 'pool-priced' },
  { k: 'mode', v: 'policy | open' },
] as const

const BENEFITS = [
  {
    featured: true,
    t: 'Your DETF, your design',
    d: 'Stand up reserve-backed shares from a family of package types — single vault, multi-vault weighted, mixed-buffer stable, composed shapes, and more. One platform; many DETF designs.',
    tag: 'platform',
  },
  {
    featured: false,
    t: 'One share, one basket',
    d: 'One ERC-20 over configured reserve legs. ETF-shaped intent without a discretionary rebalancer.',
    tag: 'share',
  },
  {
    featured: false,
    t: 'Priced by the pool',
    d: 'Synthetic valuation comes from the reserve AMM — balances, weights, rates — not a private dashboard ledger.',
    tag: 'pricing',
  },
  {
    featured: false,
    t: 'Policy or Open',
    d: 'Policy restricts primary mint/burn by synthetic price. Open has no price restrictions — you can mint and burn regardless of synthetic price. Fees may still apply.',
    tag: 'modes',
  },
  {
    featured: false,
    t: 'Immutable after deploy',
    d: 'No instance owner and no admin rebalance in normal operation. Flawed config means ship a new package — not patch a live one.',
    tag: 'constraints',
  },
] as const

const HOW_IT_WORKS = [
  {
    n: '01',
    t: 'Bond',
    d: 'Establish liveness and protocol-owned depth. Bond terms come from onchain configuration.',
  },
  {
    n: '02',
    t: 'Mint / burn',
    d: 'Exchange vault shares for DETF on the primary market. Policy only allows mint/burn outside the price deadband. Open never blocks mint or burn by price.',
  },
  {
    n: '03',
    t: 'Hold or claim',
    d: 'Hold the share, trade when markets exist, or use bond/claim paths when the instance wires them.',
  },
] as const

const DISCLAIMERS = [
  'A DETF is a decentralized ETF product pattern onchain — not a registered securities ETF or fund share.',
  'Built by the original developer of Olympus — not OlympusDAO, not the OHM token, not a claim on any DAO treasury.',
  'Holding DETF or reserve assets is not legal ownership of offchain stocks or other underlyings.',
  'Policy price thresholds (and choosing Open) do not guarantee peg stability, liquidity, or returns.',
  'There is no promised APY, rebase yield, or “(3,3)” performance.',
  'Smart-contract and market risk apply. Read research; this is not financial advice.',
] as const

type BandMode = 'policy' | 'open'

function ReserveCore() {
  return (
    <div className="landing-reserve" aria-hidden="true">
      <span className="landing-reserve__leg" />
      <span className="landing-reserve__leg" />
      <span className="landing-reserve__leg" />
      <span className="landing-reserve__leg" />
      <div className="landing-reserve__ring landing-reserve__ring--outer" />
      <div className="landing-reserve__ring landing-reserve__ring--mid" />
      <div className="landing-reserve__ring landing-reserve__ring--inner" />
      <div className="landing-reserve__core">
        <div className="landing-reserve__core-label">share token</div>
        <div className="landing-reserve__core-title">DETF</div>
        <div className="landing-reserve__core-state">inert → live</div>
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
          <p className="landing-section-label">Mint / burn modes</p>
          <h2 className="mt-2 text-xl md:text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
            Policy gates by price. Open does not.
          </h2>
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] max-w-xl">
            Toggle the deploy-time mode.{' '}
            <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Policy</strong> only
            allows primary mint/burn outside a synthetic price deadband (defaults often ±5%).{' '}
            <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Open</strong> has no
            price restrictions — mint and burn stay available regardless of synthetic price. Fees
            may still apply. Neither mode is a peg or return guarantee.
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
        <div className="landing-band__zone landing-band__zone--dead">deadband</div>
        <div className="landing-band__zone landing-band__zone--mint">mint</div>
        <div className="landing-band__zone landing-band__zone--open">mint &amp; burn · no price gate</div>
      </div>
      <div className="landing-band__labels">
        {mode === 'policy' ? (
          <>
            <span>burn only if synth &lt; 0.95</span>
            <span>blocked near peg</span>
            <span>mint only if synth &gt; 1.05</span>
          </>
        ) : (
          <>
            <span>no price floor</span>
            <span>mint &amp; burn by price: always on</span>
            <span>no price ceiling</span>
          </>
        )}
      </div>

      <p className="mt-4 font-mono text-[11px] leading-relaxed text-[var(--text-muted,#9aa3b2)]">
        <span className="text-[var(--text-primary,#EDEDED)]">THRESHOLD_MODE=</span>
        {mode === 'policy' ? 'POLICY' : 'OPEN'}
        <span className="mx-2 opacity-40">·</span>
        <span className="text-[var(--text-primary,#EDEDED)]">PRICE_GATES=</span>
        {mode === 'policy' ? 'on' : 'off'}
        <span className="mx-2 opacity-40">·</span>
        Open is explicit at deploy — not “zero thresholds”
      </p>
    </div>
  )
}

export default function HomePage() {
  const { brand } = useBrand()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const catalog = useMemo(
    () => loadEarnProductsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const featuredFeeDetfs = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 3),
    [selectedChainId, environment],
  )
  const heroFee = featuredFeeDetfs[0]
  const secondaryFees = featuredFeeDetfs.slice(1)

  const researchNotes = useMemo(() => listPublishedResearchArticles().slice(0, 3), [])

  const strategyCount = catalog.filter((p) => p.productType === 'strategy').length
  const primaryStakingHref = heroFee ? feeDetfStakingHref(heroFee.address) : '/staking'
  const networkLabel = selectedChainId === 84532 ? 'Base Sepolia' : 'Sepolia'
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
              DETF = Decentralized ETF · original developer of Olympus
            </p>
            <h1 className="landing-lab__h1 mt-4">
              Olympus made the meme.
              <br />
              <span className="landing-lab__h1-accent">DETFs make the product.</span>
            </h1>
            <p className="mt-5 max-w-xl text-base md:text-lg text-[var(--text-muted,#9aa3b2)] leading-relaxed">
              <strong className="font-medium text-[var(--text-primary,#EDEDED)]">DETF</strong> means{' '}
              <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Decentralized ETF</strong>
              — the D is decentralized. Built by the original developer of Olympus: reserve-backed
              units, bonding into shared depth, mint and burn with clear rules — productized, not a
              fork cosplay. One onchain share over a real reserve. Premier path: create your own DETFs.
              Want protocol fees? Open{' '}
              <strong className="font-medium text-[var(--text-primary,#EDEDED)]">Protocol DETF</strong>.
            </p>

            <div className="mt-6 flex flex-wrap gap-2">
              {PROOF_CHIPS.map((c) => (
                <span key={c.k} className="landing-lab__chip">
                  <span className="opacity-60">{c.k}</span>
                  <strong>{c.v}</strong>
                </span>
              ))}
            </div>

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
              <Link href="/research/uniswap-v4-markets">
                <Button size="lg" variant="secondary">
                  Uni V4 markets
                </Button>
              </Link>
              <Link href={primaryStakingHref}>
                <Button size="lg" variant="secondary">
                  {heroFee ? `Protocol fees · ${heroFee.symbol}` : 'Open Protocol DETF'}
                </Button>
              </Link>
              <Link href="/earn">
                <Button size="lg" variant="ghost">
                  Browse strategy vaults
                </Button>
              </Link>
            </div>

            <p className="mt-6 font-mono text-[11px] text-[var(--text-muted,#9aa3b2)]">
              net={networkLabel}
              <span className="mx-2 opacity-40">·</span>
              products={catalog.length}
              <span className="mx-2 opacity-40">·</span>
              vaults={strategyCount}
              <span className="mx-2 opacity-40">·</span>
              protocol_detfs={featuredFeeDetfs.length}
            </p>
          </div>

          <div className="lg:col-span-5">
            <div className="landing-lab__panel p-6 md:p-8">
              <div className="landing-terminal-bar -mx-6 md:-mx-8 -mt-6 md:-mt-8 mb-6 px-4">
                <span>{'// reserve_core.preview'}</span>
                <span className="text-[var(--accent,#4FD44B)]">status=sim</span>
              </div>
              <ReserveCore />
              <p className="mt-6 text-center text-xs text-[var(--text-muted,#9aa3b2)] leading-relaxed">
                Share at the center. Reserve legs on the ring. Policy blocks mint/burn near peg;
                Open never does — primary mint and burn stay free of price gates.
              </p>
              <div className="mt-5 flex justify-center">
                <Link href="/earn">
                  <Button size="sm" variant="secondary">
                    Browse strategy vaults
                  </Button>
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Why / benefits */}
      <section className="mb-16 md:mb-20">
        <p className="landing-section-label">Why DETFs</p>
        <h2 className="mt-2 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          Types you can compose. Rules you can inspect.
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          Not a single black-box fund. A platform of DETF packages with explicit lifecycle, optional
          price gates, and hard post-deploy constraints.
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
        <p className="landing-section-label">User path</p>
        <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          How it works
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
          Earn a claim on protocol fees through a live DETF. Mint or burn against the reserve, bond for
          onchain terms, sell to the protocol when ready, redeem via claim when wired. Fees may apply;
          amounts are not guarantees.
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
                <div className="landing-terminal-bar">
                  <span>{'// protocol_detf'}</span>
                  <span className="text-[var(--accent,#4FD44B)]">live</span>
                </div>
                <div className="p-5 md:p-6 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
                  <div>
                    <p className="text-[10px] uppercase tracking-widest text-[var(--accent,#4FD44B)]">
                      Fee share
                    </p>
                    {/* Product brand is Protocol DETF — not the deploy package name from lists. */}
                    <h3 className="mt-2 text-2xl font-semibold text-[var(--text-primary,#EDEDED)]">
                      Protocol DETF
                    </h3>
                    <p className="mt-1 font-mono text-xs text-[var(--text-muted,#9aa3b2)]">
                      {heroFee.symbol}
                      <span className="mx-2 opacity-40">·</span>
                      share token
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
                      <p className="mt-1 font-mono text-xs text-[var(--text-muted,#9aa3b2)]">
                        share token
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
              <p className="landing-section-label">Research</p>
              <h2 className="mt-2 text-xl md:text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
                Measured claims. Clear mechanics.
              </h2>
            </div>
            <Link
              href="/research"
              className="text-sm font-mono text-[var(--accent,#4FD44B)] hover:underline shrink-0"
            >
              All research →
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
              Strategy vaults
            </h2>
            <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)] max-w-xl">
              Standard Exchange vaults and composed liquidity live on Earn — often the legs a DETF
              reserve sits on. Mint, bond, and sell for Protocol DETF live on the Protocol DETF page,
              not the Earn grid.
            </p>
          </div>
          <Link href="/earn">
            <Button variant="secondary">Browse Earn</Button>
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
        <div className="rounded-xl border border-dashed border-[var(--border-subtle,rgba(255,255,255,0.12))] bg-transparent px-4 py-4 font-mono text-[11px] leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          <div className="text-[var(--accent,#4FD44B)] opacity-90">{'// product_law'}</div>
          <div className="mt-2 text-[var(--text-primary,#EDEDED)]">
            DETF = Decentralized ETF. many types. deploy inert. bond to go live.
            <br />
            protocol DETF for protocol fees. measure first; claim only what the chain can prove.
          </div>
        </div>
      </section>
    </div>
  )
}
