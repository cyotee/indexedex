import { describe, expect, it, vi, afterEach } from 'vitest'
import type { State } from 'wagmi'
import { walletFirstTransport } from './walletFirstTransport'

const connectedState = (request: ReturnType<typeof vi.fn>) => ({
  status: 'connected', current: 'selected', chainId: 4663,
  connections: new Map([['selected', { chainId: 4663, accounts: ['0x123'], connector: { getProvider: async () => ({ request }) } }]]),
}) as unknown as State

afterEach(() => vi.unstubAllGlobals())

describe('selected wallet transport', () => {
  it('reads from the selected provider without HTTP', async () => {
    const request = vi.fn().mockResolvedValueOnce('0x1237').mockResolvedValueOnce('0xabc')
    const state = connectedState(request)
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch)
    const transport = walletFirstTransport(4663, 'http://unused.invalid', () => state)({})
    expect(await transport.request({ method: 'eth_blockNumber' })).toBe('0xabc')
    expect(fetch).not.toHaveBeenCalled()
  })
  it.each(['execution reverted', 'Provider disconnected', 'request timed out', 'user rejected'])('never falls back on %s', async (message) => {
    const request = vi.fn().mockResolvedValueOnce('0x1237').mockRejectedValueOnce(new Error(message))
    const state = connectedState(request)
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch)
    const transport = walletFirstTransport(4663, 'http://unused.invalid', () => state)({})
    await expect(transport.request({ method: 'eth_blockNumber' })).rejects.toThrow(message)
    expect(fetch).not.toHaveBeenCalled()
  })
  it('rejects the wrong network before making a read', async () => {
    const request = vi.fn().mockResolvedValue('0x1')
    const state = connectedState(request)
    const transport = walletFirstTransport(4663, 'http://unused.invalid', () => state)({})
    await expect(transport.request({ method: 'eth_blockNumber' })).rejects.toThrow('Switch the wallet')
    expect(request).toHaveBeenCalledTimes(1)
  })
  it('discards a response if the connection changed in flight', async () => {
    let state: State
    const request = vi.fn().mockImplementation(async ({ method }) => {
      if (method === 'eth_chainId') return '0x1237'
      state = { ...state, status: 'disconnected' }
      return '0xabc'
    })
    state = connectedState(request)
    const transport = walletFirstTransport(4663, 'http://unused.invalid', () => state)({})
    await expect(transport.request({ method: 'eth_blockNumber' })).rejects.toThrow('Wallet connection changed')
  })
  it('allows HTTP only when disconnected', async () => {
    const state = { status: 'disconnected' } as State
    const fetch = vi.fn(async () => new Response(JSON.stringify({ jsonrpc: '2.0', id: 1, result: '0x123' }), { headers: { 'Content-Type': 'application/json' } }))
    vi.stubGlobal('fetch', fetch)
    const transport = walletFirstTransport(4663, 'http://disconnected.invalid', () => state)({})
    expect(await transport.request({ method: 'eth_blockNumber' })).toBe('0x123')
    expect(fetch).toHaveBeenCalledOnce()
  })
})
