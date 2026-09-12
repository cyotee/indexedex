export type Address = `0x${string}`

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as Address

export type V4PoolKey = {
  currency0: Address
  currency1: Address
  fee: number
  tickSpacing: number
  hooks: Address
}

export type V4PathKey = {
  intermediateCurrency: Address
  fee: number
  tickSpacing: number
  hooks: Address
  hookData: `0x${string}`
}

export type V4FeeTier = {
  fee: number
  tickSpacing: number
}

/** Canonical Uniswap v4 fee / tick-spacing pairs, plus IndexedEx leaf SE 3000/60. */
export const V4_FEE_TIERS: readonly V4FeeTier[] = [
  { fee: 100, tickSpacing: 1 },
  { fee: 500, tickSpacing: 10 },
  { fee: 3000, tickSpacing: 60 },
  { fee: 10_000, tickSpacing: 200 },
]

export type SwapHop = {
  pool: V4PoolKey
  tokenIn: Address
  tokenOut: Address
  zeroForOne: boolean
}

export type SwapRoute = {
  hops: SwapHop[]
  amountIn: bigint
  amountOut: bigint
}

export function isNativeCurrency(addr: Address | string): boolean {
  return addr.toLowerCase() === ZERO_ADDRESS
}

export function isZeroHook(hooks: Address | string): boolean {
  return hooks.toLowerCase() === ZERO_ADDRESS
}

export function sortCurrencies(a: Address, b: Address): [Address, Address] {
  return a.toLowerCase() < b.toLowerCase() ? [a, b] : [b, a]
}

export function sameAddress(a: Address | string, b: Address | string): boolean {
  return a.toLowerCase() === b.toLowerCase()
}

export function poolKeyId(key: V4PoolKey): string {
  return [
    key.currency0.toLowerCase(),
    key.currency1.toLowerCase(),
    key.fee,
    key.tickSpacing,
    key.hooks.toLowerCase(),
  ].join(':')
}
