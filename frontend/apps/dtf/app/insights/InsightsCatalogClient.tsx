'use client'

import Link from 'next/link'
import { useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { insightsDetfHref, parseInsightsDetfQuery } from './lib/insightsHref'
import { useInsightDetfCatalog } from './lib/useInsightDetfCatalog'

export default function InsightsCatalogClient() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { detfs, registryLoading, registryError } = useInsightDetfCatalog()

  useEffect(() => {
    const detf = parseInsightsDetfQuery(searchParams.get('detf'))
    if (!detf) return
    router.replace(insightsDetfHref(detf, searchParams.get('tab')))
  }, [router, searchParams])

  return (
    <div className="space-y-8">
      <section>
        <p className="text-xs font-mono uppercase tracking-[0.14em] text-[var(--accent,#4FD44B)]">
          DETF means Decentralized ETF
        </p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)] md:text-4xl">
          DETFs
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-[var(--text-muted,#9aa3b2)]">
          Open a DETF by its token address. Mint, burn, bond, or stake on that page.
        </p>
      </section>

      {detfs.length === 0 && !registryLoading ? (
        <Card>
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
            {registryError
              ? 'Could not read DETFs from the vault registry on this network.'
              : 'No DETF is on the vault registry for this network yet.'}
          </p>
          {registryError ? (
            <p className="mt-2 text-xs text-[var(--danger,#E6386A)]">{registryError}</p>
          ) : null}
          <div className="mt-4">
            <Link href="/create">
              <Button>Create DETF</Button>
            </Link>
          </div>
        </Card>
      ) : (
        <Card>
          <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
            Vault registry
          </p>
          <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
            {registryLoading ? 'Reading DETFs from the vault registry…' : 'All DETFs reported by the vault registry.'}
          </p>
          {registryError ? (
            <p className="mt-2 text-xs text-[var(--danger,#E6386A)]">{registryError}</p>
          ) : null}
          <ul className="mt-4 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]" data-testid="insights-detf-list">
            {detfs.map((d) => (
              <li key={d.address}>
                <Link
                  href={insightsDetfHref(d.address)}
                  className="flex flex-wrap items-baseline justify-between gap-2 py-3 hover:text-[var(--accent,#4FD44B)]"
                >
                  <span className="text-sm text-[var(--text-primary,#EDEDED)]">
                    {d.symbol} · {d.name}
                    {d.protocolFee ? (
                      <span className="ml-2 text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
                        Protocol fees
                      </span>
                    ) : null}
                  </span>
                  <span className="font-mono text-[11px] text-[var(--text-muted,#9aa3b2)]">{d.address}</span>
                </Link>
              </li>
            ))}
          </ul>
          <div className="mt-4">
            <Link href="/create">
              <Button size="sm" variant="secondary">
                Create DETF
              </Button>
            </Link>
          </div>
        </Card>
      )}
    </div>
  )
}
