import { describe, expect, it } from 'vitest'

import {
  CP_HOOK_REQUIRED_FLAGS,
  HOOK_FLAG_MASK,
  findMineNonce,
  flagsMatch,
  predictHookAddress,
} from './hookMine'

describe('hookMine', () => {
  it('finds a nonce whose CREATE2 address matches CP hook flags', () => {
    const factory = '0x52Dcc93187cd18a69DE11A94CBB024a5947E2d85' as const
    const initHash = ('0x' + '11'.repeat(32)) as `0x${string}`
    const salt = ('0x' + '22'.repeat(32)) as `0x${string}`
    const nonce = findMineNonce(factory, initHash, salt, CP_HOOK_REQUIRED_FLAGS)
    const predicted = predictHookAddress(factory, initHash, salt, nonce)
    expect(flagsMatch(predicted, CP_HOOK_REQUIRED_FLAGS)).toBe(true)
    expect(BigInt(predicted) & HOOK_FLAG_MASK).toBe(CP_HOOK_REQUIRED_FLAGS & HOOK_FLAG_MASK)
  })
})
