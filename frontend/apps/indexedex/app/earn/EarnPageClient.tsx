'use client'

import Link from 'next/link'
import { Suspense, useMemo, useState, useEffect } from 'react'
import { useSearchParams } from 'next/navigation'

import { EarnFilters, type EarnTypeFilter } from '../components/earn/EarnFilters'
import { ProductTypeBadge } from '../components/earn/ProductTypeBadge'
import { RiskBadge } from '../components/earn/RiskBadge'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { EmptyState } from '../components/ui/EmptyState'
import { PageHeader } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { filterEarnProducts } from '../lib/earn/assembleEarnProducts'
import { loadEarnProductsForChain, loadFeaturedFeeDetfs } from '../lib/earn/loadEarnProducts'
import type { EarnProductType } from '@indexedex/protocol/earn/types'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useVaultRegistrySearch } from '../lib/hooks/useVaultRegistrySearch'
import {
  mapRegistryAddressesToRows,
  preferredToRows,
  type VaultSearchRow,
} from '@indexedex/protocol/registry/mapRegistryToRows'
import {
  feeDetfStakingHref,
  getBaseTokensForChain,
  isFeaturedFeeDetfAddress,
} from '@indexedex/protocol/tokenlists'

function parseTypeParam(raw: string | null): EarnTypeFilter {
  if (raw === 'strategy' || raw === 'detf' || raw === 'protocol-detf') return raw
  return 'all'
}

function SourceBadge({ source }: { source: VaultSearchRow['source'] }) {
  return source === 'preferred' ? (
    <Badge tone="accent">Preferred</Badge>
  ) : (
    <Badge tone="info">Registry</Badge>
  )
}

function TypeCell({ row }: { row: VaultSearchRow }) {
  if (row.productType === 'registry') {
    return <Badge tone="neutral">Registered</Badge>
  }
  return <ProductTypeBadge type={row.productType} />
}

function ResultsTable({ rows }: { rows: VaultSearchRow[] }) {
  return (
    <>
      <div className="hidden md:block overflow-x-auto rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))]">
        <table className="w-full text-left text-sm">
          <thead className="bg-[var(--surface-1,#14171f)] text-[var(--text-muted,#9aa3b2)] text-xs uppercase tracking-wide">
            <tr>
              <th className="px-4 py-3 font-medium">Product</th>
              <th className="px-4 py-3 font-medium">Source</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Risk</th>
              <th className="px-4 py-3 font-medium">Symbol</th>
              <th className="px-4 py-3 font-medium text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((p) => (
              <tr
                key={`${p.source}-${p.address}`}
                className="border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] hover:bg-white/[0.02]"
              >
                <td className="px-4 py-3 text-[var(--text-primary,#EDEDED)]">
                  {p.display || p.name}
                  <div className="font-mono text-[10px] text-[var(--text-muted,#9aa3b2)]">
                    {p.address.slice(0, 10)}…
                  </div>
                </td>
                <td className="px-4 py-3">
                  <SourceBadge source={p.source} />
                </td>
                <td className="px-4 py-3">
                  <TypeCell row={p} />
                </td>
                <td className="px-4 py-3">
                  <RiskBadge level={p.risk} />
                </td>
                <td className="px-4 py-3 font-mono text-[var(--text-muted,#9aa3b2)]">{p.symbol}</td>
                <td className="px-4 py-3 text-right">
                  <Link href={`/earn/${p.address}`}>
                    <Button size="sm" variant="secondary">
                      View
                    </Button>
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="md:hidden flex flex-col gap-3">
        {rows.map((p) => (
          <Link key={`${p.source}-${p.address}`} href={`/earn/${p.address}`}>
            <Card>
              <div className="flex items-start justify-between gap-2">
                <div>
                  <div className="flex flex-wrap gap-1">
                    <SourceBadge source={p.source} />
                    <TypeCell row={p} />
                    <RiskBadge level={p.risk} />
                  </div>
                  <h3 className="mt-2 font-medium text-[var(--text-primary,#EDEDED)]">
                    {p.display || p.name}
                  </h3>
                  <p className="font-mono text-xs text-[var(--text-muted,#9aa3b2)]">{p.symbol}</p>
                </div>
                <span className="text-xs text-[var(--accent,#4FD44B)]">View →</span>
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </>
  )
}

function EarnCatalogInner() {
  const searchParams = useSearchParams()
  const initialType = parseTypeParam(searchParams.get('type'))
  const [productType, setProductType] = useState<EarnTypeFilter>(initialType)
  const [search, setSearch] = useState(searchParams.get('q') ?? '')

  useEffect(() => {
    setProductType(parseTypeParam(searchParams.get('type')))
  }, [searchParams])

  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const preferredCatalog = useMemo(
    () => loadEarnProductsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const featuredFee = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 1)[0],
    [selectedChainId, environment],
  )
  const feePromoHref = featuredFee ? feeDetfStakingHref(featuredFee.address) : '/staking'

  // Symbol → address hints for registry queries (base tokens + preferred products).
  const knownTokens = useMemo(() => {
    const base = getBaseTokensForChain(selectedChainId, environment).map((t) => ({
      address: t.address,
      symbol: t.symbol,
      name: t.name,
      display: t.display,
    }))
    const fromPreferred = preferredCatalog.map((p) => ({
      address: p.address,
      symbol: p.symbol,
      name: p.name,
      display: p.display,
    }))
    return [...base, ...fromPreferred]
  }, [selectedChainId, environment, preferredCatalog])

  const registrySearch = useVaultRegistrySearch({
    chainId: selectedChainId,
    environment,
    query: search,
    knownTokens,
  })

  /**
   * Display rules:
   * - No user query → preferred tokenlist (filtered by product type chips).
   * - Text-only query (no registry hit) → filter preferred tokenlist by text.
   * - Address / known token → registry view results (merged with preferred metadata).
   */
  const rows: VaultSearchRow[] = useMemo(() => {
    const typeFilter = productType === 'all' ? undefined : (productType as EarnProductType)
    const dropFeeDetf = (list: VaultSearchRow[]) =>
      list.filter((r) => !isFeaturedFeeDetfAddress(selectedChainId, environment, r.address))

    if (!registrySearch.isRegistryMode) {
      // Preferred default or free-text filter on preferred list.
      const filtered = filterEarnProducts(preferredCatalog, {
        productType: typeFilter ?? 'all',
        search: registrySearch.parsed.mode === 'text' ? search : '',
      })
      // When mode is text, filterEarnProducts already applied search.
      // When empty, product type filter only.
      if (registrySearch.parsed.mode === 'empty') {
        return dropFeeDetf(
          preferredToRows(
            filterEarnProducts(preferredCatalog, { productType: typeFilter ?? 'all' }),
          ),
        )
      }
      return dropFeeDetf(preferredToRows(filtered))
    }

    // Registry mode: live view results (still exclude Protocol DETF addresses).
    let regRows = mapRegistryAddressesToRows(
      registrySearch.registryAddresses,
      selectedChainId,
      preferredCatalog,
    )
    if (typeFilter) {
      regRows = regRows.filter(
        (r) => r.productType === typeFilter || r.productType === 'registry',
      )
    }
    return dropFeeDetf(regRows)
  }, [
    registrySearch.isRegistryMode,
    registrySearch.parsed.mode,
    registrySearch.registryAddresses,
    preferredCatalog,
    productType,
    search,
    selectedChainId,
    environment,
  ])

  const statusLine = useMemo(() => {
    if (!search.trim()) {
      return 'Showing preferred products from tokenlists. Enter a token address or symbol to query the Vault Registry.'
    }
    if (registrySearch.isRegistryMode) {
      if (registrySearch.isLoading) return 'Querying Vault Registry…'
      if (registrySearch.error) return `Registry: ${registrySearch.error}`
      if (registrySearch.parsed.mode === 'known-token') {
        return `Registry: vaults containing ${registrySearch.parsed.label}`
      }
      if (registrySearch.parsed.mode === 'address') {
        return `Registry: vaultsOfToken + isVault for ${registrySearch.parsed.address.slice(0, 10)}…`
      }
      return `Registry query (${registrySearch.primarySpec.kind})`
    }
    return 'Filtering preferred tokenlist by text (no registry match for this entry).'
  }, [search, registrySearch])

  return (
    <div>
      <PageHeader
        title="Earn"
        subtitle="Vaults a DETF can put in its basket. Protocol DETF has its own page."
      />

      {!search.trim() ? (
        <Card accent className="mb-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <p className="text-xs uppercase tracking-wide text-[var(--accent,#4FD44B)]">
              Protocol DETF
            </p>
            <p className="text-sm text-[var(--text-primary,#EDEDED)] mt-1">
              {featuredFee
                ? `${featuredFee.symbol} lives on the Protocol DETF page (mint, bond, sell), not in this vault list.`
                : 'Protocol DETFs live on their own page for mint, bond, and sell, not in this vault list.'}
            </p>
          </div>
          <Link href={feePromoHref}>
            <Button size="sm">
              {featuredFee ? `Open ${featuredFee.symbol}` : 'Open Protocol DETF'}
            </Button>
          </Link>
        </Card>
      ) : null}

      <EarnFilters
        productType={productType}
        search={search}
        onProductTypeChange={setProductType}
        onSearchChange={setSearch}
      />

      <p className="mb-4 text-xs text-[var(--text-muted,#9aa3b2)]">
        {statusLine}
        {registrySearch.registry ? (
          <span className="ml-2 font-mono opacity-70">
            registry {registrySearch.registry.slice(0, 8)}…
          </span>
        ) : null}
      </p>

      {registrySearch.isLoading ? (
        <Card>
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">Loading registry results…</p>
        </Card>
      ) : rows.length === 0 ? (
        <EmptyState
          title={registrySearch.isRegistryMode ? 'No vaults from registry' : 'No preferred products'}
          body={
            registrySearch.isRegistryMode
              ? 'No vaults matched this token/address on the Vault Registry for this chain. Clear search to see preferred products.'
              : 'Switch network, clear search, or check that tokenlists are populated for this environment.'
          }
          action={
            search.trim() ? (
              <Button variant="secondary" size="sm" onClick={() => setSearch('')}>
                Clear search
              </Button>
            ) : (
              <Link href="/">
                <Button variant="secondary" size="sm">
                  Back home
                </Button>
              </Link>
            )
          }
        />
      ) : (
        <ResultsTable rows={rows} />
      )}
    </div>
  )
}

export default function EarnPageClient() {
  return (
    <Suspense
      fallback={
        <div className="text-sm text-[var(--text-muted,#9aa3b2)] py-10">Loading Earn catalog…</div>
      }
    >
      <EarnCatalogInner />
    </Suspense>
  )
}
