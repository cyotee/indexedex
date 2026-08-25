import { getAddress } from 'viem'

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

const ADDR_RE = /^0x[0-9a-fA-F]{40}$/

export type V4PoolKeyFields = {
  currency0: Address
  currency1: Address
  fee: number
  tickSpacing: number
  hooks: Address
}

export function checksumAddress(raw: string): Address | null {
  const t = raw.trim()
  if (!ADDR_RE.test(t)) return null
  try {
    return getAddress(t) as Address
  } catch {
    return null
  }
}

function asAddr(raw: string): Address | null {
  return checksumAddress(raw)
}

/** Uniswap V3 pool contract address. */
export function parseV3PoolAddressInput(raw: string): Address | { error: string } {
  const text = raw.trim()
  if (!text) return { error: 'Paste a pool address first.' }
  const addr = checksumAddress(text)
  if (!addr) return { error: 'Need a 20-byte pool address.' }
  if (addr.toLowerCase() === ZERO_ADDRESS) return { error: 'Pool address cannot be the zero address.' }
  return addr
}

const POOL_ID_RE = /^(0x)?[0-9a-fA-F]{64}$/

/** Uniswap V4 PoolId: keccak256(abi.encode(PoolKey)), 32 bytes. */
export function parseV4PoolIdInput(raw: string): `0x${string}` | { error: string } {
  const text = raw.trim()
  if (!text) return { error: 'Paste a pool ID first.' }
  if (!POOL_ID_RE.test(text)) {
    return { error: 'Need a 32-byte pool ID (0x plus 64 hex characters).' }
  }
  const hex = text.startsWith('0x') || text.startsWith('0X') ? text : `0x${text}`
  return hex.toLowerCase() as `0x${string}`
}

function asInt(raw: unknown, min: number, max: number): number | null {
  const n = typeof raw === 'number' ? raw : Number(String(raw).trim())
  if (!Number.isFinite(n) || !Number.isInteger(n)) return null
  if (n < min || n > max) return null
  return n
}

function finishPoolKey(
  currency0: Address,
  currency1: Address,
  fee: number,
  tickSpacing: number,
  hooks: Address,
): V4PoolKeyFields | { error: string } {
  if (currency0.toLowerCase() === currency1.toLowerCase()) {
    return { error: 'The two pool tokens must be different.' }
  }
  const [c0, c1] = sortPoolTokens(currency0, currency1)
  return { currency0: c0, currency1: c1, fee, tickSpacing, hooks }
}

function parsePoolKeyObject(o: Record<string, unknown>): V4PoolKeyFields | { error: string } {
  const c0 = asAddr(String(o.currency0 ?? o.token0 ?? o.Currency0 ?? ''))
  const c1 = asAddr(String(o.currency1 ?? o.token1 ?? o.Currency1 ?? ''))
  const fee = asInt(o.fee ?? o.lpFee, 0, 0xff_ffff)
  const tickSpacing = asInt(o.tickSpacing ?? o.tick_spacing, 1, 16_383)
  const hooks = asAddr(String(o.hooks ?? o.hook ?? ZERO_ADDRESS))
  if (!c0 || !c1) return { error: 'Need two token addresses in the pool key.' }
  if (!hooks) return { error: 'Hooks must be a 20-byte address.' }
  if (fee == null) return { error: 'Fee must be an integer from 0 to 16777215.' }
  if (tickSpacing == null) return { error: 'Tick spacing must be an integer from 1 to 16383.' }
  return finishPoolKey(c0, c1, fee, tickSpacing, hooks)
}

/** JSON, Solidity tuple, or five comma/space-separated fields. Currencies are sorted. */
export function parseV4PoolKeyInput(raw: string): V4PoolKeyFields | { error: string } {
  const text = raw.trim()
  if (!text) return { error: 'Paste a pool key first.' }

  if (text.startsWith('{') || text.startsWith('[')) {
    try {
      const parsed = JSON.parse(text) as unknown
      if (Array.isArray(parsed)) {
        if (parsed.length !== 5) {
          return { error: 'Use JSON or five fields: token0, token1, fee, tick spacing, hooks.' }
        }
        return parsePoolKeyObject({
          currency0: parsed[0],
          currency1: parsed[1],
          fee: parsed[2],
          tickSpacing: parsed[3],
          hooks: parsed[4],
        })
      }
      const obj =
        parsed && typeof parsed === 'object'
          ? ((parsed as { key?: unknown }).key && typeof (parsed as { key?: unknown }).key === 'object'
              ? ((parsed as { key: Record<string, unknown> }).key)
              : (parsed as Record<string, unknown>))
          : null
      if (!obj) return { error: 'JSON pool key must be an object.' }
      return parsePoolKeyObject(obj)
    } catch {
      return { error: 'That JSON is not valid.' }
    }
  }

  const stripped = text.replace(/^[(\[]/, '').replace(/[)\]]$/, '')
  const parts = stripped
    .split(/[,;\n]+/)
    .map((p) => p.trim())
    .filter(Boolean)
    .map((p) => p.replace(/["']/g, ''))
  if (parts.length !== 5) {
    return {
      error: 'Use JSON or five fields: token0, token1, fee, tick spacing, hooks.',
    }
  }
  const c0 = asAddr(parts[0]!)
  const c1 = asAddr(parts[1]!)
  const fee = asInt(parts[2], 0, 0xff_ffff)
  const tickSpacing = asInt(parts[3], 1, 16_383)
  const hooks = asAddr(parts[4]!)
  if (!c0 || !c1) return { error: 'Need two token addresses in the pool key.' }
  if (!hooks) return { error: 'Hooks must be a 20-byte address.' }
  if (fee == null) return { error: 'Fee must be an integer from 0 to 16777215.' }
  if (tickSpacing == null) return { error: 'Tick spacing must be an integer from 1 to 16383.' }
  return finishPoolKey(c0, c1, fee, tickSpacing, hooks)
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
