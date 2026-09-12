import type { Address, SwapHop, V4PoolKey } from './v4Types'
import { poolKeyId, sameAddress, sortCurrencies } from './v4Types'

export type CandidatePath = {
  hops: SwapHop[]
}

function hopFromPool(pool: V4PoolKey, tokenIn: Address): SwapHop | null {
  const inLc = tokenIn.toLowerCase()
  const c0 = pool.currency0.toLowerCase()
  const c1 = pool.currency1.toLowerCase()
  if (inLc === c0) {
    return { pool, tokenIn: pool.currency0, tokenOut: pool.currency1, zeroForOne: true }
  }
  if (inLc === c1) {
    return { pool, tokenIn: pool.currency1, tokenOut: pool.currency0, zeroForOne: false }
  }
  return null
}

/**
 * BFS over live V4 pools. No hook allowlist — every discovered PoolKey is eligible.
 * Caps hop count (default 3) so quotes stay bounded.
 */
export function findCandidatePaths(
  pools: V4PoolKey[],
  tokenIn: Address,
  tokenOut: Address,
  maxHops = 3,
  maxPaths = 12,
): CandidatePath[] {
  if (sameAddress(tokenIn, tokenOut)) return []
  if (pools.length === 0) return []

  const adj = new Map<string, V4PoolKey[]>()
  const seenPool = new Set<string>()
  for (const pool of pools) {
    const id = poolKeyId(pool)
    if (seenPool.has(id)) continue
    seenPool.add(id)
    const [a, b] = sortCurrencies(pool.currency0, pool.currency1)
    const push = (token: Address) => {
      const k = token.toLowerCase()
      const list = adj.get(k) ?? []
      list.push(pool)
      adj.set(k, list)
    }
    push(a)
    push(b)
  }

  const outLc = tokenOut.toLowerCase()
  const found: CandidatePath[] = []
  const queue: { token: Address; hops: SwapHop[] }[] = [{ token: tokenIn, hops: [] }]
  const visitedAt = new Map<string, number>()
  visitedAt.set(tokenIn.toLowerCase(), 0)

  while (queue.length > 0 && found.length < maxPaths) {
    const cur = queue.shift()!
    if (cur.hops.length >= maxHops) continue
    const neighbors = adj.get(cur.token.toLowerCase()) ?? []
    for (const pool of neighbors) {
      const hop = hopFromPool(pool, cur.token)
      if (!hop) continue
      if (cur.hops.some((h) => poolKeyId(h.pool) === poolKeyId(pool))) continue
      const nextToken = hop.tokenOut
      const nextHops = [...cur.hops, hop]
      if (nextToken.toLowerCase() === outLc) {
        found.push({ hops: nextHops })
        if (found.length >= maxPaths) break
        continue
      }
      const depth = nextHops.length
      const prev = visitedAt.get(nextToken.toLowerCase())
      if (prev !== undefined && prev < depth) continue
      if (depth >= maxHops) continue
      visitedAt.set(nextToken.toLowerCase(), depth)
      queue.push({ token: nextToken, hops: nextHops })
    }
  }

  found.sort((a, b) => a.hops.length - b.hops.length)
  return found
}
