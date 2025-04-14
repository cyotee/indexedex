// Permit2 nonce utilities
import type { PublicClient } from 'viem'

// ABI for Permit2's nonceBitmap function
const nonceBitmapAbi = [{
  inputs: [
    { name: 'owner', type: 'address' },
    { name: 'wordIndex', type: 'uint256' }
  ],
  name: 'nonceBitmap',
  outputs: [{ name: 'bitmap', type: 'uint256' }],
  stateMutability: 'view',
  type: 'function'
}] as const

function extractBigIntReadResult(result: unknown): bigint {
  if (typeof result === 'bigint') return result
  if (Array.isArray(result) && typeof result[0] === 'bigint') return result[0]
  if (typeof result === 'object' && result !== null) {
    const record = result as Record<string, unknown>
    const zero = record['0']
    if (typeof zero === 'bigint') return zero
  }
  throw new Error('Unexpected readContract return shape; expected bigint')
}

/**
 * Fetch the Permit2 nonce bitmap for a given owner
 */
export async function fetchPermit2Nonce(
  publicClient: PublicClient,
  permit2Address: `0x${string}`,
  owner: `0x${string}`,
  wordIndex: bigint = BigInt(0)
): Promise<bigint> {
  const result = await publicClient.readContract({
    address: permit2Address,
    abi: nonceBitmapAbi,
    functionName: 'nonceBitmap',
    args: [owner, wordIndex]
  })
  return extractBigIntReadResult(result)
}

/**
 * Find the first unused nonce from a bitmap
 * The bitmap uses 1 for used/nonce and 0 for unused
 * We invert to find the first 0 bit
 */
export function findFirstUnusedNonce(bitmap: bigint): bigint {
  const inverted = ~bitmap & ((BigInt(1) << BigInt(256)) - BigInt(1))
  for (let i = 0; i < 256; i++) {
    if (((inverted >> BigInt(i)) & BigInt(1)) === BigInt(1)) {
      return BigInt(i)
    }
  }
  // If all 256 nonces in this word are used, return 256 (next word)
  return BigInt(256)
}

export async function findNextUnusedPermit2Nonce(
  publicClient: PublicClient,
  permit2Address: `0x${string}`,
  owner: `0x${string}`,
  maxWords: number = 8
): Promise<bigint> {
  for (let w = 0; w < maxWords; w++) {
    const wordIndex = BigInt(w)
    const bitmap = await fetchPermit2Nonce(publicClient, permit2Address, owner, wordIndex)
    const bitIndex = findFirstUnusedNonce(bitmap)
    if (bitIndex < BigInt(256)) {
      return (wordIndex << BigInt(8)) | bitIndex
    }
  }
  throw new Error(`No unused Permit2 nonce found in first ${maxWords} words`)
}
