import { createPublicClient, encodePacked, http, keccak256, type Hex, type PublicClient } from 'viem'

import { resolveAppChain } from '@indexedex/protocol/runtimeChains'

import { isLocalRobinhoodTestnet, LOCAL_RPC_URL } from '../../lib/localRpc'
import { type Address, ZERO_ADDRESS } from '../../swap/lib/v4Types'

import { V4_POOL_MANAGER_ABI } from './seAbi'

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
