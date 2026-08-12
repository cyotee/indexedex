'use client';
import { useEffect, useMemo, useState } from 'react';
import { WagmiProvider, createConfig, createStorage } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { base, baseSepolia, foundry, localhost, sepolia } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http } from 'viem';

import {
  DeploymentEnvironmentContext,
  isDeploymentEnvironment,
} from '@indexedex/protocol/deploymentEnvironment'
import {
  CHAIN_ID_ROBINHOOD,
  setDefaultDeploymentEnvironment,
  type CanonicalArtifactChainId,
  type DeploymentEnvironment,
} from '@indexedex/protocol/addressArtifacts'
import {
  isCanonicalArtifactChainId,
  NetworkSelectionContext,
  SELECTED_NETWORK_STORAGE_KEY,
} from '@indexedex/protocol/networkSelection'
import { robinhoodAnvil } from '@indexedex/protocol/runtimeChains'
import { BrandProvider } from './lib/brandContext'

const queryClient = new QueryClient()
const localRpcUrl = process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545'
const baseRpcUrl = process.env.NEXT_PUBLIC_BASE_RPC_URL ?? 'http://127.0.0.1:9545'
const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL ?? sepolia.rpcUrls.default.http[0]
const baseSepoliaRpcUrl = process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL ?? baseSepolia.rpcUrls.default.http[0]

/** DTF launch target is Robinhood (4663); override with NEXT_PUBLIC_DEFAULT_CHAIN_ID. */
const envDefaultChain = Number(process.env.NEXT_PUBLIC_DEFAULT_CHAIN_ID)
const DTF_DEFAULT_CHAIN_ID: CanonicalArtifactChainId =
  Number.isFinite(envDefaultChain) && isCanonicalArtifactChainId(envDefaultChain)
    ? envDefaultChain
    : CHAIN_ID_ROBINHOOD

function isLocalSepoliaEnvironment(environment: string): boolean {
  // Both supersim and single-chain local_testing point sepolia/base-sepolia
  // wallet reads at the local Anvil/SuperSim RPC endpoints.
  return environment === 'supersim_sepolia' || environment === 'local_testing'
}

function resolveDtfEnvironment(): DeploymentEnvironment {
  const raw = process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT
  if (raw && isDeploymentEnvironment(raw)) return raw
  return 'anvil_robinhood_main'
}

export function Providers({ children }: { children: React.ReactNode }) {
  // DTF defaults to RH Anvil registry; override with NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT.
  const environment = resolveDtfEnvironment()
  const setEnvironment = () => {}
  const [selectedChainId, setSelectedChainId] =
    useState<CanonicalArtifactChainId>(DTF_DEFAULT_CHAIN_ID)

  useEffect(() => {
    setDefaultDeploymentEnvironment(environment)
  }, [environment])

  useEffect(() => {
    if (typeof window === 'undefined') return

    const stored = Number(window.localStorage.getItem(SELECTED_NETWORK_STORAGE_KEY))
    if (Number.isFinite(stored) && isCanonicalArtifactChainId(stored)) {
      setSelectedChainId(stored)
    }
  }, [])

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(SELECTED_NETWORK_STORAGE_KEY, String(selectedChainId))
    }
  }, [selectedChainId])

  const config = useMemo(() => {
    const useLocalRpc = isLocalSepoliaEnvironment(environment)
    // DTF always exposes Robinhood as Anvil-local RPC for launch testing.
    const rhChain = robinhoodAnvil(localRpcUrl)

    return createConfig({
      chains: [rhChain, sepolia, baseSepolia, foundry, localhost, base],
      multiInjectedProviderDiscovery: false,
      ssr: true,
      storage: createStorage({ key: 'dtf-wagmi-v3' }),
      connectors: [
        injected({ target: 'metaMask' }),
        injected({ target: 'coinbaseWallet' }),
        injected(),
      ],
      transports: {
        [CHAIN_ID_ROBINHOOD]: http(localRpcUrl),
        [foundry.id]: http(localRpcUrl),
        [localhost.id]: http(localRpcUrl),
        [base.id]: http(base.rpcUrls.default.http[0]),
        [sepolia.id]: http(useLocalRpc ? localRpcUrl : sepoliaRpcUrl),
        [baseSepolia.id]: http(useLocalRpc ? baseRpcUrl : baseSepoliaRpcUrl),
      },
    })
  }, [environment])

  return (
    <DeploymentEnvironmentContext.Provider value={{ environment, setEnvironment }}>
      <NetworkSelectionContext.Provider value={{ selectedChainId, setSelectedChainId }}>
        <BrandProvider>
          <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
              {children}
            </QueryClientProvider>
          </WagmiProvider>
        </BrandProvider>
      </NetworkSelectionContext.Provider>
    </DeploymentEnvironmentContext.Provider>
  );
}
