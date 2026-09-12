import { getAddress } from 'viem'

import { isLocalRobinhoodTestnet } from './localRpc'

/** Public block explorer origins keyed by chain id. Local Anvil has none. */
const EXPLORER_ORIGIN: Record<number, string> = {
  1: 'https://etherscan.io',
  11155111: 'https://sepolia.etherscan.io',
  8453: 'https://basescan.org',
  84532: 'https://sepolia.basescan.org',
  // Official Robinhood Chain docs: mainnet is robinhoodchain.blockscout.com, not explorer.mainnet…
  4663: 'https://robinhoodchain.blockscout.com',
  46630: 'https://explorer.testnet.chain.robinhood.com',
}

export function explorerOrigin(chainId: number): string | null {
  return EXPLORER_ORIGIN[chainId] ?? null
}

function checksummed(address: string): string | null {
  if (!address) return null
  try {
    return getAddress(address)
  } catch {
    return null
  }
}

/**
 * Address page on the public explorer for `chainId`, or null when there is no
 * public explorer (local Anvil / unknown chain).
 */
export function explorerAddressUrl(
  chainId: number,
  address: string,
  local = isLocalRobinhoodTestnet(),
): string | null {
  if (local || chainId === 31337 || chainId === 1337) return null
  const origin = explorerOrigin(chainId)
  const addr = checksummed(address)
  if (!origin || !addr) return null
  return `${origin}/address/${addr}`
}

export function explorerTxUrl(
  chainId: number,
  hash: string,
  local = isLocalRobinhoodTestnet(),
): string | null {
  if (local || chainId === 31337 || chainId === 1337) return null
  const origin = explorerOrigin(chainId)
  if (!origin || !hash) return null
  return `${origin}/tx/${hash}`
}
