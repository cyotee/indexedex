import { describe, expect, it, vi } from 'vitest'

import {
  connectInjectedWallet,
  isProviderNotFoundError,
  orderWalletConnectors,
} from './connectInjected'

describe('orderWalletConnectors', () => {
  it('puts MetaMask before generic injected', () => {
    const ordered = orderWalletConnectors([
      { id: 'coinbaseWallet', name: 'Coinbase Wallet' },
      { id: 'injected', name: 'Injected' },
      { id: 'metaMask', name: 'MetaMask' },
    ])
    expect(ordered.map((c) => c.id)).toEqual(['metaMask', 'injected', 'coinbaseWallet'])
  })
})

describe('connectInjectedWallet', () => {
  it('falls through Provider not found to generic injected', async () => {
    const metaMask = { id: 'metaMask', name: 'MetaMask' }
    const injected = { id: 'injected', name: 'Injected' }
    const connectAsync = vi.fn(async ({ connector }: { connector: { id: string } }) => {
      if (connector.id === 'metaMask') {
        const err = new Error('Provider not found.')
        err.name = 'ProviderNotFoundError'
        throw err
      }
    })
    await connectInjectedWallet({
      connectAsync,
      connectors: [metaMask, injected],
    })
    expect(connectAsync).toHaveBeenCalledTimes(2)
    expect(connectAsync.mock.calls[1][0].connector.id).toBe('injected')
  })

  it('does not try the next connector on user reject', async () => {
    const connectAsync = vi.fn(async () => {
      const err = Object.assign(new Error('User rejected the request'), { code: 4001 })
      throw err
    })
    await expect(
      connectInjectedWallet({
        connectAsync,
        connectors: [
          { id: 'metaMask', name: 'MetaMask' },
          { id: 'injected', name: 'Injected' },
        ],
      }),
    ).rejects.toMatchObject({ code: 4001 })
    expect(connectAsync).toHaveBeenCalledTimes(1)
  })
})

describe('isProviderNotFoundError', () => {
  it('matches wagmi ProviderNotFoundError', () => {
    const err = new Error('Provider not found.')
    err.name = 'ProviderNotFoundError'
    expect(isProviderNotFoundError(err)).toBe(true)
    expect(isProviderNotFoundError(new Error('boom'))).toBe(false)
  })
})
