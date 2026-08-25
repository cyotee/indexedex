'use client'

import Image from 'next/image'
import Link from 'next/link'
import { useMemo } from 'react'

import { LandingWalkthrough } from './components/landing/LandingWalkthrough'
import { loadFeaturedFeeDetfs } from './lib/earn/loadEarnProducts'
import { getLaunchTokenAddress } from './lib/lab'
import { useBrand } from './lib/brandContext'
import { appPath } from './lib/siteOrigins'
import { displayTokenTicker } from './lib/customerSymbols'
import { feeDetfStakingHref, getBaseTokensForChain } from '@indexedex/protocol/tokenlists'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'

import './landing.css'

const STEPS = [
  {
    n: '01',
    k: 'Mint',
    t: 'Buy in with one token',
    d: 'Pick a basket. One transaction gets you the whole thing.',
  },
  {
    n: '02',
    k: 'Hold',
    t: 'It keeps working for you',
    d: 'Hold one token. The market manages the basket for you.',
  },
  {
    n: '03',
    k: 'Bond',
    t: 'Or lock in for more',
    d: 'Bond means lock money in. The first bond is what turns a new DETF on.',
  },
] as const

const FINE_PRINT = [
  { href: '/learn', t: 'A DETF is not a stock ETF or fund share' },
  { href: '/learn', t: 'No promised APY or guaranteed return' },
  { href: '/learn', t: 'Contracts and markets can lose money' },
] as const

export default function HomePage() {
  const { brand } = useBrand()
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
    return appPath(addr ? `/swap?launch=1&tokenOut=${addr}` : '/swap')
  }, [selectedChainId, environment])

  const protocolHref = appPath(heroFee ? feeDetfStakingHref(heroFee.address) : '/staking')

  return (
    <div className="dtf-landing">
      <div className="dtf-landing__grid" aria-hidden="true" />
      <div className="dtf-landing__glow" aria-hidden="true" />

      <header className="dtf-landing__nav">
        <Link href="/" className="dtf-landing__brand">
          <span className="dtf-landing__mark" aria-hidden="true" />
          <span>DTF</span>
        </Link>
        <nav className="dtf-landing__links" aria-label="Primary">
          <Link href={appPath('/explore')}>Explore</Link>
          <Link href={appPath('/create')}>Create</Link>
          <Link href={appPath('/learn')}>Learn</Link>
        </nav>
        <Link href={appPath('/explore')} className="dtf-landing__launch">
          Launch app
        </Link>
      </header>

      <main>
        <section className="dtf-landing__hero">
          <p className="dtf-landing__pill">A DETF is a Decentralized ETF</p>
          <h1 className="dtf-landing__h1">
            Your whole strategy,
            <br />
            <span className="dtf-landing__h1-accent">in a single token.</span>
          </h1>
          <p className="dtf-landing__lede">
            One token for any basket of assets you pick. Anyone can create a DETF. Mint it and
            hold the whole basket. It works with markets, tokenized stocks, and other apps.
          </p>
          <div className="dtf-landing__hero-cta">
            <Link href={appPath('/explore')} className="dtf-landing__btn dtf-landing__btn--primary">
              Join a live DETF
            </Link>
            <Link href={appPath('/create')} className="dtf-landing__btn dtf-landing__btn--ghost">
              Create a basket
            </Link>
          </div>
        </section>

        <section className="dtf-landing__visual" aria-label="One DETF token over a basket">
          <Image
            src="/images/detf-constellation.jpg"
            alt="One DETF token at the centre of a constellation of pools, vaults, and lending positions it holds"
            width={1200}
            height={608}
            priority
          />
        </section>

        <section className="dtf-landing__steps">
          {STEPS.map((s) => (
            <article key={s.n} className="dtf-landing__step">
              <p className="dtf-landing__kicker">
                {s.n} / {s.k}
              </p>
              <h2>{s.t}</h2>
              <p>{s.d}</p>
            </article>
          ))}
        </section>

        <section className="dtf-landing__try">
          <p className="dtf-landing__kicker">Try it</p>
          <h2>Walk through an example basket</h2>
          <p className="dtf-landing__section-lede">
            Pick a step. See what you do and what the basket does.
          </p>
          <LandingWalkthrough />
        </section>

        <section className="dtf-landing__live">
          <div className="dtf-landing__live-head">
            <div>
              <p className="dtf-landing__kicker">Already running</p>
              <h2>Join a live DETF</h2>
            </div>
            <Link href={appPath('/explore')} className="dtf-landing__text-link">
              Browse all baskets
            </Link>
          </div>

          <div className="dtf-landing__live-grid">
            <article className="dtf-landing__card">
              <div className="dtf-landing__card-top">
                <div>
                  <h3>{displayTokenTicker(heroFee?.symbol)}</h3>
                  <p className="dtf-landing__card-kicker">The protocol&apos;s own basket</p>
                </div>
                <span className="dtf-landing__live-badge">Live</span>
              </div>
              <ul>
                <li>
                  <i className="dot-mint" aria-hidden />
                  Earn a share of app fees
                </li>
                <li>
                  <i className="dot-purple" aria-hidden />
                  Same DETF design as any other basket
                </li>
                <li>
                  <i className="dot-gold" aria-hidden />
                  Amounts are not guaranteed
                </li>
              </ul>
              <Link href={protocolHref} className="dtf-landing__btn dtf-landing__btn--block">
                Open {displayTokenTicker(heroFee?.symbol)}
              </Link>
            </article>

            <article className="dtf-landing__card">
              <div className="dtf-landing__card-top">
                <div>
                  <h3>Example basket</h3>
                  <p className="dtf-landing__card-kicker">How a reserve is put together</p>
                </div>
                <span className="dtf-landing__count">
                  3<span>pools</span>
                </span>
              </div>
              <ul>
                <li>
                  <i className="dot-mint" aria-hidden />
                  Stable lending position
                  <em>Morpho</em>
                </li>
                <li>
                  <i className="dot-purple" aria-hidden />
                  ETH liquidity position
                  <em>Uniswap V4</em>
                </li>
                <li>
                  <i className="dot-gold" aria-hidden />
                  Stable / ETH pair
                  <em>Uniswap V4</em>
                </li>
              </ul>
              <Link href={appPath('/explore')} className="dtf-landing__btn dtf-landing__btn--block">
                See live baskets
              </Link>
            </article>
          </div>
        </section>
      </main>

      <footer className="dtf-landing__foot">
        <div className="dtf-landing__foot-grid">
          <div>
            <p className="dtf-landing__foot-title">You free tonight?</p>
            <p className="dtf-landing__h1-accent dtf-landing__foot-accent">
              We&apos;re Down To Finance.
            </p>
          </div>
          <div>
            <p className="dtf-landing__kicker">Protocol</p>
            <Link href={buyDtfHref}>Buy $DTF</Link>
            <Link href={appPath('/learn')}>How DETFs work</Link>
            <Link href={appPath('/create')}>Create a DETF</Link>
          </div>
          <div>
            <p className="dtf-landing__kicker">The fine print</p>
            {FINE_PRINT.map((line) => (
              <Link key={line.t} href={appPath(line.href)}>
                {line.t}
              </Link>
            ))}
          </div>
        </div>
        <div className="dtf-landing__legal">
          <p>
            {brand.name}. Onchain, non-custodial, long term. Not financial advice.
          </p>
          <p>App fees buy back $DTF</p>
        </div>
      </footer>
    </div>
  )
}
