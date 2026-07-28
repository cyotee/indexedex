import type { CSSProperties, ReactNode } from 'react'

import type { ResearchDiagramId } from '../../../content/research/types'

type Props = {
  id: ResearchDiagramId
  className?: string
}

/**
 * Composition diagrams for DETF research notes.
 *
 * Locked visual system (reuse for every family diagram):
 * - Panel: accent border + glow, surface-2 fill, radial accent wash on canvas
 * - Labels / leg titles: --text-primary (light) — never accent-on-accent text
 * - Primary leg (DETF): accent border/fill; weight pill = accent fill + dark text
 * - Secondary leg (SE / external): warm amber; solid fill when present
 * - Connectors: accent line + arrow; optional accent pill labels
 * - Caption bar: surface-1, light primary text
 * - Hold pill: accent border wash, --text-primary label
 *
 * Locked multi-leg / capacity strip (canonical: Multi-Vault Weighted):
 * - One full-width horizontal row inside the reserve pool frame (not stacked)
 * - DETF first (accent card), then max-capacity SE slots in the same line
 * - Filled slots: solid amber border + amber tint (example legs in use)
 * - Open slots: dashed amber border, dimmed labels (“open”) for remaining capacity
 * - Do NOT add a separate “Standard Exchange vaults” panel below multi-leg diagrams —
 *   capacity and SE legs live only in the pool strip
 * - Weight bar under the pool is optional and illustrative only
 *
 * Theme note: amber secondary stays readable on Pachira green and IndexedEx blue.
 */
export function DetfCompositionDiagram({ id, className = '' }: Props) {
  switch (id) {
    case 'single-standard-exchange':
      return <SingleStandardExchangeDiagram className={className} />
    case 'multi-vault-weighted':
      return <MultiVaultWeightedDiagram className={className} />
    default:
      return null
  }
}

const shellStyle: CSSProperties = {
  borderColor: 'var(--border-accent)',
  backgroundColor: 'var(--surface-2)',
  boxShadow:
    '0 0 0 1px color-mix(in srgb, var(--accent) 16%, transparent), 0 16px 48px rgba(0,0,0,0.45), 0 0 48px color-mix(in srgb, var(--accent) 14%, transparent)',
}

const headerStyle: CSSProperties = {
  borderColor: 'color-mix(in srgb, var(--accent) 35%, transparent)',
  background:
    'linear-gradient(90deg, color-mix(in srgb, var(--accent) 16%, var(--surface-1)), var(--surface-1))',
}

const canvasStyle: CSSProperties = {
  background:
    'radial-gradient(ellipse at 50% 28%, color-mix(in srgb, var(--accent) 10%, transparent), transparent 58%)',
}

const captionBarStyle: CSSProperties = {
  borderColor: 'color-mix(in srgb, var(--accent) 28%, transparent)',
  backgroundColor: 'var(--surface-1)',
}

function DiagramShell({
  title,
  caption,
  children,
  className = '',
}: {
  title: string
  caption: string
  children: ReactNode
  className?: string
}) {
  return (
    <figure
      className={`mt-6 overflow-hidden rounded-2xl border-2 ${className}`}
      style={shellStyle}
    >
      <figcaption className="relative border-b px-4 py-3 sm:px-5" style={headerStyle}>
        <div
          className="pointer-events-none absolute inset-y-0 left-0 w-1 bg-[var(--accent)]"
          aria-hidden="true"
        />
        <p className="pl-2 font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--accent)]">
          Composition
        </p>
        <p className="mt-0.5 pl-2 text-base font-medium text-[var(--text-primary)]">{title}</p>
      </figcaption>
      <div className="relative px-4 py-6 sm:px-6 sm:py-7">
        <div className="pointer-events-none absolute inset-0" style={canvasStyle} aria-hidden="true" />
        <div className="relative">{children}</div>
      </div>
      <p
        className="border-t px-4 py-3 text-xs leading-relaxed text-[var(--text-primary)]/85 sm:px-5"
        style={captionBarStyle}
      >
        {caption}
      </p>
    </figure>
  )
}

const poolStyle: CSSProperties = {
  borderColor: 'color-mix(in srgb, var(--accent) 55%, transparent)',
  background:
    'linear-gradient(180deg, color-mix(in srgb, var(--accent) 8%, var(--surface-1)), var(--surface-1))',
  boxShadow:
    'inset 0 1px 0 color-mix(in srgb, var(--accent) 20%, transparent), 0 8px 24px rgba(0,0,0,0.28)',
}

function PoolFrame({
  label,
  children,
  footer,
}: {
  label: string
  children: ReactNode
  footer?: ReactNode
}) {
  return (
    <div className="rounded-xl border p-3.5 sm:p-5" style={poolStyle}>
      <p className="mb-3.5 font-mono text-[10px] uppercase tracking-[0.14em] text-[var(--text-primary)]">
        {label}
      </p>
      {children}
      {footer ? <div className="mt-4">{footer}</div> : null}
    </div>
  )
}

const legAccentStyle: CSSProperties = {
  borderColor: 'color-mix(in srgb, var(--accent) 70%, transparent)',
  background: 'color-mix(in srgb, var(--accent-muted) 88%, var(--accent))',
  boxShadow: '0 0 22px color-mix(in srgb, var(--accent) 20%, transparent)',
}

/** Warm amber secondary — stays readable on green (Pachira) and blue (IndexedEx) themes. */
const legSecondaryStyle: CSSProperties = {
  borderColor: 'rgba(251, 191, 36, 0.5)',
  background: 'color-mix(in srgb, #78350f 28%, var(--surface-0))',
  boxShadow: '0 0 18px rgba(251, 191, 36, 0.12)',
}

function Leg({
  title,
  subtitle,
  weight,
  accent,
  secondary,
}: {
  title: string
  subtitle: string
  weight?: string
  accent?: boolean
  secondary?: boolean
}) {
  const tone = accent ? 'accent' : secondary ? 'secondary' : 'neutral'
  const shellStyleForLeg =
    tone === 'accent'
      ? legAccentStyle
      : tone === 'secondary'
        ? legSecondaryStyle
        : undefined

  // Titles use high-contrast light text; accent/amber reserved for weight pills (not title-on-tint).
  const titleClass =
    tone === 'secondary' ? 'text-amber-100' : 'text-[var(--text-primary)]'

  const weightClass =
    tone === 'accent'
      ? 'bg-[var(--accent)] text-[var(--surface-0)]'
      : tone === 'secondary'
        ? 'bg-amber-300 text-[var(--surface-0)]'
        : 'bg-[var(--surface-2)] text-[var(--text-muted)]'

  return (
    <div
      className="flex min-h-[5.25rem] flex-1 flex-col justify-center rounded-lg border px-3.5 py-3.5"
      style={shellStyleForLeg}
    >
      <p className={`text-base font-medium ${titleClass}`}>{title}</p>
      <p className="mt-1 text-xs leading-snug text-[var(--text-muted)]">{subtitle}</p>
      {weight ? (
        <p
          className={`mt-3 w-fit rounded-full px-2.5 py-0.5 font-mono text-[10px] font-semibold uppercase tracking-wide ${weightClass}`}
        >
          {weight}
        </p>
      ) : null}
    </div>
  )
}

function Connector({ label }: { label?: string }) {
  return (
    <div className="flex flex-col items-center py-2.5" aria-hidden="true">
      <div
        className="h-5 w-0.5 rounded-full"
        style={{ background: 'color-mix(in srgb, var(--accent) 60%, transparent)' }}
      />
      {label ? (
        <span
          className="my-1.5 rounded-full border px-2.5 py-0.5 font-mono text-[10px] uppercase tracking-wide text-[var(--accent)]"
          style={{
            borderColor: 'color-mix(in srgb, var(--accent) 45%, transparent)',
            background: 'color-mix(in srgb, var(--accent-muted) 85%, transparent)',
          }}
        >
          {label}
        </span>
      ) : null}
      <div
        className="h-5 w-0.5 rounded-full"
        style={{ background: 'color-mix(in srgb, var(--accent) 60%, transparent)' }}
      />
      <div
        className="h-0 w-0 border-l-[6px] border-r-[6px] border-t-[8px] border-l-transparent border-r-transparent"
        style={{ borderTopColor: 'var(--accent)' }}
      />
    </div>
  )
}

type WeightSegment = {
  /** CSS width, e.g. "40%" */
  width: string
  label: string
  tone: 'accent' | 'secondary'
}

function WeightBar({
  segments,
  ariaLabel,
}: {
  segments: readonly WeightSegment[]
  ariaLabel: string
}) {
  return (
    <div>
      <div
        className="flex h-2.5 overflow-hidden rounded-full"
        role="img"
        aria-label={ariaLabel}
        style={{
          boxShadow: '0 0 0 1px color-mix(in srgb, var(--accent) 30%, transparent)',
        }}
      >
        {segments.map((seg) => (
          <div
            key={seg.label}
            className={`h-full ${seg.tone === 'accent' ? 'bg-[var(--accent)]' : 'bg-amber-300'}`}
            style={{ width: seg.width }}
            title={seg.label}
          />
        ))}
      </div>
      <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 font-mono text-[10px] uppercase tracking-wide">
        {segments.map((seg) => (
          <span
            key={`lbl-${seg.label}`}
            className={seg.tone === 'accent' ? 'text-[var(--text-primary)]' : 'text-amber-200'}
          >
            {seg.label}
          </span>
        ))}
      </div>
    </div>
  )
}

function Plus() {
  return (
    <div
      className="flex items-center justify-center font-mono text-sm font-semibold text-[var(--accent)] sm:px-0.5"
      aria-hidden="true"
    >
      +
    </div>
  )
}

/** Illustrative backends only — SE is the standard adapter, not this short list. */
const SE_VAULT_EXAMPLES = ['Uniswap V4', 'Euler'] as const

function ExampleChips({ labels }: { labels: readonly string[] }) {
  return (
    <div className="mt-3.5">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-amber-200/90">
        Example integrations
      </p>
      <ul className="mt-2 flex flex-wrap gap-1.5">
        {labels.map((label) => (
          <li
            key={label}
            className="rounded-full border border-amber-300/45 bg-amber-400/15 px-2.5 py-0.5 font-mono text-[10px] uppercase tracking-wide text-amber-100"
          >
            {label}
          </li>
        ))}
      </ul>
    </div>
  )
}

const holdPillStyle: CSSProperties = {
  borderColor: 'color-mix(in srgb, var(--accent) 50%, transparent)',
  background: 'color-mix(in srgb, var(--accent-muted) 88%, transparent)',
  boxShadow: '0 0 18px color-mix(in srgb, var(--accent) 16%, transparent)',
}

const seBoxStyle: CSSProperties = {
  borderColor: 'rgba(251, 191, 36, 0.45)',
  background: 'color-mix(in srgb, #78350f 22%, var(--surface-0))',
  boxShadow: '0 0 22px rgba(251, 191, 36, 0.1)',
}

function SingleStandardExchangeDiagram({ className }: { className?: string }) {
  return (
    <DiagramShell
      className={className}
      title="Single Standard Exchange DETF"
      caption="You hold the DETF ERC-20. The other reserve leg is one SE vault share — IndexedEx’s deposit / share / redeem adapter over an external protocol (e.g. Uniswap V4, Euler). Mint and burn move value between free DETF and that share (live + Policy/Open)."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF share (ERC-20)
        </div>
      </div>
      <Connector />

      <PoolFrame
        label="Weighted reserve pool (Balancer V3)"
        footer={
          <WeightBar
            ariaLabel="Example weights: about 80% DETF, about 20% SE vault share"
            segments={[
              { width: '80%', label: '~80% DETF', tone: 'accent' },
              { width: '20%', label: '~20% SE share', tone: 'secondary' },
            ]}
          />
        }
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
          <Leg
            accent
            title="DETF (self)"
            subtitle="This diamond’s own share token in the pool"
            weight="Default ~80%"
          />
          <Plus />
          <Leg
            secondary
            title="SE vault share"
            subtitle="Exactly one Standard Exchange vault share"
            weight="Default ~20%"
          />
        </div>
      </PoolFrame>

      <Connector label="is" />

      <div className="rounded-xl border px-4 py-4" style={seBoxStyle}>
        <p className="text-base font-medium text-amber-100">Standard Exchange vault</p>
        <p className="mt-1.5 text-xs leading-relaxed text-[var(--text-muted)]">
          Vault standard — not a DETF type. Same deposit / share / redeem interface wrapping an
          external protocol. The DETF holds the SE share only; Uni or Euler stay behind the vault.
        </p>
        <ExampleChips labels={SE_VAULT_EXAMPLES} />
      </div>
    </DiagramShell>
  )
}

/**
 * Multi-Vault Weighted — reference implementation of the locked multi-leg strip.
 * Clone this strip pattern for other multi-capacity diagrams (stable, mixed-buffer, etc.).
 */
/** Illustrative multi-leg weights (not a product default). Three SE legs filled of seven. */
const MULTI_WEIGHTED_SEGMENTS: readonly WeightSegment[] = [
  { width: '40%', label: '~40% DETF', tone: 'accent' },
  { width: '25%', label: '~25% SE₁', tone: 'secondary' },
  { width: '20%', label: '~20% SE₂', tone: 'secondary' },
  { width: '15%', label: '~15% SE₃', tone: 'secondary' },
]

/** How many SE vault slots to show as filled (rest are open capacity through 7). */
const MULTI_WEIGHTED_FILLED_SE = 3
const MULTI_WEIGHTED_SE_CAPACITY = 7

function MultiVaultWeightedDiagram({ className }: { className?: string }) {
  return (
    <DiagramShell
      className={className}
      title="Multi-Vault Weighted DETF"
      caption="You hold the DETF ERC-20. The reserve is one weighted Balancer pool: DETF plus one to seven SE vault shares in a single line, each with a custom immutable weight and independent valuation. Filled slots are an example; dimmed slots are open capacity (up to 7). Weights in the bar are illustrative only. Mint and burn against configured vault shares (live + Policy/Open); first live path is initialize reserve, then bond reserve BPT."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF share (ERC-20)
        </div>
      </div>
      <Connector />

      <PoolFrame
        label="Weighted reserve pool (Balancer V3) — DETF + up to 7 SE vault shares"
        footer={
          <WeightBar
            ariaLabel="Example custom weights across DETF and filled SE vault shares"
            segments={MULTI_WEIGHTED_SEGMENTS}
          />
        }
      >
        {/* Full-width line: DETF + 7 SE slots (filled example + dimmed open capacity) */}
        <div className="flex w-full flex-row items-stretch gap-1.5 sm:gap-2">
          <div
            className="flex min-h-[4.5rem] min-w-0 flex-[1.15] flex-col justify-center rounded-lg border px-2 py-2.5 text-center sm:px-2.5"
            style={legAccentStyle}
          >
            <p className="text-sm font-medium leading-snug text-[var(--text-primary)]">DETF</p>
            <p className="mt-0.5 text-[9px] leading-tight text-[var(--text-muted)] sm:text-[10px]">
              self
            </p>
          </div>

          {Array.from({ length: MULTI_WEIGHTED_SE_CAPACITY }, (_, i) => {
            const filled = i < MULTI_WEIGHTED_FILLED_SE
            return (
              <div
                key={`reserve-se-${i + 1}`}
                className={`flex min-h-[4.5rem] min-w-0 flex-1 flex-col justify-center rounded-lg border px-1.5 py-2 text-center sm:px-2 ${
                  filled
                    ? 'border-amber-300/45 bg-amber-400/15 shadow-[0_0_12px_rgba(251,191,36,0.1)]'
                    : 'border-dashed border-amber-300/25 bg-transparent'
                }`}
              >
                <p
                  className={`font-mono text-[9px] uppercase tracking-wide sm:text-[10px] ${
                    filled ? 'text-amber-100' : 'text-amber-200/45'
                  }`}
                >
                  SE {i + 1}
                </p>
                <p
                  className={`mt-0.5 text-[9px] leading-tight sm:text-[10px] ${
                    filled ? 'text-[var(--text-muted)]' : 'text-[var(--text-muted)]/50'
                  }`}
                >
                  {filled ? 'share' : 'open'}
                </p>
              </div>
            )
          })}
        </div>
      </PoolFrame>
    </DiagramShell>
  )
}

export default DetfCompositionDiagram

