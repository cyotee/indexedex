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
import { getVaultRegistryAddress } from '@indexedex/protocol/registry/getVaultRegistryAddress'

import { createAppReadClient } from '../../create/lib/sePoolRead'
import { loadCreatedDetfs } from '../../lib/detf/createdDetfs'
import { entriesFromAddresses, loadRegisteredVaults, selectDetfsFromVaults } from '../../lib/detf/discoverDetfs'
import { mergeDetfs } from './mergeInsightDetfs'
import { indexTokens } from './tokenLabels'

export type { InsightDetf } from './mergeInsightDetfs'

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
