'use client'

import Link from 'next/link'
import { useMemo } from 'react'
import { useAccount, useConnect } from 'wagmi'

import { Button } from './components/ui/Button'
import { Card } from './components/ui/Card'
import { Stat } from './components/ui/Stat'
import { ProductTypeBadge } from './components/earn/ProductTypeBadge'
import { loadEarnProductsForChain, loadFeaturedEarnProducts } from './lib/earn/loadEarnProducts'
import { useSelectedNetwork } from './lib/networkSelection'
import { useDeploymentEnvironment } from './lib/deploymentEnvironment'
import { getLaunchTokenAddress } from './lib/lab'
import { useBrand } from './lib/brandContext'

export default function HomePage() {
  const { brand } = useBrand()
  const { isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const catalog = useMemo(
    () => loadEarnProductsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const featured = useMemo(
    () => loadFeaturedEarnProducts(selectedChainId, environment),
    [selectedChainId, environment],
  )

  const launchToken = getLaunchTokenAddress()
  const buyHref = launchToken
    ? `/swap?launch=1&tokenOut=${launchToken}`
    : '/token'

  const preferredConnector = connectors[0]

  return (
    <div>
      {/* Hero */}
      <section className="text-center pt-6 pb-10 max-w-3xl mx-auto">
        <p className="text-xs uppercase tracking-widest text-[var(--text-muted,#9aa3b2)] mb-3">
          Composed indexed liquidity
        </p>
        <h1 className="text-4xl md:text-5xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
          Index-style strategies. Deposit once.
        </h1>
        <p className="mt-4 text-base md:text-lg text-[var(--text-muted,#9aa3b2)]">
          {brand.name} routes liquidity across vaults and DETFs so you can earn without
          hand-managing every pool.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          {isConnected ? (
            <Link href="/earn">
              <Button size="lg">Go to Earn</Button>
            </Link>
          ) : (
            <Button
              size="lg"
              onClick={() => {
                if (preferredConnector) void connect({ connector: preferredConnector })
              }}
            >
              Connect & Earn
            </Button>
          )}
          <Link href={buyHref}>
            <Button size="lg" variant="secondary">
              Get $TOKEN
            </Button>
          </Link>
        </div>
      </section>

      {/* Live strip */}
      <section className="mb-10">
        <Card className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Stat label="Products listed" value={String(catalog.length)} />
          <Stat
            label="Strategy vaults"
            value={String(catalog.filter((p) => p.productType === 'strategy').length)}
          />
          <Stat
            label="DETFs"
            value={String(catalog.filter((p) => p.productType !== 'strategy').length)}
          />
          <Stat label="Network" value={selectedChainId === 84532 ? 'Base Sepolia' : 'Sepolia'} />
        </Card>
      </section>

      {/* Featured */}
      <section className="mb-12">
        <h2 className="text-lg font-medium text-[var(--text-primary,#EDEDED)] mb-4">
          Featured strategies
        </h2>
        {featured.length === 0 ? (
          <Card>
            <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
              No products on this network yet. Switch chain or check deployment environment.
            </p>
            <Link href="/earn" className="inline-block mt-3">
              <Button variant="secondary" size="sm">
                Browse Earn
              </Button>
            </Link>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {featured.map((p) => (
              <Link key={p.address} href={`/earn/${p.address}`} className="block group">
                <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
                  <ProductTypeBadge type={p.productType} />
                  <h3 className="mt-3 text-base font-semibold text-[var(--text-primary,#EDEDED)]">
                    {p.display || p.name || p.symbol}
                  </h3>
                  <p className="mt-1 font-mono text-xs text-[var(--text-muted,#9aa3b2)]">
                    {p.symbol}
                  </p>
                  <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">View & deposit →</p>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>

      {/* How it works */}
      <section className="mb-12">
        <h2 className="text-lg font-medium text-[var(--text-primary,#EDEDED)] mb-4">How it works</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[
            { n: '01', t: 'Deposit', d: 'Choose a strategy vault or DETF and deposit assets in one flow.' },
            { n: '02', t: 'Protocol routes', d: 'Standard Exchange and DETF logic allocate liquidity across venues.' },
            { n: '03', t: 'Earn & bond', d: 'Hold shares, bond positions as NFTs, or redeem when terms allow.' },
          ].map((s) => (
            <Card key={s.n}>
              <div className="font-mono text-xs text-[var(--accent,#4FD44B)]">{s.n}</div>
              <h3 className="mt-2 font-medium text-[var(--text-primary,#EDEDED)]">{s.t}</h3>
              <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">{s.d}</p>
            </Card>
          ))}
        </div>
      </section>

      {/* Trust */}
      <section className="mb-10">
        <Card className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h2 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">Built for proof</h2>
            <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
              Contracts are list-driven and on-chain. Audits and docs link from the footer when available.
            </p>
          </div>
          <Link href="/earn">
            <Button>Start earning</Button>
          </Link>
        </Card>
      </section>

      {/* Culture closer */}
      <section className="pb-6">
        <Card className="font-mono text-xs text-[var(--text-muted,#9aa3b2)] leading-relaxed">
          <div className="opacity-70">{brand.manifestoLabel}</div>
          <div className="mt-2 text-[var(--text-primary,#EDEDED)]">
            the index is empty until you fill it.
            <br />
            deposit. route. employ the bags.
          </div>
        </Card>
      </section>
    </div>
  )
}
