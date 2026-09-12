'use client';
import { useEffect, useState } from 'react';
import { WagmiProvider, createConfig, createStorage, useAccount, type State } from 'wagmi';
import { RainbowKitProvider, connectorsForWallets, darkTheme } from '@rainbow-me/rainbowkit';
import { injectedWallet, metaMaskWallet, coinbaseWallet, rainbowWallet, walletConnectWallet } from '@rainbow-me/rainbowkit/wallets';
import { QueryClient, QueryClientProvider, useQueryClient } from '@tanstack/react-query';
import { walletFirstTransport } from './lib/walletFirstTransport'

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
import { BrandProvider } from './lib/brandContext'
import { getWalletChains, isLocalRobinhoodTestnet } from './lib/localRpc'

/** DTF launch target is Robinhood (4663) unless the 46630 Anvil rehearsal env is selected. */
const envDefaultChain = Number(process.env.NEXT_PUBLIC_DEFAULT_CHAIN_ID)
const DTF_DEFAULT_CHAIN_ID: CanonicalArtifactChainId =
  envDefaultChain === CHAIN_ID_ROBINHOOD || envDefaultChain === CHAIN_ID_ROBINHOOD_TESTNET
    ? envDefaultChain
    : process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT === 'anvil_robinhood_testnet'
      ? CHAIN_ID_ROBINHOOD_TESTNET
      : CHAIN_ID_ROBINHOOD

function resolveDtfEnvironment(): DeploymentEnvironment {
  const raw = process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT
  if (raw && isDeploymentEnvironment(raw)) return raw
  return 'anvil_robinhood_main'
}

function coerceDtfChainId(value: number): CanonicalArtifactChainId {
  if (walletChains.some((chain) => chain.id === value)) return value as CanonicalArtifactChainId
  return DTF_DEFAULT_CHAIN_ID
}

const walletChains = getWalletChains(DTF_DEFAULT_CHAIN_ID)
const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID?.trim() ?? ''
// Installed wallets work without a cloud project. Never initialize WalletConnect
// with a placeholder ID, or offer a mobile loopback connection on a local fork.
const wallets = projectId && !isLocalRobinhoodTestnet()
  ? [metaMaskWallet, rainbowWallet, coinbaseWallet, walletConnectWallet, injectedWallet]
  : [injectedWallet]
const config = createConfig({
  chains: walletChains,
  connectors: connectorsForWallets([{ groupName: 'Wallets', wallets }], { appName: 'IndexedEx', projectId }),
  multiInjectedProviderDiscovery: true,
  ssr: true,
  storage: createStorage({ key: `dtf-rainbowkit-${isLocalRobinhoodTestnet() ? 'local' : 'public'}-${DTF_DEFAULT_CHAIN_ID}` }),
  transports: Object.fromEntries(walletChains.map((chain) => [chain.id, walletFirstTransport(chain.id, chain.rpcUrls.default.http[0], getWalletState)])),
})
function getWalletState(): State { return config.state }

function WalletQueryBoundary({ children }: { children: React.ReactNode }) {
  const { status, address, chainId, connector } = useAccount()
  const client = useQueryClient()
  useEffect(() => {
    // Fork and public chain can share an ID. Drop readings from the previous
    // provider as well as from the previous account/network.
    void client.resetQueries()
  }, [client, status, address, chainId, connector?.uid])
  return children
}
const walletTheme = darkTheme({ accentColor: '#4FD44B', accentColorForeground: '#101710', borderRadius: 'medium', fontStack: 'system' })

export function Providers({ children }: { children: React.ReactNode }) {
  // DTF defaults to RH Anvil registry; override with NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT.
  const environment = resolveDtfEnvironment()
  const [queryClient] = useState(() => new QueryClient())
  const [networkRestored, setNetworkRestored] = useState(false)
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
    setNetworkRestored(true)
  }, [])

  useEffect(() => {
    if (networkRestored) {
      window.localStorage.setItem(SELECTED_NETWORK_STORAGE_KEY, String(selectedChainId))
    }
  }, [selectedChainId, networkRestored])

  return (
    <DeploymentEnvironmentContext.Provider value={{ environment, setEnvironment }}>
      <NetworkSelectionContext.Provider value={{ selectedChainId, setSelectedChainId }}>
        <BrandProvider>
          <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
              <RainbowKitProvider theme={walletTheme} initialChain={selectedChainId} modalSize="compact">
                <WalletQueryBoundary>{children}</WalletQueryBoundary>
              </RainbowKitProvider>
            </QueryClientProvider>
          </WagmiProvider>
        </BrandProvider>
      </NetworkSelectionContext.Provider>
    </DeploymentEnvironmentContext.Provider>
  );
}
