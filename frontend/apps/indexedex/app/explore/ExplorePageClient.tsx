'use client'

import Link from 'next/link'
import { useMemo } from 'react'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { loadFeaturedFeeDetfs } from '../lib/earn/loadEarnProducts'
import { feeDetfStakingHref, getProtocolDetfsForChain } from '@indexedex/protocol/tokenlists'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'

import '../landing.css'

export default function ExplorePageClient() {
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const featured = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 6),
    [selectedChainId, environment],
  )
  const protocol = useMemo(
    () => getProtocolDetfsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )

  const hero = featured[0]
  const seen = new Set(featured.map((d) => d.address.toLowerCase()))
  const rest = [
    ...featured.slice(1),
    ...protocol.filter((d) => !seen.has(d.address.toLowerCase())),
  ]

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <div className="landing-lab__content space-y-12">
        <section>
          <p className="landing-lab__eyebrow">Use a DETF that is already live</p>
          <h1 className="landing-lab__h1 mt-4">
            Open one.
            <br />
            <span className="landing-lab__h1-accent">Mint, bond, or trade.</span>
          </h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            Protocol DETF is first. It uses the same design so you can take a cut of app fees.
            Amounts are not promises.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/create">
              <Button size="lg" className="landing-lab__cta-primary">
                Create DETF
              </Button>
            </Link>
            <Link href="/learn">
              <Button size="lg" variant="secondary">
                How DETFs work
              </Button>
            </Link>
          </div>
        </section>

        {hero ? (
          <section>
            <p className="landing-section-label">Cut of app fees</p>
            <Link
              href={feeDetfStakingHref(hero.address)}
              className="landing-feature-hero mt-4 block rounded-xl p-6 md:p-8 group"
            >
              <p className="text-[10px] uppercase tracking-widest text-[var(--accent,#4FD44B)]">
                Protocol DETF
              </p>
              <h2 className="mt-2 text-2xl font-semibold text-[var(--text-primary,#EDEDED)]">
                Protocol DETF
              </h2>
              <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">{hero.symbol}</p>
              <p className="mt-3 max-w-xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Mint, bond, or leave when you are ready. Fees may apply.
              </p>
              <p className="mt-5 text-sm font-medium text-[var(--accent,#4FD44B)]">
                Open {hero.symbol} →
              </p>
            </Link>
          </section>
        ) : (
          <Card>
            <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
              No live DETF is listed on this network yet.
            </p>
            <div className="mt-4">
              <Link href="/create">
                <Button size="sm">Create DETF</Button>
              </Link>
            </div>
          </Card>
        )}

        {rest.length > 0 ? (
          <section>
            <p className="landing-section-label">More live DETFs</p>
            <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
              Same steps. Different baskets.
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {rest.map((d) => (
                <Link key={d.address} href={feeDetfStakingHref(d.address)} className="group block h-full">
                  <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
                    <p className="text-[10px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">
                      DETF
                    </p>
                    <h3 className="mt-2 text-base font-semibold text-[var(--text-primary,#EDEDED)]">
                      {d.display || d.name || d.symbol}
                    </h3>
                    <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">{d.symbol}</p>
                    <p className="mt-3 text-sm text-[var(--accent,#4FD44B)]">Open {d.symbol} →</p>
                  </Card>
                </Link>
              ))}
            </div>
          </section>
        ) : null}

        <Card className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <p className="landing-section-label">Need a vault only?</p>
            <h2 className="mt-2 text-base font-medium text-[var(--text-primary,#EDEDED)]">
              Building-block vaults
            </h2>
            <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)] max-w-xl">
              Vaults are Lego for a DETF basket. They are not the plan itself.
            </p>
          </div>
          <Link href="/earn">
            <Button variant="secondary">Browse vaults</Button>
          </Link>
        </Card>
      </div>
    </div>
  )
}
