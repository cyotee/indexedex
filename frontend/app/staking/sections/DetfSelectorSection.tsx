'use client'

type DetfOption = {
  value: string
  label: string
}

interface DetfSelectorSectionProps {
  detfOptions: DetfOption[]
  selectedDetf: string
  onSelect: (value: string) => void
  isConnected: boolean
  address: `0x${string}` | undefined
  attachedWalletChainId: number | undefined
  dataChainId: number
}

export default function DetfSelectorSection({
  detfOptions,
  selectedDetf,
  onSelect,
  isConnected,
  address,
  attachedWalletChainId,
  dataChainId,
}: DetfSelectorSectionProps) {
  return (
    <div className="rounded-lg border border-gray-700 bg-gray-800 p-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <label className="block text-xs text-gray-400">Protocol DETF</label>
          <select
            value={selectedDetf}
            onChange={(event) => onSelect(event.target.value)}
            className="mt-1 w-full rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-gray-100"
          >
            {detfOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div className="text-xs text-gray-400">
          Wallet: {isConnected && address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'not connected'}
        </div>
        <div className="text-xs text-gray-400">
          Wallet chain: {attachedWalletChainId ?? '—'} | Display chain: {dataChainId}
        </div>
      </div>
    </div>
  )
}