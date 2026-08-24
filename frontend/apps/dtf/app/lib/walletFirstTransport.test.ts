import { describe, expect, it } from 'vitest'

import { shouldThrowWalletFirst } from './walletFirstTransport'

describe('shouldThrowWalletFirst', () => {
  it('keeps initialize reverts on the wallet instead of falling through to HTTP', () => {
    expect(shouldThrowWalletFirst(new Error('execution reverted'))).toBe(true)
    expect(shouldThrowWalletFirst(new Error('PoolAlreadyInitialized()'))).toBe(true)
    expect(shouldThrowWalletFirst(new Error('insufficient gas'))).toBe(true)
    expect(shouldThrowWalletFirst(new Error('Internal JSON-RPC error.'))).toBe(true)
    expect(shouldThrowWalletFirst(Object.assign(new Error('revert'), { code: 3 }))).toBe(true)
  })

  it('lets disconnect fall through to HTTP', () => {
    expect(shouldThrowWalletFirst(new Error('Provider is disconnected.'))).toBe(false)
    expect(
      shouldThrowWalletFirst(Object.assign(new Error('disconnected'), { code: 4900 })),
    ).toBe(false)
  })
})
