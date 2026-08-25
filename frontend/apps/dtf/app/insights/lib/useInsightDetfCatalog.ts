'use client'

import { useEffect, useMemo, useState } from 'react'

import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import {
  getBaseTokensForChain,
  getStrategyVaultTokensForChain,
  isFeaturedFeeDetfAddress,
  type TokenListEntry,
} from '@indexedex/protocol/tokenlists'
import { loadFeaturedFeeDetfs, loadProtocolDetfsForChain } from '../../lib/earn/loadEarnProducts'
import { relabelChirEntry } from '../../lib/customerSymbols'
import { getVaultRegistryAddress } from '@indexedex/protocol/registry/getVaultRegistryAddress'

import { createAppReadClient } from '../../create/lib/sePoolRead'
import { loadCreatedDetfs } from '../../lib/detf/createdDetfs'
import { entriesFromAddresses, loadRegisteredVaults, selectDetfsFromVaults } from '../../lib/detf/discoverDetfs'
import { indexTokens } from './tokenLabels'

export type InsightDetf = TokenListEntry & { protocolFee: boolean }

function mergeDetfs(
  featured: TokenListEntry[],
  protocol: TokenListEntry[],
  registry: TokenListEntry[],
  created: TokenListEntry[],
  featuredSet: (addr: string) => boolean,
): InsightDetf[] {
  const out: InsightDetf[] = []
  const seen = new Set<string>()
  const add = (t: TokenListEntry, protocolFee: boolean) => {
    const k = t.address.toLowerCase()
    if (seen.has(k)) return
    seen.add(k)
    out.push({ ...relabelChirEntry(t), protocolFee })
  }
  for (let i = 0; i < featured.length; i++) add(featured[i]!, true)
  for (let i = 0; i < protocol.length; i++) {
    const t = protocol[i]!
    add(t, featuredSet(t.address))
  }
  for (let i = 0; i < created.length; i++) {
    const t = created[i]!
    add(t, featuredSet(t.address))
  }
  for (let i = 0; i < registry.length; i++) {
    const t = registry[i]!
    add(t, featuredSet(t.address))
  }
  return out
}

export function useInsightDetfCatalog() {
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const featured = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 50),
    [selectedChainId, environment],
  )
  const protocol = useMemo(
    () => loadProtocolDetfsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const [registryDetfs, setRegistryDetfs] = useState<TokenListEntry[]>([])
  const [createdDetfs, setCreatedDetfs] = useState<TokenListEntry[]>([])
  const [registryLoading, setRegistryLoading] = useState(false)
  const [registryError, setRegistryError] = useState<string | null>(null)

  useEffect(() => {
    setCreatedDetfs(loadCreatedDetfs(selectedChainId))
  }, [selectedChainId])

  useEffect(() => {
    let cancelled = false
    const registry = getVaultRegistryAddress(selectedChainId, environment)
    if (!registry) {
      setRegistryDetfs([])
      setRegistryError(null)
      setRegistryLoading(false)
      return
    }
    setRegistryLoading(true)
    setRegistryError(null)
    const client = createAppReadClient(selectedChainId)
    void (async () => {
      try {
        const vaults = await loadRegisteredVaults(client, registry)
        const detfAddresses = await selectDetfsFromVaults(client, vaults)
        const entries = await entriesFromAddresses(client, selectedChainId, detfAddresses)
        if (!cancelled) setRegistryDetfs(entries)
      } catch (error) {
        if (!cancelled) {
          setRegistryDetfs([])
          setRegistryError(String((error as { message?: string })?.message ?? error))
        }
      } finally {
        if (!cancelled) setRegistryLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [selectedChainId, environment])

  const detfs = useMemo(
    () =>
      mergeDetfs(featured, protocol, registryDetfs, createdDetfs, (addr) =>
        isFeaturedFeeDetfAddress(selectedChainId, environment, addr),
      ),
    [featured, protocol, registryDetfs, createdDetfs, selectedChainId, environment],
  )
  const labels = useMemo(
    () =>
      indexTokens([
        getBaseTokensForChain(selectedChainId, environment),
        getStrategyVaultTokensForChain(selectedChainId, environment),
        featured,
        protocol,
        registryDetfs,
        createdDetfs,
      ]),
    [selectedChainId, environment, featured, protocol, registryDetfs, createdDetfs],
  )

  return {
    selectedChainId,
    environment,
    detfs,
    labels,
    registryLoading,
    registryError,
  }
}
