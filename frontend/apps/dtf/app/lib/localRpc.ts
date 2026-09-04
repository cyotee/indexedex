const localRpcEnv = process.env.NEXT_PUBLIC_LOCAL_RPC_URL

/** Local Anvil JSON-RPC. Used only as a disconnected/SSR fallback and for first-time wallet_addEthereumChain. */
export const LOCAL_RPC_URL = (localRpcEnv && localRpcEnv.trim()) || 'http://127.0.0.1:8545'

/**
 * True only when an explicit local RPC is set.
 * `anvil_robinhood_main` is the 4663 artifact registry key (also used in production).
 */
export function isLocalRobinhoodTestnet(): boolean {
  return Boolean(localRpcEnv && localRpcEnv.trim())
}

export function robinhoodTestnetRpcUrl(): string {
  return isLocalRobinhoodTestnet()
    ? LOCAL_RPC_URL
    : 'https://rpc.testnet.chain.robinhood.com'
}
