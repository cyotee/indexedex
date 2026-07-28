'use client'

import Image from 'next/image'
import { AddressLink } from '../ui/AddressLink'
import { Button } from '../ui/Button'
import { Card } from '../ui/Card'
import { formatBondAmount } from '../../lib/portfolio/formatBondAmount'
import type { BondNftMetadata } from '../../lib/portfolio/types'

export type BondNftCardProps = {
  kind: 'seigniorage' | 'protocol'
  symbol: string
  tokenId: bigint
  chainId: number
  nftVault: `0x${string}`
  claimToken?: `0x${string}`
  rewardToken?: `0x${string}`
  unlockTimeLabel: string
  bonusLabel: string
  sharesAwarded?: bigint
  pendingRewards?: bigint
  sharesDecimals?: number
  rewardDecimals?: number
  matured: boolean
  actionKeyPending: string | null
  withdrawKey: string
  unlockKey: string
  claimKey: string
  redeemKey: string
  isWritePending?: boolean
  metadata?: BondNftMetadata
  onLoadCertificate?: () => void
  onWithdrawRewards?: () => void
  onUnlock?: () => void
  onClaim?: () => void
  onRedeem?: () => void
}

/**
 * Presentational bond NFT card — handlers and discovery stay in Portfolio page.
 * Preserves per-action pending keys and disable rules.
 */
export function BondNftCard({
  kind,
  symbol,
  tokenId,
  chainId,
  nftVault,
  claimToken,
  rewardToken,
  unlockTimeLabel,
  bonusLabel,
  sharesAwarded,
  pendingRewards,
  sharesDecimals = 18,
  rewardDecimals = 18,
  matured,
  actionKeyPending,
  withdrawKey,
  unlockKey,
  claimKey,
  redeemKey,
  isWritePending = false,
  metadata,
  onLoadCertificate,
  onWithdrawRewards,
  onUnlock,
  onClaim,
  onRedeem,
}: BondNftCardProps) {
  const ZERO = BigInt(0)
  const pending = pendingRewards ?? ZERO
  const withdrawDisabled =
    !pending || pending === ZERO || isWritePending || actionKeyPending === withdrawKey
  const unlockDisabled = !matured || isWritePending || actionKeyPending === unlockKey
  const claimDisabled =
    !pending || pending === ZERO || isWritePending || actionKeyPending === claimKey
  const redeemDisabled = !matured || isWritePending || actionKeyPending === redeemKey

  const idLabel = tokenId.toString()
  const titleKind = kind === 'protocol' ? 'Protocol Bond' : 'Bond'

  return (
    <Card data-testid="bond-nft-card" className="space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="font-semibold text-[var(--text-primary,#EDEDED)]">
            {symbol} · {titleKind} #{idLabel}
          </div>
          <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
            NFT vault:{' '}
            <AddressLink chainId={chainId} address={nftVault} />
          </div>
          {claimToken ? (
            <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Claim token:{' '}
              <AddressLink chainId={chainId} address={claimToken} />
            </div>
          ) : null}
          {rewardToken ? (
            <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Reward token:{' '}
              <AddressLink chainId={chainId} address={rewardToken} />
            </div>
          ) : null}
        </div>
        {onLoadCertificate ? (
          <Button type="button" variant="secondary" size="sm" onClick={onLoadCertificate}>
            Load certificate
          </Button>
        ) : null}
      </div>

      <div className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
        <div className="text-[var(--text-primary,#EDEDED)]">
          <span className="text-[var(--text-muted,#9aa3b2)]">Unlock time:</span> {unlockTimeLabel}
        </div>
        <div className="text-[var(--text-primary,#EDEDED)]">
          <span className="text-[var(--text-muted,#9aa3b2)]">Bonus:</span> {bonusLabel}
        </div>
        <div className="text-[var(--text-primary,#EDEDED)]">
          <span className="text-[var(--text-muted,#9aa3b2)]">Shares awarded:</span>{' '}
          <span className="font-mono tabular-nums">{formatBondAmount(sharesAwarded, sharesDecimals)}</span>
        </div>
        <div className="text-[var(--text-primary,#EDEDED)]">
          <span className="text-[var(--text-muted,#9aa3b2)]">Pending rewards:</span>{' '}
          <span className="font-mono tabular-nums">{formatBondAmount(pendingRewards, rewardDecimals)}</span>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {kind === 'seigniorage' ? (
          <>
            <Button
              type="button"
              variant="primary"
              size="sm"
              disabled={withdrawDisabled}
              loading={actionKeyPending === withdrawKey}
              onClick={onWithdrawRewards}
            >
              {actionKeyPending === withdrawKey ? 'Withdrawing…' : 'Withdraw rewards'}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={unlockDisabled}
              loading={actionKeyPending === unlockKey}
              onClick={onUnlock}
              title={matured ? 'Unlock bond' : 'Bond not matured yet'}
            >
              {actionKeyPending === unlockKey ? 'Unlocking…' : matured ? 'Unlock' : 'Unlock (locked)'}
            </Button>
          </>
        ) : (
          <>
            <Button
              type="button"
              variant="primary"
              size="sm"
              disabled={claimDisabled}
              loading={actionKeyPending === claimKey}
              onClick={onClaim}
            >
              {actionKeyPending === claimKey ? 'Claiming…' : 'Claim rewards'}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={redeemDisabled}
              loading={actionKeyPending === redeemKey}
              onClick={onRedeem}
              title={matured ? 'Redeem bond' : 'Bond not matured yet'}
            >
              {actionKeyPending === redeemKey ? 'Redeeming…' : matured ? 'Redeem' : 'Redeem (locked)'}
            </Button>
          </>
        )}
      </div>

      {metadata?.image ? (
        <div>
          <div className="mb-2 text-xs text-[var(--text-muted,#9aa3b2)]">Certificate image</div>
          <div className="max-w-full overflow-hidden rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-white">
            <Image
              src={metadata.image}
              alt={metadata.name || `Bond #${idLabel}`}
              width={800}
              height={800}
              unoptimized
              className="h-auto w-full"
            />
          </div>
        </div>
      ) : null}

      {metadata?.name ? (
        <div className="text-sm text-[var(--text-primary,#EDEDED)]">
          <div className="font-semibold">{metadata.name}</div>
          {metadata.description ? (
            <div className="mt-1 text-[var(--text-muted,#9aa3b2)]">{metadata.description}</div>
          ) : null}
        </div>
      ) : null}
    </Card>
  )
}

export default BondNftCard
