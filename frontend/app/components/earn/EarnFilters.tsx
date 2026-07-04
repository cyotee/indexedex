'use client'

import type { EarnProductType } from '../../lib/earn/types'

export type EarnTypeFilter = EarnProductType | 'all'

const OPTIONS: { id: EarnTypeFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'strategy', label: 'Strategy' },
  { id: 'protocol-detf', label: 'Protocol DETF' },
  { id: 'seigniorage-detf', label: 'Seigniorage' },
]

export function EarnFilters({
  productType,
  search,
  onProductTypeChange,
  onSearchChange,
}: {
  productType: EarnTypeFilter
  search: string
  onProductTypeChange: (t: EarnTypeFilter) => void
  onSearchChange: (q: string) => void
}) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4">
      <div className="flex flex-wrap gap-1">
        {OPTIONS.map((opt) => (
          <button
            key={opt.id}
            type="button"
            onClick={() => onProductTypeChange(opt.id)}
            className={[
              'rounded-full px-3 py-1 text-xs font-medium border transition-colors',
              productType === opt.id
                ? 'border-[var(--border-accent,rgba(79,212,75,0.45))] bg-[var(--accent-muted,#1A3721)] text-[var(--accent,#4FD44B)]'
                : 'border-[var(--border-subtle,rgba(255,255,255,0.08))] text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]',
            ].join(' ')}
          >
            {opt.label}
          </button>
        ))}
      </div>
      <input
        type="search"
        value={search}
        onChange={(e) => onSearchChange(e.target.value)}
        placeholder="Token address, symbol, or name…"
        className="w-full sm:w-64 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)] placeholder:text-[var(--text-muted,#9aa3b2)]"
      />
    </div>
  )
}

export default EarnFilters
