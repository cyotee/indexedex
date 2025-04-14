'use client'

import { useEffect, useState } from 'react'

type ChainAwareConnector = {
  id?: string
  getChainId: () => Promise<number>
  getProvider?: (parameters?: { chainId?: number | undefined }) => Promise<unknown>
}

type Eip1193ProviderLike = {
  chainId?: number | string
  selectedAddress?: string
  providers?: Eip1193ProviderLike[]
  getChainId?: () => Promise<number | string> | number | string
  request?: (args: { method: string }) => Promise<unknown>
}

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

async function getProviderChainId(provider: Eip1193ProviderLike | undefined): Promise<number | undefined> {
  if (!provider) return undefined

  try {
    const direct = typeof provider.getChainId === 'function' ? await provider.getChainId() : provider.chainId
    const parsed = parseChainId(direct)
    if (parsed !== undefined) return parsed
  } catch {}

  try {
    const requested = await provider.request?.({ method: 'eth_chainId' })
    return parseChainId(requested)
  } catch {
    return undefined
  }
}

async function providerHasAccount(provider: Eip1193ProviderLike, address: string): Promise<boolean> {
  const normalizedAddress = address.toLowerCase()

  if (typeof provider.selectedAddress === 'string' && provider.selectedAddress.toLowerCase() === normalizedAddress) {
    return true
  }

  try {
    const accounts = await provider.request?.({ method: 'eth_accounts' })
    return Array.isArray(accounts) && accounts.some((account) => typeof account === 'string' && account.toLowerCase() === normalizedAddress)
  } catch {
    return false
  }
}

async function getInjectedProviderChainId(
  connector: ChainAwareConnector,
  address: string | undefined,
  preferredChainIds: readonly number[],
): Promise<number | undefined> {
  if (!address || typeof connector.getProvider !== 'function') return undefined

  try {
    const provider = (await connector.getProvider()) as Eip1193ProviderLike | undefined
    if (!provider) return undefined

    const providers = Array.isArray(provider.providers) && provider.providers.length > 0
      ? provider.providers
      : [provider]
    const matchingChainIds: number[] = []

    for (const candidate of providers) {
      if (await providerHasAccount(candidate, address)) {
        const candidateChainId = await getProviderChainId(candidate)
        if (candidateChainId !== undefined) matchingChainIds.push(candidateChainId)
      }
    }

    for (const preferredChainId of preferredChainIds) {
      if (matchingChainIds.includes(preferredChainId)) return preferredChainId
    }

    return matchingChainIds[0]
  } catch {}

  return undefined
}

export function useConnectorChainId(
  connector: ChainAwareConnector | null | undefined,
  address?: string,
  preferredChainIds: readonly number[] = [],
): number | undefined {
  const [chainId, setChainId] = useState<number | undefined>(undefined)

  useEffect(() => {
    let cancelled = false

    if (!connector) {
      setChainId(undefined)
      return
    }

    const syncChainId = async () => {
      try {
        const injectedChainId = connector.id === 'injected'
          ? await getInjectedProviderChainId(connector, address, preferredChainIds)
          : undefined
        const nextChainId = injectedChainId ?? await connector.getChainId()
        if (!cancelled) setChainId(nextChainId)
      } catch {
        if (!cancelled) setChainId(undefined)
      }
    }

    void syncChainId()

    return () => {
      cancelled = true
    }
  }, [address, connector, preferredChainIds])

  return chainId
}