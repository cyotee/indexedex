'use client'

import Image from 'next/image'
import { AddressLink } from '../ui/AddressLink'
import { Button } from '../ui/Button'
import { Card } from '../ui/Card'
import { formatBondAmount } from '../../lib/portfolio/formatBondAmount'
import { fundedBondClaimAvailability, fundedBondRole } from '../../lib/detf/fundedBondPresentation'
import type { BondNftMetadata } from '../../lib/portfolio/types'

export type BondNftCardProps = {
  kind: 'protocol'
  symbol: string
  tokenId: bigint
  chainId: number
  nftVault: `0x${string}`
  claimToken?: `0x${string}`
  vestingEndLabel: string
  principal?: bigint
  claimedPrincipal?: bigint
  principalDue?: bigint
  pendingRewards?: bigint
  actionKeyPending: string | null
  claimKey: string
  redeemKey: string
  isWritePending?: boolean
  metadata?: BondNftMetadata
  onLoadCertificate?: () => void
  onClaim?: () => void
  onRedeem?: () => void
}

/** Amounts come from the funded NFT's current position and claim views. */
export function BondNftCard({
  symbol, tokenId, chainId, nftVault, claimToken, vestingEndLabel,
  principal, claimedPrincipal, principalDue, pendingRewards,
  actionKeyPending, claimKey, redeemKey, isWritePending = false,
  metadata, onLoadCertificate, onClaim, onRedeem,
}: BondNftCardProps) {
  const role = fundedBondRole(tokenId)
  const available = fundedBondClaimAvailability({
    tokenId, principalDue, rewardsDue: pendingRewards, pending: isWritePending || actionKeyPending != null,
  })
  const amounts = [
    ['Purchased principal', principal, 'DETF'],
    ['Principal claimed', claimedPrincipal, 'sDETF'],
    ['Principal available', principalDue, 'sDETF'],
    ['Staking rewards available', pendingRewards, 'sDETF'],
  ] as const

  return (
    <Card data-testid="bond-nft-card" className="space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="font-semibold text-[var(--text-primary,#EDEDED)]">
            {symbol} · {role ?? 'Bond'} #{tokenId.toString()}
          </div>
          <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
            Bond NFT: <AddressLink chainId={chainId} address={nftVault} />
          </div>
          {claimToken ? <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
            Staking token: <AddressLink chainId={chainId} address={claimToken} />
          </div> : null}
        </div>
        {onLoadCertificate ? <Button type="button" variant="secondary" size="sm" onClick={onLoadCertificate}>
          Load certificate
        </Button> : null}
      </div>

      {role ? <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
        {role} sDETF receipts arrive directly in the NFT owner’s wallet when rewards are funded.
        They can be unstaked for DETF, and future funded rewards continue after a full unstake.
      </p> : <>
        <p className="text-sm text-[var(--text-muted,#9aa3b2)]">Vesting ends: {vestingEndLabel}</p>
        <div className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
          {amounts.map(([label, amount, unit]) => <div key={label} className="text-[var(--text-primary,#EDEDED)]">
            <span className="text-[var(--text-muted,#9aa3b2)]">{label}: </span>
            <span className="font-mono tabular-nums">{formatBondAmount(amount, 9)} {unit}</span>
          </div>)}
        </div>
        <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
          Principal unlocks continuously. Staking rewards are claimable during vesting. Both pay sDETF, which unstakes 1:1 for DETF.
        </p>
        <div className="flex flex-wrap gap-2">
          <Button type="button" variant="secondary" size="sm" disabled={!available.rewards || !onClaim}
            loading={actionKeyPending === claimKey} onClick={onClaim}>
            {actionKeyPending === claimKey ? 'Claiming…' : 'Claim rewards'}
          </Button>
          <Button type="button" variant="primary" size="sm" disabled={!available.combined || !onRedeem}
            loading={actionKeyPending === redeemKey} onClick={onRedeem}>
            {actionKeyPending === redeemKey ? 'Claiming…' : 'Claim available sDETF'}
          </Button>
        </div>
      </>}

      {metadata?.image ? <div className="max-w-full overflow-hidden rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))]">
        <Image src={metadata.image} alt={metadata.name || `Bond #${tokenId}`} width={800} height={800}
          unoptimized className="h-auto w-full" />
      </div> : null}
      {metadata?.name ? <div className="text-sm text-[var(--text-primary,#EDEDED)]">
        <div className="font-semibold">{metadata.name}</div>
        {metadata.description ? <p className="mt-1 text-[var(--text-muted,#9aa3b2)]">{metadata.description}</p> : null}
      </div> : null}
    </Card>
  )
}

export default BondNftCard
