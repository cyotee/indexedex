'use client'

import { base, baseSepolia, foundry, localhost, sepolia } from 'wagmi/chains'
import type { Chain } from 'viem'
import { defineChain } from 'viem'

import {
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_ROBINHOOD,
  CHAIN_ID_ROBINHOOD_TESTNET,
  CHAIN_ID_SEPOLIA,
} from './addresses'

/** Robinhood Chain mainnet (and Anvil RH-fork with --chain-id 4663). */
export const robinhood = defineChain({
  id: CHAIN_ID_ROBINHOOD,
  name: 'Robinhood',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://rpc.mainnet.chain.robinhood.com'] },
  },
  blockExplorers: {
    default: {
      name: 'Robinhood Explorer',
      url: 'https://explorer.mainnet.chain.robinhood.com',
    },
  },
})

/** Local Anvil forked as Robinhood (same chain id, localhost RPC). */
export function robinhoodAnvil(rpcUrl = 'http://127.0.0.1:8545'): Chain {
  return {
    ...robinhood,
    name: 'Robinhood (Anvil)',
    rpcUrls: {
      default: { http: [rpcUrl] },
      public: { http: [rpcUrl] },
    },
  }
}

/** Robinhood Chain Testnet (public 46630). */
export const robinhoodTestnet = defineChain({
  id: CHAIN_ID_ROBINHOOD_TESTNET,
  name: 'Robinhood Chain Testnet',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://rpc.testnet.chain.robinhood.com'] },
  },
  blockExplorers: {
    default: {
      name: 'Robinhood Testnet Explorer',
      url: 'https://explorer.testnet.chain.robinhood.com',
    },
  },
})

/** Local Anvil forked as Robinhood Testnet (chain id 46630). */
export function robinhoodTestnetAnvil(rpcUrl = 'http://127.0.0.1:8545'): Chain {
  return {
    ...robinhoodTestnet,
    name: 'Robinhood Testnet (Anvil)',
    rpcUrls: {
      default: { http: [rpcUrl] },
      public: { http: [rpcUrl] },
    },
  }
}

export function resolveAppChain(chainId?: number | null, localRpcUrl?: string): Chain {
  switch (chainId) {
    case baseSepolia.id:
    case CHAIN_ID_BASE_SEPOLIA:
      return baseSepolia
    case foundry.id:
      return foundry
    case localhost.id:
      return localhost
    case base.id:
      return base
    case CHAIN_ID_ROBINHOOD:
      return localRpcUrl ? robinhoodAnvil(localRpcUrl) : robinhood
    case CHAIN_ID_ROBINHOOD_TESTNET:
      return localRpcUrl ? robinhoodTestnetAnvil(localRpcUrl) : robinhoodTestnet
    case sepolia.id:
    case CHAIN_ID_SEPOLIA:
    default:
      return sepolia
  }
}
