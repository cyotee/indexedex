'use client'

interface PriceInfoSectionProps {
  syntheticPriceStatus: string
  mintThresholdStatus: string
  burnThresholdStatus: string
  syntheticPriceError: Error | null | undefined
  mintingAllowedNow: boolean | undefined
  burningAllowedNow: boolean | undefined
  availabilityMismatch: boolean
}

export default function PriceInfoSection({
  syntheticPriceStatus,
  mintThresholdStatus,
  burnThresholdStatus,
  syntheticPriceError,
  mintingAllowedNow,
  burningAllowedNow,
  availabilityMismatch,
}: PriceInfoSectionProps) {
  return (
    <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
      <div className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] p-3">
        <div className="text-xs text-[var(--text-muted,#9aa3b2)]">
          Synthetic price (pair token per rate asset)
        </div>
        <div className="font-mono text-sm tabular-nums text-[var(--text-primary,#EDEDED)]">
          {syntheticPriceStatus}
        </div>
        <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Minting is enabled when the synthetic price is above the mint threshold. Burning is enabled when
          it is below the burn threshold.
        </div>
        <div className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Mint threshold (price must be above this to mint)
        </div>
        <div className="font-mono text-sm tabular-nums text-[var(--text-primary,#EDEDED)]">
          {mintThresholdStatus}
        </div>
        <div className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Burn threshold (price must be below this to burn)
        </div>
        <div className="font-mono text-sm tabular-nums text-[var(--text-primary,#EDEDED)]">
          {burnThresholdStatus}
        </div>
        {syntheticPriceError ? (
          <div className="mt-2 text-xs text-amber-300">
            The protocol DETF contract reverted while calculating the synthetic price for the current pool
            state.
          </div>
        ) : null}
        <div className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Minting allowed:{' '}
          <span className="text-[var(--text-primary,#EDEDED)]">{String(mintingAllowedNow ?? '—')}</span>
        </div>
        <div className="text-xs text-[var(--text-muted,#9aa3b2)]">
          Burning allowed:{' '}
          <span className="text-[var(--text-primary,#EDEDED)]">{String(burningAllowedNow ?? '—')}</span>
        </div>
        {availabilityMismatch ? (
          <div className="mt-2 text-xs text-amber-300">
            The direct availability reads disagree with the threshold-derived result. The UI is using the
            threshold-derived value.
          </div>
        ) : null}
      </div>
    </div>
  )
}
