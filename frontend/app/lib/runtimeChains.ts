'use client'

import { base, baseSepolia, foundry, localhost, sepolia } from 'wagmi/chains'
import type { Chain } from 'viem'

import {
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_SEPOLIA,
} from '../addresses'

export function resolveAppChain(chainId?: number | null): Chain {
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
    case sepolia.id:
    case CHAIN_ID_SEPOLIA:
    default:
      return sepolia
  }
}
