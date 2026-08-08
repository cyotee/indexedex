'use client'

/**
 * Earn-detail DETF mint/bond/sell embed (Wave 1 PR7).
 *
 * Mounted only when NEXT_PUBLIC_EARN_DETF_EMBED=true.
 * Reuses the same staking workspace handlers via full-page client with embed props.
 * Never mounts StakingDebugPanel.
 */

import Link from 'next/link'
import { useEffect } from 'react'

import { Button } from '../../ui/Button'
import { Card } from '../../ui/Card'
import StakingPageClient from '../../../staking/StakingPageClient'

export type DetfWorkspaceEmbedProps = {
  detfAddress: `0x${string}`
  /** Product symbol (primary display) */
  symbol?: string
}

/**
 * Embed surface: deep-link always available; mounts staking workspace body without debug.
 * Prefer setting ?detf= on URL so StakingPageClient picks up the address.
 */
export function DetfWorkspaceEmbed({ detfAddress, symbol }: DetfWorkspaceEmbedProps) {
  // Ensure deep-link query is present so staking client can preselect when it reads search params.
  useEffect(() => {
    if (typeof window === 'undefined') return
    const url = new URL(window.location.href)
    if (url.searchParams.get('detf')?.toLowerCase() !== detfAddress.toLowerCase()) {
      url.searchParams.set('detf', detfAddress)
      window.history.replaceState({}, '', `${url.pathname}${url.search}`)
    }
  }, [detfAddress])

  return (
    <div className="space-y-4" data-testid="detf-workspace-embed">
      <Card padding="sm">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <p className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">
              {symbol || 'DETF'} actions
            </p>
            <p className="text-xs text-[var(--text-muted,#9aa3b2)] mt-0.5">
              Mint, bond, and sell — same handlers as the DETF workspace (no debug panel).
            </p>
          </div>
          <Link href={`/staking?detf=${detfAddress}`}>
            <Button variant="secondary" size="sm">
              Open full workspace
            </Button>
          </Link>
        </div>
      </Card>
      {/* embedMode: hide debug, compact chrome */}
      <StakingPageClient embedMode fixedDetf={detfAddress} />
    </div>
  )
}

export default DetfWorkspaceEmbed
