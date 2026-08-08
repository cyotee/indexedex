'use client'

// Permit2 nonceBitmap helper functions
// Permit2 uses a bitmap where each bit represents a nonce: 1 = used, 0 = unused
// Word index = nonce >> 8, bit index = nonce & 255

/**
 * Find the first unused nonce from a Permit2 bitmap word
 * @param bitmap - The bitmap word from nonceBitmap(address, wordIndex)
 * @returns The first unused nonce within this word (0-255), or -1 if all used
 */
export function findFirstUnusedNonceInWord(bitmap: bigint): number {
  // Invert the bitmap so we can find 0s (unused nonces)
  // Only consider lower 256 bits
  const inverted = ~bitmap & ((BigInt(1) << BigInt(256)) - BigInt(1))
  
  // Find first set bit in inverted (which was unset in original = unused)
  for (let i = 0; i < 256; i++) {
    if (((inverted >> BigInt(i)) & BigInt(1)) === BigInt(1)) {
      return i
    }
  }
  return -1 // All nonces in this word are used
}

/**
 * Calculate the full nonce from word index and bit index
 * @param wordIndex - The word index (nonce >> 8)
 * @param bitIndex - The bit index within the word (nonce & 255)
 * @returns The full nonce value
 */
export function calculateNonce(wordIndex: bigint, bitIndex: number): bigint {
  return (wordIndex << BigInt(8)) | BigInt(bitIndex)
}

/**
 * Get the next available nonce for Permit2 signature
 * @param nonceBitmapWord - The result from calling nonceBitmap(address, 0)
 * @returns The next available nonce, starting from 0
 */
export function getNextAvailableNonce(nonceBitmapWord: bigint): bigint {
  const unusedBitIndex = findFirstUnusedNonceInWord(nonceBitmapWord)
  if (unusedBitIndex >= 0) {
    return BigInt(unusedBitIndex)
  }
  // If all 256 nonces in word 0 are used, we'd need to check word 1
  // For most use cases, word 0 should suffice
  return BigInt(0)
}
