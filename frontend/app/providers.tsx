'use client';
import { useEffect, useMemo, useState } from 'react';
import { WagmiProvider, createConfig, createStorage } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { base, baseSepolia, foundry, localhost, sepolia } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http } from 'viem';

import {
  DeploymentEnvironmentContext,
  DeploymentEnvironmentToggle,
  DEFAULT_DEPLOYMENT_ENVIRONMENT,
  DEPLOYMENT_ENVIRONMENT_STORAGE_KEY,
  isDeploymentEnvironment,
} from './lib/deploymentEnvironment';
import { setDefaultDeploymentEnvironment } from './lib/addressArtifacts';

const queryClient = new QueryClient();
const localRpcUrl = process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545';
const baseRpcUrl = process.env.NEXT_PUBLIC_BASE_RPC_URL ?? 'http://127.0.0.1:9545';
const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL ?? sepolia.rpcUrls.default.http[0];
const baseSepoliaRpcUrl = process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL ?? baseSepolia.rpcUrls.default.http[0];

export function Providers({ children }: { children: React.ReactNode }) {
  const [environment, setEnvironment] = useState(DEFAULT_DEPLOYMENT_ENVIRONMENT);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const stored = window.localStorage.getItem(DEPLOYMENT_ENVIRONMENT_STORAGE_KEY);
    if (stored && isDeploymentEnvironment(stored)) {
      setEnvironment(stored);
      setDefaultDeploymentEnvironment(stored);
      return;
    }

    setDefaultDeploymentEnvironment(DEFAULT_DEPLOYMENT_ENVIRONMENT);
  }, []);

  useEffect(() => {
    setDefaultDeploymentEnvironment(environment);
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(DEPLOYMENT_ENVIRONMENT_STORAGE_KEY, environment);
    }
  }, [environment]);

  const config = useMemo(
    () =>
      createConfig({
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
          [sepolia.id]: http(environment === 'supersim_sepolia' ? localRpcUrl : sepoliaRpcUrl),
          [baseSepolia.id]: http(environment === 'supersim_sepolia' ? baseRpcUrl : baseSepoliaRpcUrl),
        },
      }),
    [environment]
  );

  return (
    <DeploymentEnvironmentContext.Provider value={{ environment, setEnvironment }}>
      <WagmiProvider config={config}>
        <QueryClientProvider client={queryClient}>
          {children}
          <DeploymentEnvironmentToggle />
        </QueryClientProvider>
      </WagmiProvider>
    </DeploymentEnvironmentContext.Provider>
  );
}
