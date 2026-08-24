import { createPublicClient, http, type Hex, type PublicClient } from 'viem'

import { resolveAppChain } from '@indexedex/protocol/runtimeChains'

import { isLocalRobinhoodTestnet, LOCAL_RPC_URL } from '../../lib/localRpc'
import { type Address, ZERO_ADDRESS } from '../../swap/lib/v4Types'

import { V4_STATE_VIEW_ABI } from './seAbi'

export function createAppReadClient(chainId: number): PublicClient {
  const chain = resolveAppChain(chainId, isLocalRobinhoodTestnet() ? LOCAL_RPC_URL : undefined)
  return createPublicClient({
    chain,
    transport: http(chain.rpcUrls.default.http[0]),
  })
}

/** Uniswap v4: initialized iff StateView.getSlot0 sqrtPriceX96 > 0. */
export function slot0IsInitialized(sqrtPriceX96: bigint | undefined | null): boolean {
  return typeof sqrtPriceX96 === 'bigint' && sqrtPriceX96 > 0n
}

export async function readV4PoolInitialized(
  client: Pick<PublicClient, 'readContract'>,
  stateView: Address,
  poolId: Hex,
): Promise<boolean> {
  try {
    const slot0 = (await client.readContract({
      address: stateView,
      abi: V4_STATE_VIEW_ABI,
      functionName: 'getSlot0',
      args: [poolId],
    })) as readonly [bigint, ...unknown[]]
    return slot0IsInitialized(slot0[0])
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
