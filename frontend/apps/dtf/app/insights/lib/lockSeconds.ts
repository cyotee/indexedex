export const MIN_LOCK_DAYS = 1
export const MAX_LOCK_DAYS = 180
const DAY = BigInt(86400)

export function lockSecondsFromDays(raw: string): bigint | null {
  const n = Math.floor(Number(raw))
  if (!Number.isFinite(n) || n < MIN_LOCK_DAYS || n > MAX_LOCK_DAYS) return null
  return BigInt(n) * DAY
}
