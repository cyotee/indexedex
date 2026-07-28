import type { CSSProperties, ReactNode } from 'react'

import type { ResearchDiagramId } from '../../../content/research/types'

type Props = {
  id: ResearchDiagramId
  className?: string
}

/**
 * Composition diagrams for DETF research notes.
 * Iterate style on single-standard-exchange first; clone for other types later.
 */
export function DetfCompositionDiagram({ id, className = '' }: Props) {
  switch (id) {
    case 'single-standard-exchange':
      return <SingleStandardExchangeDiagram className={className} />
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
      <p className="mb-3.5 font-mono text-[10px] uppercase tracking-[0.14em] text-[var(--accent)]">
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

const legSecondaryStyle: CSSProperties = {
  borderColor: 'rgba(103, 232, 249, 0.45)',
  background: 'color-mix(in srgb, #0e7490 24%, var(--surface-0))',
  boxShadow: '0 0 18px rgba(34, 211, 238, 0.14)',
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

  const titleClass =
    tone === 'accent'
      ? 'text-[var(--accent)]'
      : tone === 'secondary'
        ? 'text-cyan-200'
        : 'text-[var(--text-primary)]'

  const weightClass =
    tone === 'accent'
      ? 'bg-[var(--accent)] text-[var(--surface-0)]'
      : tone === 'secondary'
        ? 'bg-cyan-300 text-[var(--surface-0)]'
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

function WeightBar({ leftLabel, rightLabel }: { leftLabel: string; rightLabel: string }) {
  return (
    <div>
      <div
        className="flex h-2.5 overflow-hidden rounded-full"
        role="img"
        aria-label={`Default weights: ${leftLabel} DETF, ${rightLabel} SE vault share`}
        style={{
          boxShadow: '0 0 0 1px color-mix(in srgb, var(--accent) 30%, transparent)',
        }}
      >
        <div className="h-full bg-[var(--accent)]" style={{ width: '80%' }} title={leftLabel} />
        <div className="h-full bg-cyan-300" style={{ width: '20%' }} title={rightLabel} />
      </div>
      <div className="mt-2 flex justify-between font-mono text-[10px] uppercase tracking-wide">
        <span className="text-[var(--accent)]">{leftLabel} DETF</span>
        <span className="text-cyan-200">{rightLabel} SE share</span>
      </div>
    </div>
  )
}

/** Illustrative backends only — SE is the standard adapter, not this short list. */
const SE_VAULT_EXAMPLES = ['Uniswap V4', 'Euler'] as const

function ExampleChips({ labels }: { labels: readonly string[] }) {
  return (
    <div className="mt-3.5">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-cyan-200/80">
        Example integrations
      </p>
      <ul className="mt-2 flex flex-wrap gap-1.5">
        {labels.map((label) => (
          <li
            key={label}
            className="rounded-full border border-cyan-300/40 bg-cyan-400/15 px-2.5 py-0.5 font-mono text-[10px] uppercase tracking-wide text-cyan-100"
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
  borderColor: 'rgba(103, 232, 249, 0.4)',
  background: 'color-mix(in srgb, #0e7490 20%, var(--surface-0))',
  boxShadow: '0 0 22px rgba(34, 211, 238, 0.12)',
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
          className="rounded-full border px-3.5 py-1.5 font-mono text-[10px] uppercase tracking-wide text-[var(--accent)]"
          style={holdPillStyle}
        >
          You hold → DETF share (ERC-20)
        </div>
      </div>
      <Connector />

      <PoolFrame
        label="Weighted reserve pool (Balancer V3)"
        footer={<WeightBar leftLabel="~80%" rightLabel="~20%" />}
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
          <Leg
            accent
            title="DETF (self)"
            subtitle="This diamond’s own share token in the pool"
            weight="Default ~80%"
          />
          <div
            className="flex items-center justify-center font-mono text-sm font-semibold text-[var(--accent)] sm:px-1.5"
            aria-hidden="true"
          >
            +
          </div>
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
        <p className="text-base font-medium text-cyan-100">Standard Exchange vault</p>
        <p className="mt-1.5 text-xs leading-relaxed text-[var(--text-muted)]">
          Vault standard — not a DETF type. Same deposit / share / redeem interface wrapping an
          external protocol. The DETF holds the SE share only; Uni or Euler stay behind the vault.
        </p>
        <ExampleChips labels={SE_VAULT_EXAMPLES} />
      </div>
    </DiagramShell>
  )
}

export default DetfCompositionDiagram
