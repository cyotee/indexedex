import type { Address } from './v4Types'
import { ZERO_ADDRESS } from './v4Types'

/**
 * Canonical Uniswap v4 periphery on Robinhood (4663) and Robinhood Testnet (46630).
 * Same CREATE2 addresses on both. Prefer platform.json when a key is present.
 */
export const ROBINHOOD_UNISWAP_V4 = {
  poolManager: '0x8366a39CC670B4001A1121B8F6A443A643e40951' as Address,
  positionManager: '0x58daec3116aae6D93017bAAea7749052E8a04fA7' as Address,
  quoter: '0x8Dc178eFB8111BB0973Dd9d722ebeFF267c98F94' as Address,
  stateView: '0xF3334192D15450CdD385c8B70e03f9A6bD9E673b' as Address,
  universalRouter: '0x8876789976dEcBfCbBbe364623C63652db8C0904' as Address,
  permit2: '0x000000000022D473030F116dDEE9F6B43aC78BA3' as Address,
} as const

export type V4PlatformAddrs = {
  universalRouter: Address | null
  permit2: Address | null
  poolManager: Address | null
  quoter: Address | null
  stateView: Address | null
  weth: Address | null
}

function asAddr(value: unknown): Address | null {
  if (typeof value !== 'string') return null
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) return null
  if (value.toLowerCase() === ZERO_ADDRESS) return null
  return value as Address
}

export function resolveV4Platform(platform: Record<string, unknown> | null | undefined): V4PlatformAddrs {
  const p = platform ?? {}
  const onRobinhoodLike = true
  const fallback = onRobinhoodLike ? ROBINHOOD_UNISWAP_V4 : null
  return {
    universalRouter: asAddr(p.universalRouter) ?? fallback?.universalRouter ?? null,
    permit2: asAddr(p.permit2) ?? fallback?.permit2 ?? null,
    poolManager: asAddr(p.poolManager) ?? fallback?.poolManager ?? null,
    quoter: asAddr(p.v4Quoter) ?? asAddr(p.quoter) ?? fallback?.quoter ?? null,
    stateView: asAddr(p.v4StateView) ?? asAddr(p.stateView) ?? fallback?.stateView ?? null,
    weth: asAddr(p.weth9) ?? asAddr(p.weth) ?? null,
  }
}
