import { formatUnits, getAddress, isAddress, parseUnits } from 'viem'

const DAY_SECONDS = 86_400n

function trimZeros(raw: string): string {
  if (!raw.includes('.')) return raw
  return raw.replace(/\.?0+$/, '')
}

/** WAD percents: 1e18 = 100%, 1e16 = 1%, 1e15 = 0.1%. Stored 0 = unset unless `zeroMeansZero`. */
export function formatWadPercent(
  wad: bigint | undefined | null,
  opts: { zeroMeansZero?: boolean } = {},
): string {
  if (wad == null) return '—'
  if (wad === 0n && !opts.zeroMeansZero) return 'Unset'
  return `${trimZeros(formatUnits(wad, 16))}%`
}

/** Parse a human percent ("0.1", "5", "100") to WAD. */
export function parsePercentToWad(raw: string): bigint | null {
  const t = raw.trim()
  if (!t) return null
  try {
    const wad = parseUnits(t, 16)
    if (wad > 10n ** 18n) return null
    return wad
  } catch {
    return null
  }
}

export function formatLockDuration(seconds: bigint | undefined | null): string {
  if (seconds == null) return '—'
  if (seconds === 0n) return 'Unset'
  const days = seconds / DAY_SECONDS
  const rem = seconds % DAY_SECONDS
  if (rem === 0n) return days === 1n ? '1 day' : `${days.toString()} days`
  if (days === 0n) return `${seconds.toString()} seconds`
  return `${days.toString()} days + ${rem.toString()} seconds`
}

export function parseDaysToSeconds(raw: string): bigint | null {
  const t = raw.trim()
  if (!t) return null
  const n = Number(t)
  if (!Number.isFinite(n) || n < 0) return null
  return BigInt(Math.floor(n)) * DAY_SECONDS
}

export function parseTypeId(raw: string): `0x${string}` | null {
  const t = raw.trim()
  if (!/^0x[0-9a-fA-F]{8}$/.test(t)) return null
  return t.toLowerCase() as `0x${string}`
}

export function parseEthAddress(raw: string): `0x${string}` | null {
  const t = raw.trim()
  if (!isAddress(t)) return null
  return getAddress(t)
}

export function uniqueTypeIds(lists: readonly (readonly `0x${string}`[] | undefined)[]): `0x${string}`[] {
  const seen = new Set<string>()
  const out: `0x${string}`[] = []
  for (const list of lists) {
    if (!list) continue
    for (const id of list) {
      const key = id.toLowerCase()
      if (key === '0x00000000') continue
      if (seen.has(key)) continue
      seen.add(key)
      out.push(id)
    }
  }
  return out
}
