import { describe, expect, it } from 'vitest'

import { preferWalletReadClient, walletAsReadClient } from './useCreateChainClients'

describe('preferWalletReadClient', () => {
  it('uses the wallet client when it exists', () => {
    const wallet = { id: 'wallet' }
    const http = { id: 'http' }
    expect(preferWalletReadClient(wallet as never, http as never)).toBe(wallet)
  })

  it('falls back to HTTP when disconnected', () => {
    const http = { id: 'http' }
    expect(preferWalletReadClient(undefined, http as never)).toBe(http)
  })
})

describe('walletAsReadClient', () => {
  it('returns undefined when there is no wallet', () => {
    expect(walletAsReadClient(undefined)).toBeUndefined()
    expect(walletAsReadClient(null)).toBeUndefined()
  })

  it('extends the wallet with public actions', () => {
    const extended = { id: 'extended' }
    const wallet = {
      extend: () => extended,
    }
    expect(walletAsReadClient(wallet as never)).toBe(extended)
  })
})
