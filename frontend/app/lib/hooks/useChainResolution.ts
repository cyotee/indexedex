'use client'

import { useMemo } from 'react'
import { useAccount, useChainId, useConnection, useConnectorClient, useWalletClient } from 'wagmi'

import {
  CHAIN_ID_SEPOLIA,
  isSupportedChainId,
  resolveArtifactsChainId,
} from '../addressArtifacts'
import { useBrowserChainId, useConnectedWalletChainId } from '../browserChain'
import { useDeploymentEnvironment } from '../deploymentEnvironment'
import { useSelectedNetwork } from '../networkSelection'
import { resolveAppChain } from '../runtimeChains'

export type ChainSources = {
  account: number | undefined
  connection: number | undefined
  walletClient: number | undefined
  connectorClient: number | undefined
  connectorHook: number | undefined
  browser: number | undefined
  config: number
}

export type UseChainResolutionResult = {
  configChainId: number
  accountChainId: number | undefined
  attachedWalletChainId: number | undefined
  resolvedWalletChainId: number | null
  dataChainId: number
  walletMatchesDataChain: boolean
  isUnsupportedChain: boolean
  isConnected: boolean
  address: `0x${string}` | undefined
  environment: ReturnType<typeof useDeploymentEnvironment>['environment']
  selectedChainId: ReturnType<typeof useSelectedNetwork>['selectedChainId']
  targetChain: ReturnType<typeof resolveAppChain>
  chainSources: ChainSources
}

export function useChainResolution(fallbackChainId: number = CHAIN_ID_SEPOLIA): UseChainResolutionResult {
  const configChainId = useChainId()
  const { address, chainId: accountChainId, isConnected } = useAccount()
  const connection = useConnection()
  const connectedWalletChainId = useConnectedWalletChainId(isConnected, connection.connector)
  const browserChainId = useBrowserChainId(isConnected)
  const { data: connectorClient } = useConnectorClient()
  const { data: walletClient } = useWalletClient()
  const { environment } = useDeploymentEnvironment()
  const { selectedChainId } = useSelectedNetwork()

  const attachedWalletChainId = isConnected
    ? (accountChainId ?? connection.chainId ?? walletClient?.chain?.id ?? connectorClient?.chain?.id ?? connectedWalletChainId ?? browserChainId)
    : undefined

  const resolvedWalletChainId = attachedWalletChainId !== undefined
    ? resolveArtifactsChainId(attachedWalletChainId, environment, selectedChainId ?? undefined)
    : null

  const dataChainId = selectedChainId ?? fallbackChainId
  const walletMatchesDataChain = isConnected && attachedWalletChainId !== undefined && resolvedWalletChainId === dataChainId
  const isUnsupportedChain = isConnected && attachedWalletChainId !== undefined && !isSupportedChainId(attachedWalletChainId, environment)

  const chainSources = useMemo<ChainSources>(() => ({
    account: accountChainId,
    connection: connection.chainId,
    walletClient: walletClient?.chain?.id,
    connectorClient: connectorClient?.chain?.id,
    connectorHook: connectedWalletChainId,
    browser: browserChainId,
    config: configChainId,
  }), [
    accountChainId,
    connection.chainId,
    walletClient?.chain?.id,
    connectorClient?.chain?.id,
    connectedWalletChainId,
    browserChainId,
    configChainId,
  ])

  return {
    configChainId,
    accountChainId,
    attachedWalletChainId,
    resolvedWalletChainId,
    dataChainId,
    walletMatchesDataChain,
    isUnsupportedChain,
    isConnected,
    address,
    environment,
    selectedChainId,
    targetChain: resolveAppChain(dataChainId),
    chainSources,
  }
}

export default useChainResolution