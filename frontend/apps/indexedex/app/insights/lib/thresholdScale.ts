/** Map burn / price / mint (WAD) onto a 0–100 gauge. Honest snapshot, not a history. */

export type ThresholdScale = {
  burnPct: number
  pricePct: number
  mintPct: number
  /** Mint and burn both allowed regardless of price (Open). */
  openMode: boolean
  inert: boolean
}

const WAD = BigInt('1000000000000000000')

function clampPct(n: number): number {
  if (!Number.isFinite(n)) return 50
  return Math.min(100, Math.max(0, n))
}

function toPct(value: bigint, min: bigint, span: bigint): number {
  if (span <= BigInt(0)) return 50
  const raw = Number((value - min) * BigInt(10000) / span) / 100
  return clampPct(raw)
}

export function scaleThresholds(
  burn: bigint | undefined,
  price: bigint | undefined,
  mint: bigint | undefined,
): ThresholdScale {
  if (price == null || price <= BigInt(0)) {
    return { burnPct: 20, pricePct: 50, mintPct: 80, openMode: false, inert: true }
  }
  const burnV = burn ?? BigInt(0)
  const mintV = mint ?? WAD
  const openMode = mintV <= WAD / BigInt(100) && burnV >= WAD * BigInt(99) / BigInt(100)
  const values = [burnV, price, mintV]
  let min = values[0]!
  let max = values[0]!
  for (let i = 1; i < values.length; i++) {
    const v = values[i]!
    if (v < min) min = v
    if (v > max) max = v
  }
  const pad = (max - min) / BigInt(10) || WAD / BigInt(20)
  min = min > pad ? min - pad : BigInt(0)
  max = max + pad
  const span = max - min
  return {
    burnPct: toPct(burnV, min, span),
    pricePct: toPct(price, min, span),
    mintPct: toPct(mintV, min, span),
    openMode,
    inert: false,
  }
}

export function formatWad(value: bigint | undefined, digits = 4): string {
  if (value == null) return '—'
  const neg = value < BigInt(0)
  const abs = neg ? -value : value
  const whole = abs / WAD
  const frac = abs % WAD
  const fracStr = frac.toString().padStart(18, '0').slice(0, digits)
  const trimmed = fracStr.replace(/0+$/, '')
  const body = trimmed.length > 0 ? `${whole.toString()}.${trimmed}` : whole.toString()
  return neg ? `-${body}` : body
}
