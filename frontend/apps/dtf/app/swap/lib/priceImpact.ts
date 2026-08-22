/**
 * Uniswap-style price impact from a v4 slot0 mid vs the quoted execution price.
 * Returns basis points (50 = 0.50%). Null when the math is not defined.
 */
export function priceImpactBps(args: {
  amountIn: bigint
  amountOut: bigint
  sqrtPriceX96: bigint
  zeroForOne: boolean
}): number | null {
  const { amountIn, amountOut, sqrtPriceX96, zeroForOne } = args
  if (amountIn <= BigInt(0) || amountOut <= BigInt(0) || sqrtPriceX96 <= BigInt(0)) return null

  const q96 = BigInt(1) << BigInt(96)
  const spotX192 = sqrtPriceX96 * sqrtPriceX96
  const q192 = q96 * q96

  let execNum: bigint
  let execDen: bigint
  let spotNum: bigint
  let spotDen: bigint
  if (zeroForOne) {
    execNum = amountOut
    execDen = amountIn
    spotNum = spotX192
    spotDen = q192
  } else {
    execNum = amountOut
    execDen = amountIn
    spotNum = q192
    spotDen = spotX192
  }

  if (spotNum === BigInt(0) || execDen === BigInt(0)) return null
  const execScaled = execNum * spotDen
  const spotScaled = spotNum * execDen
  if (spotScaled === BigInt(0)) return null
  if (execScaled >= spotScaled) return 0
  const diff = spotScaled - execScaled
  const bps = Number((diff * BigInt(10_000)) / spotScaled)
  if (!Number.isFinite(bps) || bps < 0) return null
  return Math.min(bps, 10_000)
}

export function formatPriceImpact(bps: number | null): string | null {
  if (bps == null) return null
  const pct = bps / 100
  if (pct < 0.01) return '<0.01%'
  return `${pct.toFixed(2)}%`
}
