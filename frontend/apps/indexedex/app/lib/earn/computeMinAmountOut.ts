/**
 * Slippage floor from a real preview amountOut.
 * Never invent minOut from % of amountIn alone.
 *
 * @param amountOut - preview quote (bigint). Missing → 0 (caller must disable execute).
 * @param slippagePercent - percent points, e.g. 0.5 for 0.5%. Clamped to [0, 5].
 */
export function computeMinAmountOut(
  amountOut: bigint | undefined | null,
  slippagePercent: number,
): bigint {
  if (amountOut == null || amountOut <= BigInt(0)) return BigInt(0)
  const clamped = Number.isFinite(slippagePercent)
    ? Math.min(5, Math.max(0, slippagePercent))
    : 0.5
  const slippageBps = BigInt(Math.floor(clamped * 100))
  // bps of 10000; 0.5% → 50 bps
  return (amountOut * (BigInt(10000) - slippageBps)) / BigInt(10000)
}

export const DEFAULT_SLIPPAGE_PERCENT = 0.5
