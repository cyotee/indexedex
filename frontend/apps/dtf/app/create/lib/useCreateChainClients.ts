'use client'

import { useMemo } from 'react'
import { publicActions, type PublicClient, type WalletClient } from 'viem'
import { usePublicClient, useWalletClient } from 'wagmi'

import { createAppReadClient } from './sePoolRead'

export function walletAsReadClient(
  walletClient: WalletClient | undefined | null,
): PublicClient | undefined {
  if (!walletClient) return undefined
  return walletClient.extend(publicActions) as unknown as PublicClient
}

/** Prefer the connected wallet RPC. HTTP is only the disconnected fallback. */
export function preferWalletReadClient(
  walletRead: PublicClient | undefined,
  fallback: PublicClient,
): PublicClient {
  return walletRead ?? fallback
}

/**
 * Create-flow RPC clients.
 * When a wallet is connected, reads (eth_call, receipts) go through that wallet's RPC,
 * matching swap: `walletClient.extend(publicActions)`.
 */
export function useCreateChainClients(chainId: number): {
  readClient: PublicClient
  walletClient: WalletClient | undefined
  httpClient: PublicClient
} {
  const httpClient = useMemo(() => createAppReadClient(chainId), [chainId])
  const wagmiPublic = usePublicClient({ chainId })
  const { data: walletClient } = useWalletClient()

  const readClient = useMemo(() => {
    const fromWallet = walletAsReadClient(walletClient as WalletClient | undefined)
    const fallback = (wagmiPublic as PublicClient | undefined) ?? httpClient
    return preferWalletReadClient(fromWallet, fallback)
  }, [walletClient, wagmiPublic, httpClient])

  return {
    readClient,
    walletClient: walletClient as WalletClient | undefined,
    httpClient,
  }
}
