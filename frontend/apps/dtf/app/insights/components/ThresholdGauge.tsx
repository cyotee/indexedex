'use client'

import type { ThresholdScale } from '../lib/thresholdScale'

export function ThresholdGauge({
  scale,
  burnLabel,
  priceLabel,
  mintLabel,
}: {
  scale: ThresholdScale
  burnLabel: string
  priceLabel: string
  mintLabel: string
}) {
  if (scale.inert) {
    return (
      <div
        className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-4 py-8 text-center text-sm text-[var(--text-muted,#9aa3b2)]"
        data-testid="insights-gauge-inert"
      >
        This DETF is inert. Price appears after the first bond.
      </div>
    )
  }

  if (scale.openMode) {
    return (
      <div
        className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-4 py-6 text-sm text-[var(--text-muted,#9aa3b2)]"
        data-testid="insights-gauge-open"
      >
        Open mode. Mint and burn are not blocked by synthetic price.
        <p className="mt-2 font-mono text-[var(--text-primary,#EDEDED)]">Price {priceLabel}</p>
      </div>
    )
  }

  return (
    <div data-testid="insights-gauge">
      <svg viewBox="0 0 100 28" className="h-24 w-full" role="img" aria-label="Mint and burn thresholds versus synthetic price">
        <rect x="2" y="11" width="96" height="6" rx="3" fill="var(--surface-2, #1c2030)" />
        <line
          x1={scale.burnPct}
          x2={scale.mintPct}
          y1="14"
          y2="14"
          stroke="var(--accent, #4FD44B)"
          strokeWidth="6"
          strokeLinecap="round"
          opacity="0.35"
        />
        <circle cx={scale.burnPct} cy="14" r="3.2" fill="var(--text-muted, #9aa3b2)" />
        <circle cx={scale.mintPct} cy="14" r="3.2" fill="var(--text-muted, #9aa3b2)" />
        <circle cx={scale.pricePct} cy="14" r="4.4" fill="var(--accent, #4FD44B)" />
      </svg>
      <div className="mt-1 grid grid-cols-3 gap-2 text-[11px] text-[var(--text-muted,#9aa3b2)]">
        <div>
          Burn
          <div className="font-mono tabular-nums text-[var(--text-primary,#EDEDED)]">{burnLabel}</div>
        </div>
        <div className="text-center">
          Price
          <div className="font-mono tabular-nums text-[var(--accent,#4FD44B)]">{priceLabel}</div>
        </div>
        <div className="text-right">
          Mint
          <div className="font-mono tabular-nums text-[var(--text-primary,#EDEDED)]">{mintLabel}</div>
        </div>
      </div>
    </div>
  )
}
