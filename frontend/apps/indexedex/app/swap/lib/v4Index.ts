import { parseAbiItem, type PublicClient } from 'viem'

import type { Address, V4PoolKey } from './v4Types'
import { poolKeyId, sortCurrencies } from './v4Types'

const INITIALIZE_EVENT = parseAbiItem(
  'event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks, uint160 sqrtPriceX96, int24 tick)',
)

export type IndexReader = Pick<PublicClient, 'getLogs' | 'getBlockNumber'>

/**
 * Uniswap's pool search starts from PoolManager Initialize logs, not a hook allowlist.
 * Scan recent history (or the whole Anvil overlay when the chain is short).
 */
export async function indexPoolsFromInitialize(args: {
  client: IndexReader
  poolManager: Address
}): Promise<V4PoolKey[]> {
  const { client, poolManager } = args
  let toBlock: bigint
  try {
    toBlock = await client.getBlockNumber()
  } catch {
    return []
  }

  const window = toBlock < BigInt(80000) ? toBlock : BigInt(30000)
  const fromBlock = toBlock > window ? toBlock - window : BigInt(0)

  try {
    const logs = await client.getLogs({
      address: poolManager,
      event: INITIALIZE_EVENT,
      fromBlock,
      toBlock,
    })
    const found = new Map<string, V4PoolKey>()
    for (let i = 0; i < logs.length; i++) {
      const log = logs[i]!
      const a = (log.args as { currency0?: Address; currency1?: Address; fee?: number; tickSpacing?: number; hooks?: Address })
      if (!a.currency0 || !a.currency1 || a.fee == null || a.tickSpacing == null || !a.hooks) continue
      const [currency0, currency1] = sortCurrencies(a.currency0, a.currency1)
      const key: V4PoolKey = {
        currency0,
        currency1,
        fee: Number(a.fee),
        tickSpacing: Number(a.tickSpacing),
        hooks: a.hooks,
      }
      found.set(poolKeyId(key), key)
    }
    return Array.from(found.values())
  } catch {
    return []
  }
}
