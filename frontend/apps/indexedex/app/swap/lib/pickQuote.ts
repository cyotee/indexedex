import type { UniswapApiQuote } from './uniswapTradeApi'
import type { SwapRoute } from './v4Types'
import { isZeroHook } from './v4Types'

export type QuotePick = 'local' | 'uniswap'

/**
 * Prefer the IndexedEx/local route when it uses a hooked pool Uniswap may skip.
 * Otherwise take the larger amountOut (Uniswap Trading API vs local v4 graph).
 */
export function pickQuote(local: SwapRoute | null, uni: UniswapApiQuote | null): QuotePick | null {
  if (!local && !uni) return null
  if (local && !uni) return 'local'
  if (!local && uni) return 'uniswap'
  const loc = local!
  const remote = uni!
  const hooked = loc.hops.some((h) => !isZeroHook(h.pool.hooks))
  if (hooked) {
    if (remote.amountOut * BigInt(100) > loc.amountOut * BigInt(102)) return 'uniswap'
    return 'local'
  }
  return remote.amountOut > loc.amountOut ? 'uniswap' : 'local'
}
