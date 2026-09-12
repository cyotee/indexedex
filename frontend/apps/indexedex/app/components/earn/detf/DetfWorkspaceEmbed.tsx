'use client'

/**
 * Earn-detail DETF mint/bond/sell workspace for a single lab DETF address.
 * Reuses StakingPageClient handlers in embedMode (no debug panel, no Protocol DETF chrome).
 * Does not deep-link lab DETFs to /staking — that page is fee Protocol DETF only.
 */

import { Card } from '../../ui/Card'
import StakingPageClient from '../../../staking/StakingPageClient'

export type DetfWorkspaceEmbedProps = {
  detfAddress: `0x${string}`
  /** Product symbol (primary display) */
  symbol?: string
}

export function DetfWorkspaceEmbed({ detfAddress, symbol }: DetfWorkspaceEmbedProps) {
  return (
    <div className="space-y-4" data-testid="detf-workspace-embed">
      <Card padding="sm">
        <p className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">
          {symbol || 'DETF'} workspace
        </p>
        <p className="text-xs text-[var(--text-muted,#9aa3b2)] mt-0.5">
          Mint, bond, and sell for this DETF on this page. The Protocol DETF fee product lives on{' '}
          <span className="font-mono">/staking</span> only.
        </p>
      </Card>
      <StakingPageClient embedMode fixedDetf={detfAddress} />
    </div>
  )
}

export default DetfWorkspaceEmbed
