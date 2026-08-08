'use client'

import { useCallback, useMemo, useState } from 'react'

import { Button } from '../ui/Button'
import { Card } from '../ui/Card'
import {
  sanitizeSharePosition,
  sharePositionPlainText,
  type SharePositionInput,
  type SanitizedSharePosition,
} from '../../lib/portfolio/sanitizeShareFields'

export type SharePositionCardProps = SharePositionInput & {
  className?: string
  /** Compact: actions only without large preview (table rows). */
  compact?: boolean
}

/**
 * Sanitized share card for Portfolio positions / bond NFTs.
 * Renders only symbol / amount / address / optional detail — never raw tokenURI HTML/SVG.
 * Culture subtitle is off by default (showCulture must be true).
 */
export function SharePositionCard(props: SharePositionCardProps) {
  const { className = '', compact = false, ...input } = props
  // Depend on primitive fields so memo invalidates when parent rebuilds objects.
  const fields = useMemo(
    () =>
      sanitizeSharePosition({
        kind: input.kind,
        symbol: input.symbol,
        amountLabel: input.amountLabel,
        address: input.address,
        detailLabel: input.detailLabel,
        brandName: input.brandName,
        cultureLine: input.cultureLine,
        showCulture: input.showCulture,
      }),
    [
      input.kind,
      input.symbol,
      input.amountLabel,
      input.address,
      input.detailLabel,
      input.brandName,
      input.cultureLine,
      input.showCulture,
    ],
  )
  const [status, setStatus] = useState<string | null>(null)

  const plain = useMemo(() => sharePositionPlainText(fields), [fields])

  const copyText = useCallback(async () => {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(plain)
      } else {
        const ta = document.createElement('textarea')
        ta.value = plain
        ta.setAttribute('readonly', '')
        ta.style.position = 'fixed'
        ta.style.left = '-9999px'
        document.body.appendChild(ta)
        ta.select()
        document.execCommand('copy')
        document.body.removeChild(ta)
      }
      setStatus('Copied summary')
    } catch {
      setStatus('Copy failed')
    }
  }, [plain])

  const downloadPng = useCallback(async () => {
    try {
      const blob = await renderSharePng(fields)
      if (!blob) {
        setStatus('Image failed')
        return
      }
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `position-${fields.symbol}-${Date.now()}.png`
      a.click()
      URL.revokeObjectURL(url)
      setStatus('Downloaded PNG')
    } catch {
      setStatus('Image failed')
    }
  }, [fields])

  const kindLabel =
    fields.kind === 'bond-nft'
      ? 'Bond'
      : fields.kind === 'detf-share'
        ? 'DETF'
        : 'Vault share'

  return (
    <div className={className} data-testid="share-position-card">
      {!compact ? (
        <Card
          className="mb-3 border-[var(--border-accent,rgba(79,212,75,0.35))]"
          data-testid="share-position-preview"
        >
          <p className="text-[10px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">
            {fields.brandName} · {kindLabel}
          </p>
          <p className="mt-2 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">
            {fields.symbol}
          </p>
          <p className="mt-1 font-mono text-base tabular-nums text-[var(--text-primary,#EDEDED)]">
            {fields.amountLabel}
          </p>
          {fields.detailLabel ? (
            <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{fields.detailLabel}</p>
          ) : null}
          {fields.address ? (
            <p className="mt-1 font-mono text-xs text-[var(--text-muted,#9aa3b2)] break-all">
              {fields.address}
            </p>
          ) : null}
          {fields.showCulture && fields.cultureLine ? (
            <p className="mt-3 text-xs italic text-[var(--text-muted,#9aa3b2)]">{fields.cultureLine}</p>
          ) : null}
          <p className="mt-3 text-[10px] text-[var(--text-muted,#9aa3b2)]">
            Amounts are not guarantees. Share uses sanitized fields only.
          </p>
        </Card>
      ) : null}

      <div className="flex flex-wrap items-center gap-2">
        <Button type="button" variant="secondary" size="sm" onClick={copyText}>
          Copy summary
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={downloadPng}>
          Download PNG
        </Button>
        {status ? (
          <span className="text-xs text-[var(--text-muted,#9aa3b2)]" role="status">
            {status}
          </span>
        ) : null}
      </div>
    </div>
  )
}

/**
 * Draw PNG from sanitized text only (no HTML, no tokenURI, no external images).
 */
async function renderSharePng(fields: SanitizedSharePosition): Promise<Blob | null> {
  if (typeof document === 'undefined') return null
  const w = 720
  const h = 400
  const canvas = document.createElement('canvas')
  canvas.width = w
  canvas.height = h
  const ctx = canvas.getContext('2d')
  if (!ctx) return null

  // Dark surface (brand-agnostic, no untrusted fills)
  ctx.fillStyle = '#0a0a0a'
  ctx.fillRect(0, 0, w, h)
  ctx.strokeStyle = 'rgba(79, 212, 75, 0.45)'
  ctx.lineWidth = 2
  ctx.strokeRect(16, 16, w - 32, h - 32)

  ctx.fillStyle = '#4FD44B'
  ctx.font = '600 14px ui-sans-serif, system-ui, sans-serif'
  const kind =
    fields.kind === 'bond-nft' ? 'Bond' : fields.kind === 'detf-share' ? 'DETF' : 'Vault share'
  ctx.fillText(`${fields.brandName} · ${kind}`, 40, 60)

  ctx.fillStyle = '#EDEDED'
  ctx.font = '600 32px ui-sans-serif, system-ui, sans-serif'
  ctx.fillText(fields.symbol, 40, 110)

  ctx.font = '500 28px ui-monospace, SFMono-Regular, Menlo, monospace'
  ctx.fillText(fields.amountLabel, 40, 160)

  ctx.fillStyle = '#9aa3b2'
  ctx.font = '400 16px ui-sans-serif, system-ui, sans-serif'
  let y = 200
  if (fields.detailLabel) {
    ctx.fillText(fields.detailLabel, 40, y)
    y += 28
  }
  if (fields.address) {
    ctx.font = '400 14px ui-monospace, SFMono-Regular, Menlo, monospace'
    ctx.fillText(fields.address, 40, y)
    y += 28
  }
  if (fields.showCulture && fields.cultureLine) {
    ctx.font = 'italic 14px ui-sans-serif, system-ui, sans-serif'
    ctx.fillText(fields.cultureLine, 40, y)
    y += 28
  }
  ctx.font = '400 12px ui-sans-serif, system-ui, sans-serif'
  ctx.fillText('Amounts are not guarantees.', 40, h - 48)

  return new Promise((resolve) => {
    canvas.toBlob((b) => resolve(b), 'image/png')
  })
}

export default SharePositionCard
