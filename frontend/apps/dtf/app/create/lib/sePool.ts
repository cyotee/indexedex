import { sortCurrencies, type Address, ZERO_ADDRESS } from '../../swap/lib/v4Types'

export type PoolVersion = 'v3' | 'v4'

export type V3FeeTier = { fee: number; tickSpacing: number; label: string }

export const V3_FEE_TIERS: readonly V3FeeTier[] = [
  { fee: 100, tickSpacing: 1, label: '0.01%' },
  { fee: 500, tickSpacing: 10, label: '0.05%' },
  { fee: 3000, tickSpacing: 60, label: '0.3%' },
  { fee: 10_000, tickSpacing: 200, label: '1%' },
]

export const V4_FEE_TIERS: readonly V3FeeTier[] = V3_FEE_TIERS

export const SQRT_PRICE_1_1 = 2n ** 96n

export function sortPoolTokens(a: Address, b: Address): [Address, Address] {
  return sortCurrencies(a, b)
}

/** sqrt(token1/token0) in Q64.96. Default 1:1. */
export function sqrtPriceX96FromHuman(price: string): bigint {
  const n = Number(price.trim())
  if (!Number.isFinite(n) || n <= 0) return SQRT_PRICE_1_1
  const scaled = Math.round(Math.sqrt(n) * 2 ** 48)
  if (!Number.isFinite(scaled) || scaled <= 0) return SQRT_PRICE_1_1
  return BigInt(scaled) << 48n
}

export function tickSpacingForV3Fee(fee: number): number {
  return V3_FEE_TIERS.find((t) => t.fee === fee)?.tickSpacing ?? 60
}

export function isZeroAddr(addr: string | undefined): boolean {
  return !addr || addr.toLowerCase() === ZERO_ADDRESS
}

export type PoolReadyState = 'missing' | 'uninitialized' | 'ready'

export function poolReadyState(input: {
  version: PoolVersion
  v3PoolExists: boolean
  v3Initialized: boolean
  v4Exists: boolean
}): PoolReadyState {
  if (input.version === 'v3') {
    if (!input.v3PoolExists) return 'missing'
    if (!input.v3Initialized) return 'uninitialized'
    return 'ready'
  }
  return input.v4Exists ? 'ready' : 'missing'
}

export function poolStatusCopy(state: PoolReadyState): string {
  if (state === 'ready') return 'found'
  if (state === 'uninitialized') return 'created, not initialized'
  return 'not found'
}

export function poolActionLabel(state: PoolReadyState): string {
  if (state === 'uninitialized') return 'Initialize pool'
  return 'Create pool'
}

export function errorText(err: unknown): string {
  if (err == null) return ''
  if (typeof err === 'string') return err
  if (err instanceof Error) return err.message
  if (typeof err === 'object') {
    const o = err as Record<string, unknown>
    if (typeof o.shortMessage === 'string') return o.shortMessage
    if (typeof o.message === 'string') return o.message
    if (o.cause != null) return errorText(o.cause)
  }
  return String(err)
}

/** PoolManager.initialize / V3 initialize when the pool is already live. */
export function isPoolAlreadyExistsError(err: unknown): boolean {
  let current: unknown = err
  for (let i = 0; i < 8 && current != null; i++) {
    if (/already initialized|pool already exists|PoolAlreadyInitialized/i.test(errorText(current))) {
      return true
    }
    if (typeof current === 'object') {
      const o = current as Record<string, unknown>
      const data = o.data
      if (data && typeof data === 'object' && (data as { errorName?: string }).errorName === 'PoolAlreadyInitialized') {
        return true
      }
      current = o.cause
      continue
    }
    break
  }
  return false
}
