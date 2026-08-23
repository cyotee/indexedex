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
 * - For single-layer weighted reserves: SE capacity lives in the pool strip only
 * - Weight bar under the pool is optional and illustrative only
 *
 * Locked multi-layer rate-provider composition (canonical: Multi-Vault Stable):
 * Use when a DETF has intermediate pools, dual rate views, or multiple rate providers
 * per vault — not for flat single-pool weighted DETFs.
 * - Intermediate pools enumerate SE vault legs they hold (per-pool strip, not a shared set)
 * - SE vaults are independent products — never one grouped “shared set” card
 * - Separate Rate Provider blocks: one RP per (vault × marking/pool) pair
 *   Example: 4 SE vaults × 2 pools = 8 rate providers
 * - RP → Stable markings: accent-tinted blocks; RP → Common (or second view): amber
 * - Independent SE vault blocks on their own row below the RPs
 * - Crossing connectors (SVG) from each SE vault to both of its RPs when geometry allows
 * - Top true DETF reserve still shows DETF + composition receipts (e.g. Stable BPT, Common BPT)
 *
 * Locked mixed-buffer strip (canonical: Mixed-Buffer Multi-Vault Stable):
 * - One MixedBuffer stable pool (not weighted; not dual intermediate stables)
 * - Full-width row: DETF (accent) + exactly one buffer token (neutral cash leg) + SE slots
 * - SE capacity 1–3: filled solid amber, open dashed/dimmed
 * - Buffer is the shared cash unit vaults accept and produce; burn settles to buffer only
 * - Do not invent dual-pool / 8-RP topology here — that is Multi-Vault Stable only
 *
 * Theme note: amber secondary stays readable on Pachira green and IndexedEx blue.
 */
export function DetfCompositionDiagram({ id, className = '' }: Props) {
  switch (id) {
    case 'single-standard-exchange':
      return <SingleStandardExchangeDiagram className={className} />
    case 'multi-vault-weighted':
      return <MultiVaultWeightedDiagram className={className} />
    case 'multi-vault-stable':
      return <MultiVaultStableDiagram className={className} />
    case 'mixed-buffer-multi-vault-stable':
      return <MixedBufferMultiVaultStableDiagram className={className} />
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
  kicker = 'Composition',
}: {
  title: string
  caption: string
  children: ReactNode
  className?: string
  kicker?: string
}) {
  return (
    <figure
      className={`overflow-hidden rounded-2xl border-2 ${className.includes('mt-') ? className : `mt-6 ${className}`}`}
      style={shellStyle}
    >
      <figcaption className="relative border-b px-4 py-3 sm:px-5" style={headerStyle}>
        <div
          className="pointer-events-none absolute inset-y-0 left-0 w-1 bg-[var(--accent)]"
          aria-hidden="true"
        />
        <p className="pl-2 font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--accent)]">
          {kicker}
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
      title="One vault"
      caption="You hold the DETF token. The other reserve leg is one vault share from a vault that wraps another protocol. Mint and burn move between that vault share and the DETF token."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF token
        </div>
      </div>
      <Connector />

      <PoolFrame
        label="Reserve: DETF token plus one vault share"
        footer={
          <WeightBar
            ariaLabel="Example weights: about 80% DETF, about 20% vault share"
            segments={[
              { width: '80%', label: '~80% DETF', tone: 'accent' },
              { width: '20%', label: '~20% vault share', tone: 'secondary' },
            ]}
          />
        }
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
          <Leg
            accent
            title="DETF token"
            subtitle="The DETF token in the reserve"
            weight="Default ~80%"
          />
          <Plus />
          <Leg
            secondary
            title="Vault share"
            subtitle="Exactly one vault share"
            weight="Default ~20%"
          />
        </div>
      </PoolFrame>

      <Connector label="is" />

      <div className="rounded-xl border px-4 py-4" style={seBoxStyle}>
        <p className="text-base font-medium text-amber-100">Earn vault</p>
        <p className="mt-1.5 text-xs leading-relaxed text-[var(--text-muted)]">
          A building-block vault, not a DETF type. Deposit, receive a vault share, redeem later.
          The DETF holds that vault share. The other protocol stays behind the vault.
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
  { width: '25%', label: '~25% vault 1', tone: 'secondary' },
  { width: '20%', label: '~20% vault 2', tone: 'secondary' },
  { width: '15%', label: '~15% vault 3', tone: 'secondary' },
]

/** How many SE vault slots to show as filled (rest are open capacity through 7). */
const MULTI_WEIGHTED_FILLED_SE = 3
const MULTI_WEIGHTED_SE_CAPACITY = 7

function MultiVaultWeightedDiagram({ className }: { className?: string }) {
  return (
    <DiagramShell
      className={className}
      title="Several vaults, fixed weights"
      caption="You hold the DETF token. The reserve holds that token plus one to seven vault shares, each with a set weight. Filled slots are an example. Dimmed slots are open capacity. Weights in the bar are only an example."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF token
        </div>
      </div>
      <Connector />

      <PoolFrame
        label="Reserve: DETF token plus up to 7 vault shares"
        footer={
          <WeightBar
            ariaLabel="Example custom weights across DETF and filled vault shares"
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

          {Array.from({ length: MULTI_WEIGHTED_SE_CAPACITY }, (_, i) => (
            <SeCapacitySlot
              key={`reserve-se-${i + 1}`}
              index={i + 1}
              filled={i < MULTI_WEIGHTED_FILLED_SE}
            />
          ))}
        </div>
      </PoolFrame>
    </DiagramShell>
  )
}

/** Filled / dimmed SE capacity cell — shared by multi-leg pool strips. */
function SeCapacitySlot({
  index,
  filled,
  labelPrefix = 'Vault',
}: {
  index: number
  filled: boolean
  labelPrefix?: string
}) {
  return (
    <div
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
        {labelPrefix} {index}
      </p>
      <p
        className={`mt-0.5 text-[9px] leading-tight sm:text-[10px] ${
          filled ? 'text-[var(--text-muted)]' : 'text-[var(--text-muted)]/50'
        }`}
      >
        {filled ? 'vault share' : 'open'}
      </p>
    </div>
  )
}

function PoolSlot({
  title,
  subtitle,
  accent,
  secondary,
  flexClass = 'flex-1',
}: {
  title: string
  subtitle: string
  accent?: boolean
  secondary?: boolean
  flexClass?: string
}) {
  const style = accent ? legAccentStyle : secondary ? legSecondaryStyle : undefined
  const titleClass = secondary ? 'text-amber-100' : 'text-[var(--text-primary)]'
  return (
    <div
      className={`flex min-h-[4.5rem] min-w-0 ${flexClass} flex-col justify-center rounded-lg border px-2 py-2.5 text-center sm:px-2.5`}
      style={style}
    >
      <p className={`text-sm font-medium leading-snug ${titleClass}`}>{title}</p>
      <p className="mt-0.5 text-[9px] leading-tight text-[var(--text-muted)] sm:text-[10px]">
        {subtitle}
      </p>
    </div>
  )
}

/**
 * Multi-Vault Stable (Composed) — reference for locked multi-layer rate-provider layout:
 * top weighted reserve = DETF + Stable BPT + Common BPT;
 * intermediate pools enumerate SE legs; 8 RPs; 4 independent SE vaults; crossing connectors.
 */
const MULTI_STABLE_TOP_SEGMENTS: readonly WeightSegment[] = [
  { width: '50%', label: '~50% DETF', tone: 'accent' },
  { width: '25%', label: '~25% own-mark group', tone: 'secondary' },
  { width: '25%', label: '~25% shared-mark group', tone: 'secondary' },
]

/** Example instance: 4 independent SE vaults → 8 rate providers → 2 intermediate stables. */
const MULTI_STABLE_SE_COUNT = 4

function IntermediateStablePool({
  title,
  rateNote,
}: {
  title: string
  rateNote: string
}) {
  return (
    <div
      className="min-w-0 flex-1 rounded-xl border border-amber-300/40 px-3 py-3"
      style={{
        background: 'color-mix(in srgb, #78350f 18%, var(--surface-0))',
        boxShadow: '0 0 16px rgba(251, 191, 36, 0.08)',
      }}
    >
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-[var(--text-primary)]">
        {title}
      </p>
      <p className="mt-0.5 text-[10px] leading-snug text-[var(--text-muted)]">{rateNote}</p>
      <div className="mt-2.5 flex w-full flex-row items-stretch gap-1 sm:gap-1.5">
        {Array.from({ length: MULTI_STABLE_SE_COUNT }, (_, i) => (
          <SeCapacitySlot
            key={`${title}-se-${i + 1}`}
            index={i + 1}
            filled
            labelPrefix="Vault"
          />
        ))}
      </div>
    </div>
  )
}

function RateProviderBlock({
  seIndex,
  pool,
}: {
  seIndex: number
  pool: 'stable' | 'common'
}) {
  const isStable = pool === 'stable'
  return (
    <div
      className={`flex min-h-[4.25rem] min-w-0 flex-1 flex-col justify-center rounded-lg border px-1.5 py-2 text-center sm:px-2 ${
        isStable ? '' : 'border-amber-300/45 bg-amber-400/15'
      }`}
      style={
        isStable
          ? {
              borderColor: 'color-mix(in srgb, var(--accent) 55%, transparent)',
              background: 'color-mix(in srgb, var(--accent-muted) 82%, transparent)',
              boxShadow: '0 0 12px color-mix(in srgb, var(--accent) 12%, transparent)',
            }
          : undefined
      }
    >
      <p
        className={`font-mono text-[9px] uppercase tracking-wide sm:text-[10px] ${
          isStable ? 'text-[var(--text-primary)]' : 'text-amber-100'
        }`}
      >
        RP {seIndex}
        {isStable ? 'S' : 'C'}
      </p>
      <p className="mt-0.5 text-[9px] leading-tight text-[var(--text-muted)] sm:text-[10px]">
        {isStable ? '→ own-mark' : '→ shared-mark'}
      </p>
      <p className="mt-0.5 text-[8px] leading-tight text-[var(--text-muted)]/80 sm:text-[9px]">
        marks vault {seIndex}
      </p>
    </div>
  )
}

function IndependentSeVaultBlock({ index }: { index: number }) {
  return (
    <div
      className="flex min-h-[4.5rem] min-w-0 flex-1 flex-col justify-center rounded-lg border border-amber-300/45 bg-amber-400/15 px-2 py-2.5 text-center shadow-[0_0_12px_rgba(251,191,36,0.1)]"
    >
      <p className="font-mono text-[10px] uppercase tracking-wide text-amber-100">Vault {index}</p>
      <p className="mt-0.5 text-[9px] leading-snug text-[var(--text-muted)] sm:text-[10px]">
        Independent vault
      </p>
      <p className="mt-1 text-[8px] leading-snug text-[var(--text-muted)]/80 sm:text-[9px]">
        marked two ways
      </p>
    </div>
  )
}

/**
 * Crossing connectors: each SE vault (bottom) → its Stable RP (left group) and Common RP (right group).
 * Percentage geometry matches 4 equal columns under a 4+4 rate-provider row.
 */
function SeToRateProviderCrossConnectors() {
  const seXs = [12.5, 37.5, 62.5, 87.5]
  const stableXs = [6.25, 18.75, 31.25, 43.75]
  const commonXs = [56.25, 68.75, 81.25, 93.75]
  const yTop = 4
  const yBot = 46

  return (
    <svg
      className="pointer-events-none h-14 w-full sm:h-16"
      viewBox="0 0 100 50"
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      {seXs.map((seX, i) => {
        const sX = stableXs[i]
        const cX = commonXs[i]
        return (
          <g key={`cross-${i}`}>
            {/* SE → Stable RP (accent) */}
            <path
              d={`M ${seX} ${yBot} C ${seX} ${(yBot + yTop) / 2}, ${sX} ${(yBot + yTop) / 2}, ${sX} ${yTop}`}
              fill="none"
              stroke="var(--accent)"
              strokeWidth="0.55"
              strokeOpacity="0.75"
            />
            {/* SE → Common RP (amber) — crosses the accent fan */}
            <path
              d={`M ${seX} ${yBot} C ${seX} ${(yBot + yTop) / 2}, ${cX} ${(yBot + yTop) / 2}, ${cX} ${yTop}`}
              fill="none"
              stroke="rgb(251 191 36)"
              strokeWidth="0.55"
              strokeOpacity="0.7"
            />
          </g>
        )
      })}
    </svg>
  )
}

function MultiVaultStableDiagram({ className }: { className?: string }) {
  return (
    <DiagramShell
      className={className}
      title="Several similar vaults, grouped"
      caption="You hold the DETF token. It sits next to two grouped pools of the same vaults. One group marks each vault on its own. The other marks them against one shared target. This is not the one-cash-token design."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF token
        </div>
      </div>
      <Connector />

      <PoolFrame
        label="Reserve: DETF token plus two grouped pools"
        footer={
          <WeightBar
            ariaLabel="Example top-reserve weights: DETF, Stable BPT, Common BPT"
            segments={MULTI_STABLE_TOP_SEGMENTS}
          />
        }
      >
        <div className="flex w-full flex-row items-stretch gap-1.5 sm:gap-2">
          <PoolSlot accent title="DETF token" subtitle="in the reserve" flexClass="flex-[1.1]" />
          <Plus />
          <PoolSlot secondary title="Own-mark group" subtitle="each vault marked on its own" />
          <Plus />
          <PoolSlot secondary title="Shared-mark group" subtitle="one shared target" />
        </div>
      </PoolFrame>

      <Connector label="those groups hold" />

      <div>
        <p className="mb-2.5 text-center font-mono text-[10px] uppercase tracking-[0.12em] text-[var(--text-primary)]">
          Grouped pools. Each lists the vault shares it holds.
        </p>
        <div className="flex w-full flex-col gap-2.5 sm:flex-row sm:items-stretch">
          <IntermediateStablePool
            title="Own-mark pool"
            rateNote="Each vault marked on its own"
          />
          <IntermediateStablePool
            title="Shared-mark pool"
            rateNote="One shared target for every vault"
          />
        </div>
      </div>

      <Connector label="each vault is marked two ways" />

      <div>
        <p className="mb-2 text-center font-mono text-[10px] uppercase tracking-[0.12em] text-[var(--text-primary)]">
          Rate providers: each vault, two marks
        </p>
        <div className="flex w-full flex-row items-stretch gap-1 sm:gap-1.5">
          {Array.from({ length: MULTI_STABLE_SE_COUNT }, (_, i) => (
            <RateProviderBlock key={`rp-s-${i + 1}`} seIndex={i + 1} pool="stable" />
          ))}
          {Array.from({ length: MULTI_STABLE_SE_COUNT }, (_, i) => (
            <RateProviderBlock key={`rp-c-${i + 1}`} seIndex={i + 1} pool="common" />
          ))}
        </div>
      </div>

      {/* Crossing: each SE vault → its Stable RP (left) and Common RP (right) */}
      <div className="-my-0.5 w-full" aria-hidden="true">
        <SeToRateProviderCrossConnectors />
      </div>

      <div>
        <p className="mb-2 text-center font-mono text-[10px] uppercase tracking-[0.12em] text-[var(--text-primary)]">
          Independent vaults, not one grouped set
        </p>
        <div className="flex w-full flex-row items-stretch gap-1.5 sm:gap-2">
          {Array.from({ length: MULTI_STABLE_SE_COUNT }, (_, i) => (
            <IndependentSeVaultBlock key={`se-vault-${i + 1}`} index={i + 1} />
          ))}
        </div>
      </div>
    </DiagramShell>
  )
}

/**
 * Mixed-Buffer Multi-Vault Stable — single MixedBuffer pool:
 * DETF (unpaired) + exactly one buffer token + 1..3 SE vault shares.
 * Reference for locked mixed-buffer strip (not multi-layer RP topology).
 */
const MIXED_BUFFER_SE_CAPACITY = 3
const MIXED_BUFFER_FILLED_SE = 2

const bufferLegStyle: CSSProperties = {
  borderColor: 'rgba(226, 232, 240, 0.35)',
  background: 'color-mix(in srgb, var(--surface-1) 70%, #e2e8f0)',
  boxShadow: '0 0 14px rgba(226, 232, 240, 0.08)',
}

function MixedBufferMultiVaultStableDiagram({ className }: { className?: string }) {
  return (
    <DiagramShell
      className={className}
      title="One cash token plus vaults"
      caption="You hold the DETF token. The reserve holds that token, exactly one cash token, and one to three vaults that all take and give that cash. Mint with cash or a vault share. Burn returns the cash token only."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF token
        </div>
      </div>
      <Connector />

      <PoolFrame label="Reserve: DETF token, one cash token, and vaults">
        <div className="flex w-full flex-row items-stretch gap-1.5 sm:gap-2">
          <div
            className="flex min-h-[4.5rem] min-w-0 flex-[1.15] flex-col justify-center rounded-lg border px-2 py-2.5 text-center sm:px-2.5"
            style={legAccentStyle}
          >
            <p className="text-sm font-medium leading-snug text-[var(--text-primary)]">DETF</p>
            <p className="mt-0.5 text-[9px] leading-tight text-[var(--text-muted)] sm:text-[10px]">
              unpaired self
            </p>
          </div>

          <Plus />

          <div
            className="flex min-h-[4.5rem] min-w-0 flex-[1.2] flex-col justify-center rounded-lg border px-2 py-2.5 text-center sm:px-2.5"
            style={bufferLegStyle}
          >
            <p className="text-sm font-medium leading-snug text-[var(--text-primary)]">Cash token</p>
            <p className="mt-0.5 text-[9px] leading-tight text-[var(--text-muted)] sm:text-[10px]">
              shared cash
            </p>
            <p className="mt-1 text-[8px] leading-tight text-[var(--text-muted)]/90 sm:text-[9px]">
              exactly one · burn returns this
            </p>
          </div>

          {Array.from({ length: MIXED_BUFFER_SE_CAPACITY }, (_, i) => (
            <SeCapacitySlot
              key={`mixed-buffer-se-${i + 1}`}
              index={i + 1}
              filled={i < MIXED_BUFFER_FILLED_SE}
            />
          ))}
        </div>
      </PoolFrame>

      <Connector label="vaults take and give that cash" />

      <div>
        <p className="mb-2 text-center font-mono text-[10px] uppercase tracking-[0.12em] text-[var(--text-primary)]">
          Independent vaults (1–3). Each takes and gives the cash token.
        </p>
        <div className="flex w-full flex-row items-stretch gap-1.5 sm:gap-2">
          {Array.from({ length: MIXED_BUFFER_SE_CAPACITY }, (_, i) => {
            const filled = i < MIXED_BUFFER_FILLED_SE
            return (
              <div
                key={`mb-se-vault-${i + 1}`}
                className={`flex min-h-[4.25rem] min-w-0 flex-1 flex-col justify-center rounded-lg border px-2 py-2.5 text-center ${
                  filled
                    ? 'border-amber-300/45 bg-amber-400/15 shadow-[0_0_12px_rgba(251,191,36,0.1)]'
                    : 'border-dashed border-amber-300/25 bg-transparent'
                }`}
              >
                <p
                  className={`font-mono text-[10px] uppercase tracking-wide ${
                    filled ? 'text-amber-100' : 'text-amber-200/45'
                  }`}
                >
                  Vault {i + 1}
                </p>
                <p
                  className={`mt-0.5 text-[9px] leading-snug sm:text-[10px] ${
                    filled ? 'text-[var(--text-muted)]' : 'text-[var(--text-muted)]/50'
                  }`}
                >
                  {filled ? 'cash in / out' : 'open capacity'}
                </p>
              </div>
            )
          })}
        </div>
      </div>
    </DiagramShell>
  )
}

/**
 * Landing example: three-part Orbital-style basket.
 * Customer copy must not use the package name. Two SE-buffered external legs:
 * Morpho vault marked in USDG, Uniswap V4 USDG/WETH vault marked in WETH.
 */
export function OrbitalMorphoUniv4ExampleDiagram({ className }: { className?: string }) {
  return (
    <DiagramShell
      className={className}
      kicker="Example"
      title="One token, two vaults"
      caption="You hold the DETF token. This example basket holds two vault shares: a Morpho vault marked in USDG, and a Uniswap V4 vault on a USDG/WETH pool marked in WETH. Each vault keeps working in its own app."
    >
      <div className="mb-1 flex justify-center">
        <div
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--text-primary)]"
          style={holdPillStyle}
        >
          You hold → DETF token
        </div>
      </div>
      <Connector />

      <PoolFrame label="Assets behind the token: DETF plus two vault shares">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-stretch sm:gap-2">
          <Leg
            accent
            title="DETF token"
            subtitle="The token you hold. It sits in the basket too."
          />
          <Plus />
          <Leg
            secondary
            title="Morpho vault share"
            subtitle="Marked in USDG"
          />
          <Plus />
          <Leg
            secondary
            title="Uniswap V4 vault share"
            subtitle="Marked in WETH"
          />
        </div>
      </PoolFrame>

      <Connector label="those vaults wrap" />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="rounded-xl border px-4 py-4" style={seBoxStyle}>
          <p className="text-base font-medium text-amber-100">Morpho</p>
          <p className="mt-1.5 text-xs leading-relaxed text-[var(--text-muted)]">
            A vault that takes USDG. The Morpho market keeps that USDG working. The DETF holds the
            vault share, not a raw USDG pile.
          </p>
          <ExampleChips labels={['USDG']} />
        </div>
        <div className="rounded-xl border px-4 py-4" style={seBoxStyle}>
          <p className="text-base font-medium text-amber-100">Uniswap V4</p>
          <p className="mt-1.5 text-xs leading-relaxed text-[var(--text-muted)]">
            A vault on a USDG/WETH pool. The share is marked in WETH. The pool stays a Uniswap V4
            market.
          </p>
          <ExampleChips labels={['USDG/WETH', 'WETH']} />
        </div>
      </div>
    </DiagramShell>
  )
}

export default DetfCompositionDiagram


