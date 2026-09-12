import { keccak256, stringToBytes, type Hex } from 'viem'

import { toPoolId } from '../../swap/lib/v4PoolId'
import {
  sortCurrencies,
  ZERO_ADDRESS,
  type Address,
  type V4PoolKey,
} from '../../swap/lib/v4Types'

/** Matches UniswapV4PoolKeyAwareRepo.STORAGE_SLOT. */
export const UNI_V4_SE_POOL_KEY_SLOT = keccak256(
  stringToBytes('indexedex.protocols.dexes.uniswap.v4.pool.key.aware'),
)

/** Single SE CP-buffer DETF reserve door: fee 0, tick 60, hooks = reserve hook. */
export const DETF_RESERVE_FEE = 0
export const DETF_RESERVE_TICK_SPACING = 60

export type StorageReader = {
  getStorageAt: (args: { address: Address; slot: Hex }) => Promise<Hex | undefined>
}

export type PoolKeyTuple = {
  currency0: Address
  currency1: Address
  fee: number | bigint
  tickSpacing: number | bigint
  hooks: Address
}

function addHex(slot: Hex, n: number): Hex {
  const next = BigInt(slot) + BigInt(n)
  return (`0x${next.toString(16).padStart(64, '0')}`) as Hex
}

function wordToAddress(word: Hex): Address {
  return (`0x${word.slice(-40)}`) as Address
}

function decodeInt24(raw: number): number {
  return raw >= 0x800000 ? raw - 0x1000000 : raw
}

export function decodePackedFeeTickHooks(word: Hex): {
  fee: number
  tickSpacing: number
  hooks: Address
} {
  const v = BigInt(word)
  const mask24 = BigInt(0xffffff)
  const fee = Number(v & mask24)
  const tickSpacing = decodeInt24(Number((v >> BigInt(24)) & mask24))
  const hookBits = (v >> BigInt(48)) & ((BigInt(1) << BigInt(160)) - BigInt(1))
  const hooks = (`0x${hookBits.toString(16).padStart(40, '0')}`) as Address
  return { fee, tickSpacing, hooks }
}

export function isPlausiblePoolKey(key: V4PoolKey): boolean {
  if (key.currency0.toLowerCase() >= key.currency1.toLowerCase()) return false
  if (key.tickSpacing <= 0 || key.tickSpacing > 16_384) return false
  if (key.fee > 1_000_000 && key.fee !== 0x800000) return false
  return true
}

export function decodeSePoolKeySlots(s0: Hex, s1: Hex, s2: Hex): V4PoolKey | null {
  const currency0 = wordToAddress(s0)
  const currency1 = wordToAddress(s1)
  if (currency0 === ZERO_ADDRESS && currency1 === ZERO_ADDRESS) return null
  const packed = decodePackedFeeTickHooks(s2)
  const key: V4PoolKey = {
    currency0,
    currency1,
    fee: packed.fee,
    tickSpacing: packed.tickSpacing,
    hooks: packed.hooks,
  }
  return isPlausiblePoolKey(key) ? key : null
}

export function poolKeyFromTuple(tuple: PoolKeyTuple | undefined | null): V4PoolKey | null {
  if (!tuple) return null
  const c0 = tuple.currency0
  const c1 = tuple.currency1
  if (!c0 || !c1) return null
  if (c0.toLowerCase() === ZERO_ADDRESS && c1.toLowerCase() === ZERO_ADDRESS) return null
  if (c0.toLowerCase() === c1.toLowerCase()) return null
  const [currency0, currency1] = sortCurrencies(c0, c1)
  const key: V4PoolKey = {
    currency0,
    currency1,
    fee: Number(tuple.fee),
    tickSpacing: Number(tuple.tickSpacing),
    hooks: tuple.hooks,
  }
  return isPlausiblePoolKey(key) ? key : null
}

/** Accepts a wagmi tuple or named struct from `listingPoolKey` / `pairPoolKey`. */
export function poolKeyFromUnknown(raw: unknown): V4PoolKey | null {
  if (!raw) return null
  if (Array.isArray(raw) && raw.length >= 5) {
    return poolKeyFromTuple({
      currency0: raw[0] as Address,
      currency1: raw[1] as Address,
      fee: raw[2] as number | bigint,
      tickSpacing: raw[3] as number | bigint,
      hooks: raw[4] as Address,
    })
  }
  if (typeof raw === 'object') {
    const o = raw as Record<string, unknown>
    if (o.currency0 == null || o.currency1 == null) return null
    return poolKeyFromTuple({
      currency0: o.currency0 as Address,
      currency1: o.currency1 as Address,
      fee: o.fee as number | bigint,
      tickSpacing: o.tickSpacing as number | bigint,
      hooks: o.hooks as Address,
    })
  }
  return null
}

export function detfReservePoolKey(args: {
  currency0: Address
  currency1: Address
  hooks: Address
  fee?: number
  tickSpacing?: number
}): V4PoolKey | null {
  return poolKeyFromTuple({
    currency0: args.currency0,
    currency1: args.currency1,
    fee: args.fee ?? DETF_RESERVE_FEE,
    tickSpacing: args.tickSpacing ?? DETF_RESERVE_TICK_SPACING,
    hooks: args.hooks,
  })
}

export function poolIdFromKey(key: V4PoolKey | null): Hex | null {
  if (!key) return null
  return toPoolId(key)
}

/** Read the Uni V4 PoolId stored on an SE vault (PoolKeyAwareRepo). */
export async function readSeVaultPoolId(
  client: StorageReader,
  vault: Address,
): Promise<Hex | null> {
  try {
    const [s0, s1, s2, s3] = await Promise.all([
      client.getStorageAt({ address: vault, slot: UNI_V4_SE_POOL_KEY_SLOT }),
      client.getStorageAt({ address: vault, slot: addHex(UNI_V4_SE_POOL_KEY_SLOT, 1) }),
      client.getStorageAt({ address: vault, slot: addHex(UNI_V4_SE_POOL_KEY_SLOT, 2) }),
      client.getStorageAt({ address: vault, slot: addHex(UNI_V4_SE_POOL_KEY_SLOT, 3) }),
    ])
    if (s3 && /^0x0+$/.test(s3) === false && s3.length === 66) {
      const fromSlot = s3.toLowerCase() as Hex
      const key = s0 && s1 && s2 ? decodeSePoolKeySlots(s0, s1, s2) : null
      if (key) {
        const computed = toPoolId(key)
        if (computed.toLowerCase() === fromSlot) return computed
      }
      return fromSlot
    }
    if (!s0 || !s1 || !s2) return null
    return poolIdFromKey(decodeSePoolKeySlots(s0, s1, s2))
  } catch {
    return null
  }
}
