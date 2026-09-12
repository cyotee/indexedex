/**
 * Sanitizers for SharePositionCard.
 * Only allow safe symbol / numeric / address strings — never raw tokenURI HTML/SVG.
 */

const MAX_SYMBOL = 32
const MAX_AMOUNT = 48
const MAX_LABEL = 64
const MAX_CULTURE = 120

/** Strip control chars and angle brackets that could inject markup. */
export function stripUnsafeText(raw: string, maxLen: number): string {
  return raw
    .replace(/[\u0000-\u001F\u007F<>`]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLen)
}

/** Token symbols: must start with a letter; digits allowed after (e.g. USDC2). */
export function sanitizeShareSymbol(raw: unknown): string {
  if (typeof raw !== 'string') return '—'
  const cleaned = stripUnsafeText(raw, MAX_SYMBOL * 2)
  // Prefer trailing ticker-like tokens (junk…WETH → WETH). Reject leading-digit debris.
  const tokens = cleaned.match(/[A-Za-z][A-Za-z0-9._$+\-]{0,31}/g)
  if (!tokens?.length) return '—'
  return tokens[tokens.length - 1]!.slice(0, MAX_SYMBOL)
}

/** Pre-formatted amount strings (from formatUnits / formatBondAmount). */
export function sanitizeShareAmount(raw: unknown): string {
  if (typeof raw !== 'string' && typeof raw !== 'number') return '—'
  const s = stripUnsafeText(String(raw), MAX_AMOUNT)
  // Allow decimal amounts and common placeholders
  if (s === '—' || s === '-') return '—'
  if (!/^[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$/.test(s) && !/^[0-9]+(\.[0-9]+)?\s+[A-Za-z0-9._$+\-]{1,16}$/.test(s)) {
    // Pure numeric or "1.23 SYM" only — reject HTML-ish leftovers
    const numOnly = s.match(/^[0-9]+(\.[0-9]+)?/)
    return numOnly?.[0] ?? '—'
  }
  return s
}

/** EIP-55 or lowercase 0x address; otherwise empty. */
export function sanitizeShareAddress(raw: unknown): `0x${string}` | '' {
  if (typeof raw !== 'string') return ''
  const s = raw.trim()
  if (!/^0x[0-9a-fA-F]{40}$/.test(s)) return ''
  return s as `0x${string}`
}

export function sanitizeShareLabel(raw: unknown): string {
  if (typeof raw !== 'string') return ''
  return stripUnsafeText(raw, MAX_LABEL)
}

/** Culture line — optional, still sanitized; caller must pass showCulture. */
export function sanitizeShareCulture(raw: unknown): string {
  if (typeof raw !== 'string') return ''
  return stripUnsafeText(raw, MAX_CULTURE)
}

export type SharePositionKind = 'vault-share' | 'detf-share' | 'bond-nft'

export type SharePositionInput = {
  kind: SharePositionKind
  symbol: string
  /** Human amount only (already formatUnits); never raw wei as primary field. */
  amountLabel: string
  address?: string
  /** e.g. Bond #12 or product name */
  detailLabel?: string
  brandName?: string
  cultureLine?: string
  showCulture?: boolean
}

export type SanitizedSharePosition = {
  kind: SharePositionKind
  symbol: string
  amountLabel: string
  address: `0x${string}` | ''
  detailLabel: string
  brandName: string
  cultureLine: string
  showCulture: boolean
}

export function sanitizeSharePosition(input: SharePositionInput): SanitizedSharePosition {
  const showCulture = Boolean(input.showCulture)
  return {
    kind: input.kind,
    symbol: sanitizeShareSymbol(input.symbol),
    amountLabel: sanitizeShareAmount(input.amountLabel),
    address: sanitizeShareAddress(input.address),
    detailLabel: sanitizeShareLabel(input.detailLabel ?? ''),
    brandName: sanitizeShareLabel(input.brandName ?? '') || 'Indexed liquidity',
    cultureLine: showCulture ? sanitizeShareCulture(input.cultureLine ?? '') : '',
    showCulture,
  }
}

export function sharePositionPlainText(fields: SanitizedSharePosition): string {
  const kindLabel =
    fields.kind === 'bond-nft'
      ? 'Bond position'
      : fields.kind === 'detf-share'
        ? 'DETF balance'
        : 'Vault share'
  const lines = [
    `${fields.brandName} · ${kindLabel}`,
    `${fields.symbol}: ${fields.amountLabel}`,
  ]
  if (fields.detailLabel) lines.push(fields.detailLabel)
  if (fields.address) lines.push(fields.address)
  if (fields.showCulture && fields.cultureLine) lines.push(fields.cultureLine)
  lines.push('Amounts are not guarantees.')
  return lines.join('\n')
}
