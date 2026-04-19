'use client';
import { useEffect, useMemo, useState } from 'react';
import { WagmiProvider, createConfig, createStorage } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { base, baseSepolia, foundry, localhost, sepolia } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http } from 'viem';

import {
  DeploymentEnvironmentContext,
  DEFAULT_DEPLOYMENT_ENVIRONMENT,
} from './lib/deploymentEnvironment';
import { setDefaultDeploymentEnvironment } from './lib/addressArtifacts';
import {
  DEFAULT_SELECTED_CHAIN_ID,
  isCanonicalArtifactChainId,
  NetworkSelectionContext,
  SELECTED_NETWORK_STORAGE_KEY,
} from './lib/networkSelection';

const queryClient = new QueryClient();
const localRpcUrl = process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545';
const baseRpcUrl = process.env.NEXT_PUBLIC_BASE_RPC_URL ?? 'http://127.0.0.1:9545';
const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL ?? sepolia.rpcUrls.default.http[0];
const baseSepoliaRpcUrl = process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL ?? baseSepolia.rpcUrls.default.http[0];

function isLocalSepoliaEnvironment(environment: string): boolean {
  return environment === 'supersim_sepolia';
}

export function Providers({ children }: { children: React.ReactNode }) {
  const environment = DEFAULT_DEPLOYMENT_ENVIRONMENT;
  const setEnvironment = () => {};
  const [selectedChainId, setSelectedChainId] = useState(DEFAULT_SELECTED_CHAIN_ID);

  useEffect(() => {
    setDefaultDeploymentEnvironment(environment);
  }, [environment]);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const stored = Number(window.localStorage.getItem(SELECTED_NETWORK_STORAGE_KEY));
    if (Number.isFinite(stored) && isCanonicalArtifactChainId(stored)) {
      setSelectedChainId(stored);
    }
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(SELECTED_NETWORK_STORAGE_KEY, String(selectedChainId));
    }
  }, [selectedChainId]);

  const config = useMemo(
    () => {
      const useLocalRpc = isLocalSepoliaEnvironment(environment);

      return createConfig({
        chains: [sepolia, baseSepolia, foundry, localhost, base],
        multiInjectedProviderDiscovery: false,
        ssr: true,
        storage: createStorage({ key: 'indexedex-wagmi-v3' }),
        connectors: [
          injected({ target: 'metaMask' }),
          injected({ target: 'coinbaseWallet' }),
          injected(),
        ],
        transports: {
          [foundry.id]: http(localRpcUrl),
          [localhost.id]: http(localRpcUrl),
          [base.id]: http(base.rpcUrls.default.http[0]),
          [sepolia.id]: http(useLocalRpc ? localRpcUrl : sepoliaRpcUrl),
          [baseSepolia.id]: http(useLocalRpc ? baseRpcUrl : baseSepoliaRpcUrl),
        },
      })
    },
    [environment]
  );

  return (
    <DeploymentEnvironmentContext.Provider value={{ environment, setEnvironment }}>
      <NetworkSelectionContext.Provider value={{ selectedChainId, setSelectedChainId }}>
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            {children}
          </QueryClientProvider>
        </WagmiProvider>
      </NetworkSelectionContext.Provider>
    </DeploymentEnvironmentContext.Provider>
  );
}
