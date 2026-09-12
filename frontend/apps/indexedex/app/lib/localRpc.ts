import { robinhood, robinhoodAnvil, robinhoodTestnet, robinhoodTestnetAnvil } from '@indexedex/protocol/runtimeChains'
import type { Chain } from 'viem'

const localRpcEnv = process.env.NEXT_PUBLIC_LOCAL_RPC_URL

/** Explicit local RPC is used for disconnected browsing and wallet chain metadata. */
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

/** A local RPC serves one fork, never both Robinhood chain IDs. */
export function getWalletChains(defaultChainId: number): readonly [Chain, ...Chain[]] {
  if (isLocalRobinhoodTestnet()) {
    const chain = defaultChainId === robinhoodTestnet.id
      ? robinhoodTestnetAnvil(LOCAL_RPC_URL)
      : robinhoodAnvil(LOCAL_RPC_URL)
    return [{
      ...chain,
      name: defaultChainId === robinhoodTestnet.id ? 'Robinhood Testnet Local Anvil' : 'Robinhood Local Anvil',
      blockExplorers: undefined,
      testnet: true,
    }]
  }
  return defaultChainId === robinhoodTestnet.id
    ? [robinhoodTestnet, robinhood]
    : [robinhood, robinhoodTestnet]
}
