'use client'

import { useMemo } from 'react'
import { useReadContract } from 'wagmi'

import { getVaultRegistryAddress } from '@indexedex/protocol/registry/getVaultRegistryAddress'
import {
  filtersFromParsedEntry,
  parseUserSearchEntry,
  pickRegistryQuery,
  type KnownTokenHint,
  type ParsedUserEntry,
  type RegistryQuerySpec,
} from '@indexedex/protocol/registry/pickRegistryQuery'
import { vaultRegistryQueryAbi } from '@indexedex/protocol/registry/vaultRegistryAbi'
import type { DeploymentEnvironment } from '@indexedex/protocol/addressArtifacts'

export type UseVaultRegistrySearchArgs = {
  chainId: number
  environment: DeploymentEnvironment
  /** Raw search box text. */
  query: string
  /** Tokens used to resolve symbols → addresses for registry queries. */
  knownTokens?: readonly KnownTokenHint[]
}

function readConfig(spec: RegistryQuerySpec, registry: `0x${string}` | null, chainId: number) {
  if (!registry || spec.kind === 'none') {
    return { address: undefined as `0x${string}` | undefined, functionName: 'vaultsOfToken' as const, args: undefined as any, enabled: false }
  }
  switch (spec.kind) {
    case 'isVault':
      return {
        address: registry,
        functionName: 'isVault' as const,
        args: [spec.vault] as const,
        enabled: true,
      }
    case 'vaultsOfToken':
      return {
        address: registry,
        functionName: 'vaultsOfToken' as const,
        args: [spec.token] as const,
        enabled: true,
      }
    case 'vaultsOfType':
      return {
        address: registry,
        functionName: 'vaultsOfType' as const,
        args: [spec.typeId] as const,
        enabled: true,
      }
    case 'vaultsOfTypeOfToken':
      return {
        address: registry,
        functionName: 'vaultsOfTypeOfToken' as const,
        args: [spec.typeId, spec.token] as const,
        enabled: true,
      }
    case 'vaultsOfPackage':
      return {
        address: registry,
        functionName: 'vaultsOfPackage' as const,
        args: [spec.pkg] as const,
        enabled: true,
      }
    case 'vaultsOfPkgOfToken':
      return {
        address: registry,
        functionName: 'vaultsOfPkgOfToken' as const,
        args: [spec.pkg, spec.token] as const,
        enabled: true,
      }
    default:
      return { address: undefined as `0x${string}` | undefined, functionName: 'vaultsOfToken' as const, args: undefined as any, enabled: false }
  }
}

/**
 * When the user has entered a registry-capable query, call the matching view.
 * Empty query → enabled=false (caller shows preferred tokenlist).
 */
export function useVaultRegistrySearch({
  chainId,
  environment,
  query,
  knownTokens = [],
}: UseVaultRegistrySearchArgs) {
  const registry = useMemo(
    () => getVaultRegistryAddress(chainId, environment),
    [chainId, environment],
  )

  const parsed: ParsedUserEntry = useMemo(
    () => parseUserSearchEntry(query, knownTokens),
    [query, knownTokens],
  )

  const filters = useMemo(() => filtersFromParsedEntry(parsed), [parsed])
  const primarySpec = useMemo(() => pickRegistryQuery(filters), [filters])

  // For pasted addresses: also check isVault so a vault address surfaces even if
  // vaultsOfToken(that address) is empty.
  const secondaryIsVault =
    parsed.mode === 'address'
      ? ({ kind: 'isVault' as const, vault: parsed.address })
      : ({ kind: 'none' as const })

  const primary = readConfig(primarySpec, registry, chainId)
  const secondary = readConfig(secondaryIsVault, registry, chainId)

  // When primary is already isVault, don't double-call.
  const secondaryEnabled =
    secondary.enabled && primarySpec.kind !== 'isVault' && parsed.mode === 'address'

  const primaryRead = useReadContract({
    address: primary.address,
    abi: vaultRegistryQueryAbi,
    functionName: primary.functionName as any,
    args: primary.args as any,
    chainId,
    query: { enabled: primary.enabled && !!registry },
  })

  const secondaryRead = useReadContract({
    address: secondary.address,
    abi: vaultRegistryQueryAbi,
    functionName: 'isVault',
    args: secondaryEnabled && secondaryIsVault.kind === 'isVault' ? [secondaryIsVault.vault] : undefined,
    chainId,
    query: { enabled: secondaryEnabled && !!registry },
  })

  const registryAddresses = useMemo(() => {
    if (primarySpec.kind === 'none' && parsed.mode !== 'address') return [] as `0x${string}`[]

    const out: `0x${string}`[] = []
    const seen = new Set<string>()

    const push = (a: string) => {
      if (!/^0x[0-9a-fA-F]{40}$/.test(a)) return
      const k = a.toLowerCase()
      if (seen.has(k)) return
      seen.add(k)
      out.push(a as `0x${string}`)
    }

    if (primarySpec.kind === 'isVault') {
      // Dynamic functionName widens data typing; isVault returns bool.
      if ((primaryRead.data as unknown) === true) push(primarySpec.vault)
    } else if (Array.isArray(primaryRead.data)) {
      for (const a of primaryRead.data as string[]) push(a)
    }

    if (secondaryEnabled && (secondaryRead.data as unknown) === true && secondaryIsVault.kind === 'isVault') {
      push(secondaryIsVault.vault)
    }

    return out
  }, [primarySpec, primaryRead.data, secondaryEnabled, secondaryRead.data, secondaryIsVault, parsed.mode])

  const isRegistryMode =
    primarySpec.kind !== 'none' || parsed.mode === 'address' || parsed.mode === 'known-token'

  const isLoading =
    isRegistryMode &&
    (primaryRead.isFetching || (secondaryEnabled && secondaryRead.isFetching))

  const error =
    primaryRead.error?.message ||
    (secondaryEnabled ? secondaryRead.error?.message : undefined) ||
    (!registry && isRegistryMode ? 'Vault registry address not configured for this chain/env' : undefined)

  return {
    registry,
    parsed,
    primarySpec,
    isRegistryMode,
    registryAddresses,
    isLoading,
    error,
    refetch: () => {
      void primaryRead.refetch()
      if (secondaryEnabled) void secondaryRead.refetch()
    },
  }
}
