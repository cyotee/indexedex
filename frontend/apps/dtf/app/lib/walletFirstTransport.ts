import { custom, http, type EIP1193Provider, type Transport } from 'viem'
import type { State } from 'wagmi'

/** Only disconnected browsing uses HTTP. A connected wallet is authoritative,
 * including its errors; never substitute a different node with the same chain ID. */
export function walletFirstTransport(chainId: number, fallbackUrl: string, getState: () => State): Transport {
  return (options) => {
    const disconnected = http(fallbackUrl)(options)
    return custom({
      async request(args) {
        const state = getState()
        if (state.status === 'disconnected') {
          const result = await disconnected.request(args)
          if (getState().status !== 'disconnected') throw new Error('Wallet connection changed. Refresh the position.')
          return result
        }
        const connection = state.current ? state.connections.get(state.current) : undefined
        if (state.status !== 'connected' || !connection) throw new Error('Waiting for wallet connection.')
        const provider = await connection.connector.getProvider() as EIP1193Provider | undefined
        if (!provider) throw new Error('The selected wallet provider is unavailable.')
        const actualChain = Number(await provider.request({ method: 'eth_chainId' }))
        if (actualChain !== chainId) throw new Error('Switch the wallet to the selected network to load this position.')
        const result = await provider.request(args as Parameters<EIP1193Provider['request']>[0])
        const current = getState()
        if (current.status !== 'connected' || current.current !== state.current ||
          current.connections.get(current.current!) !== connection) {
          throw new Error('Wallet connection changed. Refresh the position.')
        }
        return result
      },
    }, { key: 'walletFirst', name: 'Selected wallet RPC', retryCount: 0 })(options)
  }
}
