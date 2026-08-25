import { createPublicClient, encodePacked, http, keccak256, parseAbiItem, type Hex, type PublicClient } from 'viem'

import { resolveAppChain } from '@indexedex/protocol/runtimeChains'

import { isLocalRobinhoodTestnet, LOCAL_RPC_URL } from '../../lib/localRpc'
import { type Address, ZERO_ADDRESS } from '../../swap/lib/v4Types'

import { V4_POOL_MANAGER_ABI } from './seAbi'
import { checksumAddress, sortPoolTokens, type V4PoolKeyFields } from './sePool'

const V4_INITIALIZE_EVENT = parseAbiItem(
  'event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks, uint160 sqrtPriceX96, int24 tick)',
)

const DEFAULT_LOG_CHUNK = 50_000n

function parseRpcGetLogsMaxRange(message: string): bigint | null {
  const upToMatch = message.match(/up to a\s+(\d+)\s+block range/i)
  if (upToMatch?.[1]) {
    const n = Number(upToMatch[1])
    if (Number.isFinite(n) && n > 0) return BigInt(n)
  }
  const bracketMatch = message.match(/\[(0x[0-9a-fA-F]+),\s*(0x[0-9a-fA-F]+)\]/)
  if (bracketMatch?.[1] && bracketMatch?.[2]) {
    try {
      const lo = BigInt(bracketMatch[1])
      const hi = BigInt(bracketMatch[2])
      if (hi >= lo) return hi - lo + 1n
    } catch {
      /* ignore */
    }
  }
  return null
}

function poolKeyFromInitializeLog(log: {
  args?: {
    currency0?: Address
    currency1?: Address
    fee?: number | bigint
    tickSpacing?: number | bigint
    hooks?: Address
  }
}): V4PoolKeyFields | null {
  const a = log.args
  if (!a?.currency0 || !a.currency1 || a.fee == null || a.tickSpacing == null || !a.hooks) return null
  const c0 = checksumAddress(a.currency0)
  const c1 = checksumAddress(a.currency1)
  const hooks = checksumAddress(a.hooks)
  if (!c0 || !c1 || !hooks) return null
  const fee = Number(a.fee)
  const tickSpacing = Number(a.tickSpacing)
  if (!Number.isFinite(fee) || !Number.isInteger(fee) || fee < 0) return null
  if (!Number.isFinite(tickSpacing) || !Number.isInteger(tickSpacing) || tickSpacing < 1) return null
  const [currency0, currency1] = sortPoolTokens(c0, c1)
  return { currency0, currency1, fee, tickSpacing, hooks }
}

/** Uniswap v4 PoolManager `pools` mapping slot (StateLibrary.POOLS_SLOT). */
export const V4_POOLS_SLOT = 6n

export function createAppReadClient(chainId: number): PublicClient {
  const chain = resolveAppChain(chainId, isLocalRobinhoodTestnet() ? LOCAL_RPC_URL : undefined)
  return createPublicClient({
    chain,
    transport: http(chain.rpcUrls.default.http[0]),
  })
}

/** `keccak256(abi.encodePacked(poolId, POOLS_SLOT))` — StateLibrary._getPoolStateSlot. */
export function v4PoolStateSlot(poolId: Hex): Hex {
  return keccak256(encodePacked(['bytes32', 'uint256'], [poolId, V4_POOLS_SLOT]))
}

export function sqrtPriceX96FromExtsloadWord(word: Hex): bigint {
  return BigInt(word) & ((1n << 160n) - 1n)
}

export async function readV4PoolInitialized(
  client: Pick<PublicClient, 'readContract'>,
  poolManager: Address,
  poolId: Hex,
): Promise<boolean> {
  try {
    const word = (await client.readContract({
      address: poolManager,
      abi: V4_POOL_MANAGER_ABI,
      functionName: 'extsload',
      args: [v4PoolStateSlot(poolId)],
    })) as Hex
    return sqrtPriceX96FromExtsloadWord(word) > 0n
  } catch {
    return false
  }
}

/** Reverse a Uniswap V4 PoolId to PoolKey via PoolManager Initialize logs. */
export async function lookupV4PoolKeyById(args: {
  client: Pick<PublicClient, 'getLogs' | 'getBlockNumber'>
  poolManager: Address
  poolId: Hex
}): Promise<V4PoolKeyFields | { error: string }> {
  const { client, poolManager, poolId } = args
  let latest: bigint
  try {
    latest = await client.getBlockNumber()
  } catch {
    return { error: 'No RPC client.' }
  }

  const query = (fromBlock: bigint, toBlock: bigint) =>
    client.getLogs({
      address: poolManager,
      event: V4_INITIALIZE_EVENT,
      args: { id: poolId },
      fromBlock,
      toBlock,
    })

  const firstKey = (logs: Awaited<ReturnType<typeof query>>) => {
    for (const log of logs) {
      const key = poolKeyFromInitializeLog(log)
      if (key) return key
    }
    return null
  }

  try {
    const found = firstKey(await query(0n, latest))
    if (found) return found
    return { error: 'No Uniswap V4 pool with that ID on this network.' }
  } catch (err) {
    const max = parseRpcGetLogsMaxRange(String((err as { message?: string })?.message ?? err)) ?? DEFAULT_LOG_CHUNK
    for (let toBlock = latest; toBlock >= 0n; ) {
      const fromBlock = toBlock + 1n > max ? toBlock - max + 1n : 0n
      let logs: Awaited<ReturnType<typeof query>>
      try {
        logs = await query(fromBlock, toBlock)
      } catch {
        if (fromBlock === 0n) break
        toBlock = fromBlock - 1n
        continue
      }
      const found = firstKey(logs)
      if (found) return found
      if (fromBlock === 0n) break
      toBlock = fromBlock - 1n
    }
    return { error: 'No Uniswap V4 pool with that ID on this network.' }
  }
}

export function uniqueAddresses(raw: Address[] | undefined, cap = 12): Address[] {
  const seen = new Set<string>()
  const out: Address[] = []
  for (const addr of raw ?? []) {
    const key = addr.toLowerCase()
    if (seen.has(key) || addr === ZERO_ADDRESS) continue
    seen.add(key)
    out.push(addr)
    if (out.length >= cap) break
  }
  return out
}
