'use client'

import { useEffect, useMemo, useState } from 'react'
import { usePublicClient, useReadContract } from 'wagmi'
import type { Hex } from 'viem'

import { asAddr } from './actionTokens'
import { v4PoolViewAbi } from './insightsAbi'
import {
  detfReservePoolKey,
  poolIdFromKey,
  poolKeyFromUnknown,
  readSeVaultPoolId,
} from './poolKeys'

export type DetfPoolIdRow = {
  role: string
  id: Hex
  vault?: `0x${string}`
}

export function useDetfPoolIds(args: {
  chainId: number
  detf?: `0x${string}`
  pairToken?: `0x${string}`
  reserveHook?: `0x${string}`
  claimToken?: `0x${string}`
  seVaults: readonly `0x${string}`[]
}): { reservePoolId?: Hex; sePoolIds: DetfPoolIdRow[] } {
  const { chainId, detf, pairToken, reserveHook, claimToken, seVaults } = args
  const client = usePublicClient({ chainId })

  const listing = useReadContract({
    address: claimToken,
    abi: v4PoolViewAbi,
    functionName: 'listingPoolKey',
    query: { enabled: !!claimToken, retry: 0 },
  })
  const pairKey = useReadContract({
    address: reserveHook,
    abi: v4PoolViewAbi,
    functionName: 'pairPoolKey',
    args: detf && pairToken ? [detf, pairToken] : undefined,
    query: { enabled: !!reserveHook && !!detf && !!pairToken, retry: 0 },
  })
  const currency0 = useReadContract({
    address: reserveHook,
    abi: v4PoolViewAbi,
    functionName: 'currency0',
    query: { enabled: !!reserveHook, retry: 0 },
  })
  const currency1 = useReadContract({
    address: reserveHook,
    abi: v4PoolViewAbi,
    functionName: 'currency1',
    query: { enabled: !!reserveHook, retry: 0 },
  })
  const poolFee = useReadContract({
    address: reserveHook,
    abi: v4PoolViewAbi,
    functionName: 'poolFee',
    query: { enabled: !!reserveHook, retry: 0 },
  })
  const tickHint = useReadContract({
    address: reserveHook,
    abi: v4PoolViewAbi,
    functionName: 'tickSpacingHint',
    query: { enabled: !!reserveHook, retry: 0 },
  })

  const reservePoolId = useMemo(() => {
    const fromListing = poolIdFromKey(poolKeyFromUnknown(listing.data))
    if (fromListing) return fromListing
    const fromPair = poolIdFromKey(poolKeyFromUnknown(pairKey.data))
    if (fromPair) return fromPair
    const c0 = asAddr(currency0.data)
    const c1 = asAddr(currency1.data)
    if (c0 && c1 && reserveHook) {
      return poolIdFromKey(
        detfReservePoolKey({
          currency0: c0,
          currency1: c1,
          hooks: reserveHook,
          fee: typeof poolFee.data === 'number' ? poolFee.data : undefined,
          tickSpacing: typeof tickHint.data === 'number' ? tickHint.data : undefined,
        }),
      ) ?? undefined
    }
    return undefined
  }, [
    listing.data,
    pairKey.data,
    currency0.data,
    currency1.data,
    reserveHook,
    poolFee.data,
    tickHint.data,
  ])

  const seKey = seVaults.map((v) => v.toLowerCase()).join(',')
  const [sePoolIds, setSePoolIds] = useState<DetfPoolIdRow[]>([])

  useEffect(() => {
    const vaults = seKey.split(',').filter(Boolean) as `0x${string}`[]
    if (!client || vaults.length === 0) {
      setSePoolIds([])
      return
    }
    let cancelled = false
    void (async () => {
      const rows: DetfPoolIdRow[] = []
      for (let i = 0; i < vaults.length; i++) {
        const vault = vaults[i]
        if (!vault) continue
        const id = await readSeVaultPoolId(client, vault)
        if (id) {
          rows.push({
            role: vaults.length === 1 ? 'Underlying vault' : `Underlying vault ${i + 1}`,
            id,
            vault,
          })
        }
      }
      if (!cancelled) setSePoolIds(rows)
    })()
    return () => {
      cancelled = true
    }
  }, [client, seKey])

  return { reservePoolId: reservePoolId ?? undefined, sePoolIds }
}
