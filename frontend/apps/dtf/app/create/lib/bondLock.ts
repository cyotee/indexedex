export const DAY_SECONDS = 86_400
export const FALLBACK_MIN_LOCK_DAYS = 30
export const FALLBACK_MAX_LOCK_DAYS = 180

export type BondLockTerms = {
  minLockDuration: bigint
  maxLockDuration: bigint
}

export function daysFromLockSeconds(seconds: bigint): number {
  if (seconds <= 0n) return 0
  const days = Number(seconds / BigInt(DAY_SECONDS))
  return Number.isFinite(days) ? days : 0
}

export function lockSecondsFromDays(days: number): bigint {
  return BigInt(Math.max(0, Math.floor(days))) * BigInt(DAY_SECONDS)
}

export function lockRangeFromBondTerms(terms: BondLockTerms | undefined | null): {
  minDays: number
  maxDays: number
} {
  if (!terms) return { minDays: FALLBACK_MIN_LOCK_DAYS, maxDays: FALLBACK_MAX_LOCK_DAYS }
  const minDays = Math.max(1, daysFromLockSeconds(terms.minLockDuration))
  const maxDays = Math.max(minDays, daysFromLockSeconds(terms.maxLockDuration))
  if (terms.minLockDuration === 0n && terms.maxLockDuration === 0n) {
    return { minDays: FALLBACK_MIN_LOCK_DAYS, maxDays: FALLBACK_MAX_LOCK_DAYS }
  }
  return { minDays, maxDays }
}

export function asBondLockTerms(raw: unknown): BondLockTerms | null {
  if (raw == null) return null
  if (Array.isArray(raw) && raw.length >= 2) {
    try {
      return {
        minLockDuration: BigInt(raw[0] as bigint),
        maxLockDuration: BigInt(raw[1] as bigint),
      }
    } catch {
      return null
    }
  }
  if (typeof raw === 'object' && 'minLockDuration' in (raw as object) && 'maxLockDuration' in (raw as object)) {
    const o = raw as { minLockDuration: bigint; maxLockDuration: bigint }
    try {
      return {
        minLockDuration: BigInt(o.minLockDuration),
        maxLockDuration: BigInt(o.maxLockDuration),
      }
    } catch {
      return null
    }
  }
  return null
}

export function clampLockDays(raw: string, minDays: number, maxDays: number): number | null {
  const n = Math.floor(Number(raw))
  if (!Number.isFinite(n)) return null
  if (n < minDays || n > maxDays) return null
  return n
}
