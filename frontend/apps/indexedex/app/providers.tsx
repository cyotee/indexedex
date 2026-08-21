'use client';
import { useEffect, useState } from 'react';
import { WagmiProvider, createConfig, createStorage, unstable_connector } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { base, baseSepolia, sepolia } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fallback, http } from 'viem';

import {
  DeploymentEnvironmentContext,
  DEFAULT_DEPLOYMENT_ENVIRONMENT,
} from '@indexedex/protocol/deploymentEnvironment';
import {
  CHAIN_ID_ROBINHOOD,
  CHAIN_ID_ROBINHOOD_TESTNET,
  setDefaultDeploymentEnvironment,
  type CanonicalArtifactChainId,
} from '@indexedex/protocol/addressArtifacts';
import {
  isCanonicalArtifactChainId,
  NetworkSelectionContext,
  SELECTED_NETWORK_STORAGE_KEY,
} from '@indexedex/protocol/networkSelection';
import { robinhood, robinhoodTestnet, robinhoodTestnetAnvil } from '@indexedex/protocol/runtimeChains';
import { BrandProvider } from './lib/brandContext';
import { isLocalRobinhoodTestnet, robinhoodTestnetRpcUrl } from './lib/localRpc';

const queryClient = new QueryClient();

const rhTestnetChain = isLocalRobinhoodTestnet()
  ? robinhoodTestnetAnvil(robinhoodTestnetRpcUrl())
  : robinhoodTestnet

/** Prefer the connected wallet's RPC; HTTP is SSR / disconnected fallback only. */
function walletFirstTransport(fallbackUrl: string) {
  return fallback([
    unstable_connector(injected, { retryCount: 0 }),
    http(fallbackUrl),
  ])
}

const wagmiConfig = createConfig({
  chains: [robinhood, rhTestnetChain, sepolia, baseSepolia, base],
  multiInjectedProviderDiscovery: false,
  ssr: true,
  storage: createStorage({ key: 'indexedex-wagmi-v3' }),
  connectors: [
    injected({ target: 'metaMask' }),
    injected({ target: 'coinbaseWallet' }),
    injected(),
  ],
  transports: {
    [robinhood.id]: walletFirstTransport(robinhood.rpcUrls.default.http[0]),
    [rhTestnetChain.id]: walletFirstTransport(rhTestnetChain.rpcUrls.default.http[0]),
    [sepolia.id]: walletFirstTransport(sepolia.rpcUrls.default.http[0]),
    [baseSepolia.id]: walletFirstTransport(baseSepolia.rpcUrls.default.http[0]),
    [base.id]: walletFirstTransport(base.rpcUrls.default.http[0]),
  },
});

function coerceIndexedexChainId(value: number): CanonicalArtifactChainId {
  if (value === CHAIN_ID_ROBINHOOD || value === CHAIN_ID_ROBINHOOD_TESTNET) return value
  return CHAIN_ID_ROBINHOOD_TESTNET
}

export function Providers({ children }: { children: React.ReactNode }) {
  const environment = DEFAULT_DEPLOYMENT_ENVIRONMENT;
  const setEnvironment = () => {};
  const [selectedChainId, setSelectedChainId] = useState<CanonicalArtifactChainId>(CHAIN_ID_ROBINHOOD_TESTNET);

  useEffect(() => {
    setDefaultDeploymentEnvironment(environment);
  }, [environment]);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const stored = Number(window.localStorage.getItem(SELECTED_NETWORK_STORAGE_KEY));
    if (Number.isFinite(stored) && isCanonicalArtifactChainId(stored)) {
      setSelectedChainId(coerceIndexedexChainId(stored));
    }
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(SELECTED_NETWORK_STORAGE_KEY, String(selectedChainId));
    }
  }, [selectedChainId]);

  return (
    <DeploymentEnvironmentContext.Provider value={{ environment, setEnvironment }}>
      <NetworkSelectionContext.Provider value={{ selectedChainId, setSelectedChainId }}>
        <BrandProvider>
          <WagmiProvider config={wagmiConfig}>
            <QueryClientProvider client={queryClient}>
              {children}
            </QueryClientProvider>
          </WagmiProvider>
        </BrandProvider>
      </NetworkSelectionContext.Provider>
    </DeploymentEnvironmentContext.Provider>
  );
}
