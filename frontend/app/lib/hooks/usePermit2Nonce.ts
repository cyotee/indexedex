'use client'

import { useCallback, useMemo } from 'react'
import { useReadContract } from 'wagmi'

type UsePermit2NonceParams = {
  permit2Address: `0x${string}` | undefined
  owner: `0x${string}` | undefined
}

type UsePermit2NonceResult = {
  nonceBitmap: bigint | undefined
  nextUnusedNonce: bigint | undefined
  refetchNonce: () => Promise<bigint | undefined>
}

const permit2NonceBitmapAbi = [
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'wordIndex', type: 'uint256' },
    ],
    name: 'nonceBitmap',
    outputs: [{ name: 'bitmap', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

function deriveNextUnusedNonce(nonceBitmap: bigint | undefined): bigint | undefined {
  if (nonceBitmap === undefined) return undefined

  const inverted = ~nonceBitmap & ((BigInt(1) << BigInt(256)) - BigInt(1))
  for (let index = 0; index < 256; index += 1) {
    if (((inverted >> BigInt(index)) & BigInt(1)) === BigInt(1)) {
      return BigInt(index)
    }
  }

  return undefined
}

export function usePermit2Nonce({ permit2Address, owner }: UsePermit2NonceParams): UsePermit2NonceResult {
  const { data, refetch } = useReadContract({
    address: permit2Address,
    abi: permit2NonceBitmapAbi,
    functionName: 'nonceBitmap',
    args: owner ? [owner, BigInt(0)] : undefined,
    query: { enabled: !!permit2Address && !!owner },
  })

  const nonceBitmap = data as bigint | undefined
  const nextUnusedNonce = useMemo(() => deriveNextUnusedNonce(nonceBitmap), [nonceBitmap])

  const refetchNonce = useCallback(async () => {
    const refreshed = await refetch()
    return refreshed.data as bigint | undefined
  }, [refetch])

  return {
    nonceBitmap,
    nextUnusedNonce,
    refetchNonce,
  }
}

export default usePermit2Nonce