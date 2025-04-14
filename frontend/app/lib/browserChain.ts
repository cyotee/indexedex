'use client'

import { useEffect, useState } from 'react'
import type { Connector } from 'wagmi'

type BrowserEthereumProvider = {
  chainId?: string | number
  providers?: BrowserEthereumProvider[]
  isMetaMask?: boolean
  isCoinbaseWallet?: boolean
  selectedAddress?: string
  request?: (args: { method: string }) => Promise<unknown>
  on?: (event: string, listener: (value: unknown) => void) => void
  removeListener?: (event: string, listener: (value: unknown) => void) => void
}

type WalletConnector = Pick<Connector, 'getChainId' | 'getProvider'>

function parseChainId(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) return value
  if (typeof value !== 'string') return undefined

  if (value.startsWith('0x') || value.startsWith('0X')) {
    const parsed = Number.parseInt(value, 16)
    return Number.isFinite(parsed) ? parsed : undefined
  }

  const parsed = Number.parseInt(value, 10)
  return Number.isFinite(parsed) ? parsed : undefined
}

export function useBrowserChainId(enabled: boolean): number | undefined {
  const [chainId, setChainId] = useState<number | undefined>(undefined)

  useEffect(() => {
    if (!enabled || typeof window === 'undefined') {
      setChainId(undefined)
      return
    }

    const provider = (window as typeof window & { ethereum?: BrowserEthereumProvider }).ethereum
    if (!provider) {
      setChainId(undefined)
      return
    }

    let cancelled = false

    const sync = async () => {
      try {
        const requested = await provider.request?.({ method: 'eth_chainId' })
        const nextChainId = parseChainId(requested ?? provider.chainId)
        if (!cancelled) setChainId(nextChainId)
      } catch {
        const nextChainId = parseChainId(provider.chainId)
        if (!cancelled) setChainId(nextChainId)
      }
    }

    const handleChainChanged = (value: unknown) => {
      if (cancelled) return
      setChainId(parseChainId(value))
    }

    void sync()
    provider.on?.('chainChanged', handleChainChanged)

    return () => {
      cancelled = true
      provider.removeListener?.('chainChanged', handleChainChanged)
    }
  }, [enabled])

  return chainId
}

export function useConnectedWalletChainId(
  enabled: boolean,
  connector: WalletConnector | undefined,
): number | undefined {
  const [chainId, setChainId] = useState<number | undefined>(undefined)

  useEffect(() => {
    if (!enabled || !connector) {
      setChainId(undefined)
      return
    }

    let cancelled = false
    let provider: BrowserEthereumProvider | undefined

    const sync = async () => {
      try {
        provider = await connector.getProvider() as BrowserEthereumProvider | undefined
        const requested = await provider?.request?.({ method: 'eth_chainId' })
        const nextChainId = parseChainId(requested ?? provider?.chainId)
        if (!cancelled && nextChainId !== undefined) {
          setChainId(nextChainId)
          return
        }
      } catch {
        // Fall back to connector.getChainId below.
      }

      try {
        const nextChainId = await connector.getChainId()
        if (!cancelled) setChainId(nextChainId)
      } catch {
        if (!cancelled) setChainId(undefined)
      }
    }

    const handleChainChanged = (value: unknown) => {
      if (cancelled) return
      setChainId(parseChainId(value))
    }

    void sync()

    void connector.getProvider().then((nextProvider) => {
      if (cancelled) return
      provider = nextProvider as BrowserEthereumProvider | undefined
      provider?.on?.('chainChanged', handleChainChanged)
    })

    return () => {
      cancelled = true
      provider?.removeListener?.('chainChanged', handleChainChanged)
    }
  }, [connector, enabled])

  return chainId
}

async function readProviderChainId(provider: BrowserEthereumProvider | undefined): Promise<number | undefined> {
  if (!provider) return undefined

  try {
    const requested = await provider.request?.({ method: 'eth_chainId' })
    return parseChainId(requested ?? provider.chainId)
  } catch {
    return parseChainId(provider.chainId)
  }
}

function matchesConnector(provider: BrowserEthereumProvider, connectorId: string | undefined): boolean {
  if (!connectorId) return false
  if (connectorId === 'metaMask') return provider.isMetaMask === true
  if (connectorId === 'coinbaseWallet') return provider.isCoinbaseWallet === true
  return false
}

async function matchesAccount(
  provider: BrowserEthereumProvider,
  walletAddress: string | undefined,
): Promise<boolean> {
  if (!walletAddress) return false

  const normalizedWalletAddress = walletAddress.toLowerCase()
  if (typeof provider.selectedAddress === 'string' && provider.selectedAddress.toLowerCase() === normalizedWalletAddress) {
    return true
  }

  try {
    const accounts = await provider.request?.({ method: 'eth_accounts' })
    if (!Array.isArray(accounts)) return false

    return accounts.some(
      (account): account is string => typeof account === 'string' && account.toLowerCase() === normalizedWalletAddress,
    )
  } catch {
    return false
  }
}

async function resolvePreferredChainId(
  provider: BrowserEthereumProvider,
  preferredChainIds: readonly number[],
  connectorId: string | undefined,
  walletAddress: string | undefined,
): Promise<number | undefined> {
  const topLevelChainId = await readProviderChainId(provider)
  const nestedProviders = Array.isArray(provider.providers) ? provider.providers : []

  const accountMatchedProviders = (
    await Promise.all(
      nestedProviders.map(async (nestedProvider) => ({
        provider: nestedProvider,
        matchesAccount: await matchesAccount(nestedProvider, walletAddress),
      })),
    )
  )
    .filter((entry) => entry.matchesAccount)
    .map((entry) => entry.provider)
  const preferredProviders = nestedProviders.filter((nestedProvider) => matchesConnector(nestedProvider, connectorId))
  const candidateProviders = accountMatchedProviders.length > 0
    ? accountMatchedProviders
    : preferredProviders.length > 0
      ? preferredProviders
      : nestedProviders
  const candidateChainIds = (await Promise.all(candidateProviders.map(readProviderChainId)))
    .filter((value): value is number => value !== undefined)
  const preferredCandidateChainIds = candidateChainIds.filter((value) => preferredChainIds.includes(value))

  if (topLevelChainId !== undefined && preferredChainIds.includes(topLevelChainId)) {
    return topLevelChainId
  }

  if (preferredCandidateChainIds.length === 1) return preferredCandidateChainIds[0]

  for (const preferredChainId of preferredChainIds) {
    if (preferredCandidateChainIds.includes(preferredChainId)) {
      return preferredChainId
    }
  }

  return preferredCandidateChainIds[0]
}

export function usePreferredBrowserChainId(
  enabled: boolean,
  preferredChainIds: readonly number[],
  connectorId?: string,
  walletAddress?: string,
): number | undefined {
  const [chainId, setChainId] = useState<number | undefined>(undefined)

  useEffect(() => {
    if (!enabled || typeof window === 'undefined') {
      setChainId(undefined)
      return
    }

    const provider = (window as typeof window & { ethereum?: BrowserEthereumProvider }).ethereum
    if (!provider) {
      setChainId(undefined)
      return
    }

    let cancelled = false

    const sync = async () => {
      const nextChainId = await resolvePreferredChainId(provider, preferredChainIds, connectorId, walletAddress)
      if (!cancelled) setChainId(nextChainId)
    }

    const handleChainChanged = (value: unknown) => {
      if (cancelled) return

      const nextChainId = parseChainId(value)
      if (nextChainId !== undefined && preferredChainIds.includes(nextChainId)) {
        setChainId(nextChainId)
        return
      }

      void sync()
    }

    void sync()
    provider.on?.('chainChanged', handleChainChanged)
    for (const nestedProvider of Array.isArray(provider.providers) ? provider.providers : []) {
      nestedProvider.on?.('chainChanged', handleChainChanged)
    }

    return () => {
      cancelled = true
      provider.removeListener?.('chainChanged', handleChainChanged)
      for (const nestedProvider of Array.isArray(provider.providers) ? provider.providers : []) {
        nestedProvider.removeListener?.('chainChanged', handleChainChanged)
      }
    }
  }, [connectorId, enabled, preferredChainIds, walletAddress])

  return chainId
}