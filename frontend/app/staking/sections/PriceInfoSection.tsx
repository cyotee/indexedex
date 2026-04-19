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
    <div className="rounded-lg border border-gray-700 bg-gray-800 p-4">
      <div className="rounded-md border border-gray-700 bg-gray-900 p-3">
        <div className="text-xs text-gray-400">Synthetic Price (RICH per WETH)</div>
        <div className="text-sm text-gray-100">{syntheticPriceStatus}</div>
        <div className="mt-1 text-xs text-gray-500">
          Minting is enabled when the synthetic price is above the mint threshold. Burning is enabled when it is below the burn threshold.
        </div>
        <div className="mt-2 text-xs text-gray-400">Mint threshold (price must be above this to mint)</div>
        <div className="text-sm text-gray-100">{mintThresholdStatus}</div>
        <div className="mt-2 text-xs text-gray-400">Burn threshold (price must be below this to burn)</div>
        <div className="text-sm text-gray-100">{burnThresholdStatus}</div>
        {syntheticPriceError ? (
          <div className="mt-2 text-xs text-amber-300">
            The Protocol DETF contract reverted while calculating the synthetic price for the current pool state.
          </div>
        ) : null}
        <div className="mt-2 text-xs text-gray-400">
          Minting allowed: <span className="text-gray-200">{String(mintingAllowedNow ?? '—')}</span>
        </div>
        <div className="text-xs text-gray-400">
          Burning allowed: <span className="text-gray-200">{String(burningAllowedNow ?? '—')}</span>
        </div>
        {availabilityMismatch ? (
          <div className="mt-2 text-xs text-amber-300">
            The direct availability reads disagree with the threshold-derived result. The UI is using the threshold-derived value.
          </div>
        ) : null}
      </div>
    </div>
  )
}