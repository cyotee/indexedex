'use client';
import { useEffect, useMemo, useState } from 'react';
import { WagmiProvider, createConfig, createStorage } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { base, baseSepolia, foundry, localhost, sepolia } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import {
  DeploymentEnvironmentContext,
  isDeploymentEnvironment,
} from '@indexedex/protocol/deploymentEnvironment'
import {
  CHAIN_ID_ROBINHOOD,
  CHAIN_ID_ROBINHOOD_TESTNET,
  setDefaultDeploymentEnvironment,
  type CanonicalArtifactChainId,
  type DeploymentEnvironment,
} from '@indexedex/protocol/addressArtifacts'
import {
  NetworkSelectionContext,
  SELECTED_NETWORK_STORAGE_KEY,
} from '@indexedex/protocol/networkSelection'
import { robinhood, robinhoodAnvil, robinhoodTestnet, robinhoodTestnetAnvil } from '@indexedex/protocol/runtimeChains'
import { BrandProvider } from './lib/brandContext'
import { isLocalRobinhoodTestnet, robinhoodTestnetRpcUrl } from './lib/localRpc'
import { walletFirstTransport } from './lib/walletFirstTransport'

const queryClient = new QueryClient()
const localRpcUrl = process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545'
const baseRpcUrl = process.env.NEXT_PUBLIC_BASE_RPC_URL ?? 'http://127.0.0.1:9545'
const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL ?? sepolia.rpcUrls.default.http[0]
const baseSepoliaRpcUrl = process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL ?? baseSepolia.rpcUrls.default.http[0]

/** DTF launch target is Robinhood (4663) unless the 46630 Anvil rehearsal env is selected. */
const envDefaultChain = Number(process.env.NEXT_PUBLIC_DEFAULT_CHAIN_ID)
const DTF_DEFAULT_CHAIN_ID: CanonicalArtifactChainId =
  envDefaultChain === CHAIN_ID_ROBINHOOD || envDefaultChain === CHAIN_ID_ROBINHOOD_TESTNET
    ? envDefaultChain
    : process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT === 'anvil_robinhood_testnet'
      ? CHAIN_ID_ROBINHOOD_TESTNET
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

function coerceDtfChainId(value: number): CanonicalArtifactChainId {
  if (value === CHAIN_ID_ROBINHOOD || value === CHAIN_ID_ROBINHOOD_TESTNET) return value
  return DTF_DEFAULT_CHAIN_ID
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
    if (Number.isFinite(stored)) {
      setSelectedChainId(coerceDtfChainId(stored))
    }
  }, [])

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(SELECTED_NETWORK_STORAGE_KEY, String(selectedChainId))
    }
  }, [selectedChainId])

  const config = useMemo(() => {
    const useLocalRpc = isLocalSepoliaEnvironment(environment)
    const rhChain = isLocalRobinhoodTestnet() ? robinhoodAnvil(localRpcUrl) : robinhood
    const rhTestnetChain = isLocalRobinhoodTestnet()
      ? robinhoodTestnetAnvil(robinhoodTestnetRpcUrl())
      : robinhoodTestnet

    return createConfig({
      chains: [rhChain, rhTestnetChain, sepolia, baseSepolia, foundry, localhost, base],
      multiInjectedProviderDiscovery: false,
      ssr: true,
      storage: createStorage({ key: 'dtf-wagmi-v3' }),
      connectors: [
        injected({ target: 'metaMask' }),
        injected({ target: 'coinbaseWallet' }),
        injected(),
      ],
      transports: {
        [CHAIN_ID_ROBINHOOD]: walletFirstTransport(rhChain.rpcUrls.default.http[0]),
        [CHAIN_ID_ROBINHOOD_TESTNET]: walletFirstTransport(rhTestnetChain.rpcUrls.default.http[0]),
        [foundry.id]: walletFirstTransport(localRpcUrl),
        [localhost.id]: walletFirstTransport(localRpcUrl),
        [base.id]: walletFirstTransport(base.rpcUrls.default.http[0]),
        [sepolia.id]: walletFirstTransport(useLocalRpc ? localRpcUrl : sepoliaRpcUrl),
        [baseSepolia.id]: walletFirstTransport(useLocalRpc ? baseRpcUrl : baseSepoliaRpcUrl),
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
