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

const inputClass =
  'mt-1 w-full rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

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
    <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div className="min-w-0 flex-1">
          <label className="block text-xs text-[var(--text-muted,#9aa3b2)]">Protocol DETF</label>
          <select
            value={selectedDetf}
            onChange={(event) => onSelect(event.target.value)}
            className={inputClass}
          >
            {detfOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div className="text-xs text-[var(--text-muted,#9aa3b2)]">
          Wallet:{' '}
          {isConnected && address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'not connected'}
        </div>
        <div className="text-xs text-[var(--text-muted,#9aa3b2)]">
          Wallet chain: {attachedWalletChainId ?? '—'} | Display chain: {dataChainId}
        </div>
      </div>
    </div>
  )
}
