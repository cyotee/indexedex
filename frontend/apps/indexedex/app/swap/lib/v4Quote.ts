import type { PublicClient } from 'viem'

import { V4_QUOTER_ABI } from './v4Abis'
import { pathFromRoute } from './v4Encode'
import { findCandidatePaths } from './v4Route'
import type { Address, SwapRoute, V4PoolKey } from './v4Types'

export type QuoteReader = Pick<PublicClient, 'simulateContract'>

async function quotePath(
  client: QuoteReader,
  quoter: Address,
  hops: SwapRoute['hops'],
  amountIn: bigint,
  account?: Address,
): Promise<bigint | null> {
  if (hops.length === 0) return null
  try {
    if (hops.length === 1) {
      const hop = hops[0]!
      const { result } = await client.simulateContract({
        address: quoter,
        abi: V4_QUOTER_ABI,
        functionName: 'quoteExactInputSingle',
        args: [
          {
            poolKey: hop.pool,
            zeroForOne: hop.zeroForOne,
            exactAmount: amountIn,
            hookData: '0x',
          },
        ],
        account,
      })
      const amountOut = result[0]
      return amountOut > BigInt(0) ? amountOut : null
    }
    const path = pathFromRoute({ hops, amountIn, amountOut: BigInt(0) })
    const { result } = await client.simulateContract({
      address: quoter,
      abi: V4_QUOTER_ABI,
      functionName: 'quoteExactInput',
      args: [
        {
          exactCurrency: hops[0]!.tokenIn,
          path,
          exactAmount: amountIn,
        },
      ],
      account,
    })
    const amountOut = result[0]
    return amountOut > BigInt(0) ? amountOut : null
  } catch {
    return null
  }
}

export async function quoteBestRoute(args: {
  client: QuoteReader
  quoter: Address
  pools: V4PoolKey[]
  tokenIn: Address
  tokenOut: Address
  amountIn: bigint
  account?: Address
  maxHops?: number
}): Promise<SwapRoute | null> {
  const { client, quoter, pools, tokenIn, tokenOut, amountIn, account, maxHops = 3 } = args
  if (amountIn <= BigInt(0)) return null
  const candidates = findCandidatePaths(pools, tokenIn, tokenOut, maxHops)
  if (candidates.length === 0) return null

  let best: SwapRoute | null = null
  for (const path of candidates) {
    const amountOut = await quotePath(client, quoter, path.hops, amountIn, account)
    if (amountOut == null) continue
    if (!best || amountOut > best.amountOut) {
      best = { hops: path.hops, amountIn, amountOut }
    }
  }
  return best
}
