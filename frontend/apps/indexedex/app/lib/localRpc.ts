const localRpcEnv = process.env.NEXT_PUBLIC_LOCAL_RPC_URL
const deploymentEnv = process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT

/** Local Anvil JSON-RPC. Used only as a disconnected/SSR fallback and for first-time wallet_addEthereumChain. */
export const LOCAL_RPC_URL = (localRpcEnv && localRpcEnv.trim()) || 'http://127.0.0.1:8545'

/** True when this process is the 46630 Anvil rehearsal (wallet RPC still wins when connected). */
export function isLocalRobinhoodTestnet(): boolean {
  return deploymentEnv === 'anvil_robinhood_testnet' || Boolean(localRpcEnv && localRpcEnv.trim())
}

export function robinhoodTestnetRpcUrl(): string {
  return isLocalRobinhoodTestnet()
    ? LOCAL_RPC_URL
    : 'https://rpc.testnet.chain.robinhood.com'
}
