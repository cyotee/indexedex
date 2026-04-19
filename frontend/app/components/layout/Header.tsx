'use client';

import Link from 'next/link';
import { useState, useEffect, useRef } from 'react';
import Image from 'next/image';
import { useAccount, useChainId, useConnect, useConnection, useDisconnect, useSwitchChain } from 'wagmi';
import { baseSepolia, sepolia } from 'wagmi/chains';

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '../../lib/addressArtifacts';
import { useDeploymentEnvironment } from '../../lib/deploymentEnvironment';
import { useSelectedNetwork } from '../../lib/networkSelection';

type HeaderChainOption = 'ethereum' | 'base';

type BrowserEthereumProvider = {
  providers?: BrowserEthereumProvider[];
  isMetaMask?: boolean;
  isCoinbaseWallet?: boolean;
  selectedAddress?: string;
  chainId?: string;
  request?: (args: { method: string; params?: unknown[] }) => Promise<unknown>;
  on?: (event: 'chainChanged', listener: (chainId: string) => void) => void;
  removeListener?: (event: 'chainChanged', listener: (chainId: string) => void) => void;
};

type SwitchConnector = {
  id?: string;
  name?: string;
  rdns?: string | string[];
  getProvider?: () => Promise<BrowserEthereumProvider | undefined>;
};

type ConnectorLike = {
  id?: string;
  name?: string;
  rdns?: string | readonly string[];
};

type SwitchableChain = {
  option: HeaderChainOption;
  label: string;
  chainId: number;
  hexChainId: `0x${string}`;
  chainName: string;
  rpcUrls: string[];
  blockExplorerUrls?: string[];
};

type ChainSwitchNotice = {
  tone: 'info' | 'success';
  message: string;
};

type SwitchInspection = {
  connectorLooksMetaMask: boolean;
  connectorProviderIsMetaMask: boolean;
  browserProviderIsMetaMask: boolean;
  switchProviderIsMetaMask: boolean;
  summary: string;
};

const localRpcUrl = process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545';
const baseRpcUrl = process.env.NEXT_PUBLIC_BASE_RPC_URL ?? 'http://127.0.0.1:9545';

function isLocalSepoliaEnvironment(environment: string): boolean {
  return environment === 'supersim_sepolia';
}

function getSwitchableChains(environment: string): Record<HeaderChainOption, SwitchableChain> {
  const useLocalRpc = isLocalSepoliaEnvironment(environment);
  const ethereumRpcUrls = useLocalRpc
    ? [localRpcUrl]
    : [...sepolia.rpcUrls.default.http];
  const baseRpcUrls = useLocalRpc
    ? [baseRpcUrl]
    : [...baseSepolia.rpcUrls.default.http];

  return {
    ethereum: {
      option: 'ethereum',
      label: 'Ethereum Sepolia',
      chainId: sepolia.id,
      hexChainId: `0x${sepolia.id.toString(16)}`,
      chainName: sepolia.name,
      rpcUrls: ethereumRpcUrls,
      blockExplorerUrls: sepolia.blockExplorers?.default?.url ? [sepolia.blockExplorers.default.url] : undefined,
    },
    base: {
      option: 'base',
      label: 'Base Sepolia',
      chainId: baseSepolia.id,
      hexChainId: `0x${baseSepolia.id.toString(16)}`,
      chainName: baseSepolia.name,
      rpcUrls: baseRpcUrls,
      blockExplorerUrls: baseSepolia.blockExplorers?.default?.url ? [baseSepolia.blockExplorers.default.url] : undefined,
    },
  };
}

function resolveHeaderChainOption(chainId: number | undefined): HeaderChainOption {
  return chainId === baseSepolia.id ? 'base' : 'ethereum';
}

function connectorHasRdns(connector: ConnectorLike | undefined, value: string): boolean {
  if (!connector?.rdns) return false;
  return Array.isArray(connector.rdns) ? connector.rdns.includes(value) : connector.rdns === value;
}

function isMetaMaskConnector(connector: ConnectorLike | undefined): boolean {
  if (!connector) return false;
  return connector.id === 'metaMaskSDK'
    || connector.id === 'metaMask'
    || /metamask/i.test(connector.name ?? '')
    || connectorHasRdns(connector, 'io.metamask')
    || connectorHasRdns(connector, 'io.metamask.mobile');
}

function isCoinbaseConnector(connector: ConnectorLike | undefined): boolean {
  if (!connector) return false;
  return connector.id === 'coinbaseWallet' || connectorHasRdns(connector, 'com.coinbase.wallet');
}

function resolvePreferredConnector<T extends ConnectorLike>(connectors: readonly T[]): T | undefined {
  return connectors.find((connector) => isMetaMaskConnector(connector))
    ?? connectors.find((connector) => isCoinbaseConnector(connector))
    ?? connectors.find((connector) => connector.id === 'injected')
    ?? connectors[0];
}

function resolveFallbackConnector<T extends ConnectorLike>(
  connectors: readonly T[],
  preferredConnector: T | undefined,
): T | undefined {
  return connectors.find((connector) => connector.id === 'injected' && connector.id !== preferredConnector?.id)
    ?? connectors.find((connector) => !isMetaMaskConnector(connector) && connector.id !== preferredConnector?.id)
    ?? connectors.find((connector) => connector.id !== preferredConnector?.id);
}

function matchesConnectorProvider(provider: BrowserEthereumProvider, connectorId: string | undefined): boolean {
  if (provider.isMetaMask === true && isMetaMaskConnector({ id: connectorId })) return true;
  if (provider.isCoinbaseWallet === true && isCoinbaseConnector({ id: connectorId })) return true;
  if (provider.isMetaMask === true && !provider.isCoinbaseWallet) return true;
  if (!connectorId) return false;
  if (connectorId === 'metaMask' || connectorId === 'metaMaskSDK') return provider.isMetaMask === true;
  if (connectorId === 'coinbaseWallet') return provider.isCoinbaseWallet === true;
  return false;
}

function isMetaMaskProvider(provider: BrowserEthereumProvider | undefined): boolean {
  return provider?.isMetaMask === true && provider?.isCoinbaseWallet !== true;
}

function isBrowserInjectedConnector(connector: ConnectorLike | undefined): boolean {
  if (!connector) return false;

  return isMetaMaskConnector(connector)
    || isCoinbaseConnector(connector)
    || connector.id === 'injected';
}

function logChainSwitch(event: string, details: Record<string, unknown>) {
  console.info('[chain-switch]', event, details);
}

async function getProviderAccounts(provider: BrowserEthereumProvider | undefined): Promise<string[]> {
  if (!provider?.request) return [];

  try {
    const accounts = await provider.request({ method: 'eth_accounts' });
    return Array.isArray(accounts) ? accounts.filter((account): account is string => typeof account === 'string') : [];
  } catch {
    return [];
  }
}

async function matchesWalletAddress(provider: BrowserEthereumProvider, walletAddress: string | undefined): Promise<boolean> {
  if (!walletAddress) return false;

  const normalizedWalletAddress = walletAddress.toLowerCase();
  if (typeof provider.selectedAddress === 'string' && provider.selectedAddress.toLowerCase() === normalizedWalletAddress) {
    return true;
  }

  try {
    const accounts = await provider.request?.({ method: 'eth_accounts' });
    if (!Array.isArray(accounts)) return false;
    return accounts.some(
      (account): account is string => typeof account === 'string' && account.toLowerCase() === normalizedWalletAddress,
    );
  } catch {
    return false;
  }
}

async function readProviderChainId(provider: BrowserEthereumProvider | undefined): Promise<number | undefined> {
  if (!provider) return undefined;

  const rawChainId = await provider.request?.({ method: 'eth_chainId' }).catch(() => undefined)
    ?? provider.chainId;

  if (typeof rawChainId !== 'string') return undefined;

  const normalized = rawChainId.startsWith('0x')
    ? Number.parseInt(rawChainId, 16)
    : Number.parseInt(rawChainId, 10);

  return Number.isFinite(normalized) ? normalized : undefined;
}

async function waitForProviderChainId(
  provider: BrowserEthereumProvider | undefined,
  targetChainId: number,
  attempts = 6,
  delayMs = 250,
): Promise<number | undefined> {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const chainId = await readProviderChainId(provider);
    if (chainId === targetChainId) {
      return chainId;
    }

    if (attempt < attempts - 1) {
      await new Promise((resolve) => window.setTimeout(resolve, delayMs));
    }
  }

  return readProviderChainId(provider);
}

async function waitForAnyProviderChainId(
  targetChainId: number,
  providers: BrowserEthereumProvider[],
  attempts = 6,
  delayMs = 250,
): Promise<number | undefined> {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    for (const provider of providers) {
      const chainId = await readProviderChainId(provider);
      if (chainId === targetChainId) {
        return chainId;
      }
    }

    if (attempt < attempts - 1) {
      await new Promise((resolve) => window.setTimeout(resolve, delayMs));
    }
  }

  for (const provider of providers) {
    const chainId = await readProviderChainId(provider);
    if (typeof chainId === 'number') {
      return chainId;
    }
  }

  return undefined;
}

async function inspectSwitchContext(
  activeConnector: SwitchConnector | undefined,
  connectorId: string | undefined,
  address: string | undefined,
): Promise<{
  browserEthereum: BrowserEthereumProvider | undefined;
  connectorProvider: BrowserEthereumProvider | undefined;
  switchProvider: BrowserEthereumProvider | undefined;
  connectorLooksMetaMask: boolean;
  connectorProviderIsMetaMask: boolean;
  browserProviderIsMetaMask: boolean;
  switchProviderIsMetaMask: boolean;
  selectedAddress: string;
  selectedChainId: number | string;
  debugSummary: string;
}> {
  const browserEthereum = (window as typeof window & { ethereum?: BrowserEthereumProvider }).ethereum;
  const connectorProvider = activeConnector?.getProvider
    ? await activeConnector.getProvider().catch(() => undefined)
    : undefined;
  const nestedProviders = Array.isArray(browserEthereum?.providers) ? browserEthereum.providers : [];

  const candidateProviders = [connectorProvider, ...nestedProviders, browserEthereum]
    .filter((provider): provider is BrowserEthereumProvider => !!provider)
    .filter((provider, index, providers) => providers.indexOf(provider) === index);

  const providerMatches: Array<{
    provider: BrowserEthereumProvider;
    matchesConnector: boolean;
    matchesWallet: boolean;
  }> = await Promise.all(candidateProviders.map(async (provider) => ({
    provider,
    matchesConnector: matchesConnectorProvider(provider, connectorId),
    matchesWallet: await matchesWalletAddress(provider, address),
  })));

  const provider: BrowserEthereumProvider | undefined = providerMatches.find((entry) => entry.matchesConnector && entry.matchesWallet)?.provider
    ?? providerMatches.find((entry) => entry.matchesWallet)?.provider
    ?? providerMatches.find((entry) => entry.matchesConnector)?.provider
    ?? connectorProvider
    ?? browserEthereum;

  const directMetaMaskProvider = [browserEthereum, ...nestedProviders]
    .find((candidate) => isMetaMaskProvider(candidate));

  const switchProvider = connectorProvider
    ?? (isMetaMaskConnector(activeConnector)
      ? directMetaMaskProvider ?? provider
      : provider);

  const selectedChainId = await readProviderChainId(switchProvider);
  const connectorLooksMetaMask = isMetaMaskConnector(activeConnector);
  const connectorProviderIsMetaMask = isMetaMaskProvider(connectorProvider);
  const browserProviderIsMetaMask = isMetaMaskProvider(browserEthereum);
  const switchProviderIsMetaMask = isMetaMaskProvider(switchProvider);
  const debugSummary = [
    `connector=${activeConnector?.name ?? connectorId ?? 'none'}`,
    `connectorId=${connectorId ?? 'none'}`,
    `connectorMetaMask=${connectorLooksMetaMask ? 'yes' : 'no'}`,
    `connectorProviderMetaMask=${connectorProviderIsMetaMask ? 'yes' : 'no'}`,
    `browserProviderMetaMask=${browserProviderIsMetaMask ? 'yes' : 'no'}`,
    `switchProviderMetaMask=${switchProviderIsMetaMask ? 'yes' : 'no'}`,
    `selectedAddress=${switchProvider?.selectedAddress ?? 'unknown'}`,
    `selectedChain=${selectedChainId ?? switchProvider?.chainId ?? 'unknown'}`,
  ].join(' | ');

  return {
    browserEthereum,
    connectorProvider,
    switchProvider,
    connectorLooksMetaMask,
    connectorProviderIsMetaMask,
    browserProviderIsMetaMask,
    switchProviderIsMetaMask,
    selectedAddress: switchProvider?.selectedAddress ?? 'unknown',
    selectedChainId: selectedChainId ?? switchProvider?.chainId ?? 'unknown',
    debugSummary,
  };
}

export function Header() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { connectAsync, connectors, status, error } = useConnect();
  const connection = useConnection();
  const { disconnect } = useDisconnect();
  const { switchChainAsync } = useSwitchChain();
  const { environment } = useDeploymentEnvironment();
  const { selectedChainId, setSelectedChainId } = useSelectedNetwork();

  const preferredConnector = resolvePreferredConnector(connectors);
  const fallbackConnector = resolveFallbackConnector(connectors, preferredConnector);

  const [connectAttempted, setConnectAttempted] = useState(false);
  const [isOpeningWallet, setIsOpeningWallet] = useState(false);
  const [noPopupHint, setNoPopupHint] = useState(false);

  const [isTestnetDropdownOpen, setIsTestnetDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsTestnetDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const [styleTheme, setStyleTheme] = useState<string>('pachira')
  const [chainSwitchError, setChainSwitchError] = useState<string>('');
  const [chainSwitchDebug, setChainSwitchDebug] = useState<string>('');
  const [isPromptingWalletSwitch, setIsPromptingWalletSwitch] = useState(false);
  const [chainSwitchNotice, setChainSwitchNotice] = useState<ChainSwitchNotice | null>(null);
  const [switchInspection, setSwitchInspection] = useState<SwitchInspection | null>(null);

  const chainOptions = getSwitchableChains(environment);
  const selectedChainOption = resolveHeaderChainOption(selectedChainId);
  const activeConnector = (connection.connector ?? preferredConnector) as SwitchConnector | undefined;
  const connectorId = activeConnector?.id;
  const walletNeedsSwitchPrompt = isConnected
    && typeof chainId === 'number'
    && chainId !== selectedChainId
    && chainId !== CHAIN_ID_ANVIL
    && chainId !== CHAIN_ID_LOCALHOST;
  const selectedTargetChain = chainOptions[selectedChainOption];

  useEffect(() => {
    try {
      const saved = localStorage.getItem('style-theme')
      const theme = saved === 'current' ? 'current' : 'pachira'
      setStyleTheme(theme)
    } catch {}
  }, [])

  useEffect(() => {
    if (!chainSwitchNotice) return

    const timeout = window.setTimeout(() => {
      setChainSwitchNotice(null)
    }, 2500)

    return () => window.clearTimeout(timeout)
  }, [chainSwitchNotice])

  useEffect(() => {
    let cancelled = false;

    void inspectSwitchContext(activeConnector, connectorId, address)
      .then((context) => {
        if (cancelled) return;
        setSwitchInspection({
          connectorLooksMetaMask: context.connectorLooksMetaMask,
          connectorProviderIsMetaMask: context.connectorProviderIsMetaMask,
          browserProviderIsMetaMask: context.browserProviderIsMetaMask,
          switchProviderIsMetaMask: context.switchProviderIsMetaMask,
          summary: context.debugSummary,
        });
      })
      .catch(() => {
        if (cancelled) return;
        setSwitchInspection(null);
      });

    return () => {
      cancelled = true;
    };
  }, [activeConnector, connectorId, address, chainId]);

  useEffect(() => {
    const browserEthereum = (window as typeof window & { ethereum?: BrowserEthereumProvider }).ethereum
    if (!browserEthereum?.on || !browserEthereum?.removeListener) return

    const handleChainChanged = (nextChainId: string) => {
      const normalizedChainId = nextChainId.startsWith('0x')
        ? Number.parseInt(nextChainId, 16)
        : Number.parseInt(nextChainId, 10)

      logChainSwitch('chainChanged', { nextChainId, normalizedChainId })

      if (!Number.isFinite(normalizedChainId)) return

      setIsPromptingWalletSwitch(false)
      setChainSwitchError('')
      setChainSwitchDebug('')

      if (normalizedChainId === CHAIN_ID_ANVIL || normalizedChainId === CHAIN_ID_LOCALHOST) {
        return
      }

      const resolvedOption = resolveHeaderChainOption(normalizedChainId)
      setChainSwitchNotice({
        tone: 'success',
        message: `Wallet switched to ${chainOptions[resolvedOption].label}`,
      })
    }

    browserEthereum.on('chainChanged', handleChainChanged)
    return () => {
      browserEthereum.removeListener?.('chainChanged', handleChainChanged)
    }
  }, [chainOptions])

  function toggleTheme() {
    const next = styleTheme === 'pachira' ? 'current' : 'pachira'
    setStyleTheme(next)
    try {
      localStorage.setItem('style-theme', next)
    } catch {}
    if (typeof document !== 'undefined') {
      document.documentElement.setAttribute('data-theme', next)
    }
  }

  async function requestWalletChainSwitch(target: SwitchableChain, priorDebug?: string) {
    const context = await inspectSwitchContext(activeConnector, connectorId, address)
    const browserEthereum = context.browserEthereum
    const connectorProvider = context.connectorProvider
    const switchProvider = context.switchProvider

    const [browserAccounts, connectorAccounts, selectedAccounts] = await Promise.all([
      getProviderAccounts(browserEthereum),
      getProviderAccounts(connectorProvider),
      getProviderAccounts(switchProvider),
    ])

    const directDebugPrefix = [
      priorDebug,
      context.debugSummary,
      `target=${target.chainId}`,
      `hasConnectorProvider=${connectorProvider?.request ? 'yes' : 'no'}`,
      `selectedMetaMask=${switchProvider?.isMetaMask === true ? 'yes' : 'no'}`,
      `selectedCoinbase=${switchProvider?.isCoinbaseWallet === true ? 'yes' : 'no'}`,
      `selectedAddress=${switchProvider?.selectedAddress ?? 'unknown'}`,
      `selectedChain=${context.selectedChainId}`,
    ].filter(Boolean).join(' | ')

    setChainSwitchDebug(directDebugPrefix)
    logChainSwitch('requestWalletChainSwitch:selected-provider', {
      connectorId: connectorId ?? 'none',
      targetChainId: target.chainId,
      browserIsMetaMask: context.browserProviderIsMetaMask,
      connectorIsMetaMask: context.connectorProviderIsMetaMask,
      connectorLooksMetaMask: context.connectorLooksMetaMask,
      selectedMetaMask: context.switchProviderIsMetaMask,
      selectedCoinbase: switchProvider?.isCoinbaseWallet === true,
      browserEqualsConnectorProvider: Boolean(browserEthereum && connectorProvider && browserEthereum === connectorProvider),
      browserEqualsSwitchProvider: Boolean(browserEthereum && switchProvider && browserEthereum === switchProvider),
      connectorEqualsSwitchProvider: Boolean(connectorProvider && switchProvider && connectorProvider === switchProvider),
      browserAccounts,
      connectorAccounts,
      selectedAccounts,
      selectedAddress: switchProvider?.selectedAddress ?? 'unknown',
      selectedChainId: selectedChainId ?? switchProvider?.chainId ?? 'unknown',
    })

    if (!switchProvider?.request) {
      throw new Error('No injected wallet provider found')
    }

    try {
      logChainSwitch('requestWalletChainSwitch:wallet_switchEthereumChain:start', {
        targetChainId: target.chainId,
        targetHexChainId: target.hexChainId,
      })
      await switchProvider.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: target.hexChainId }],
      })
      const switchedChainId = await waitForProviderChainId(switchProvider, target.chainId)
      logChainSwitch('requestWalletChainSwitch:wallet_switchEthereumChain:result', {
        targetChainId: target.chainId,
        switchedChainId: switchedChainId ?? 'unknown',
      })
      if (switchedChainId === target.chainId) {
        setChainSwitchDebug((current) => `${current} | directSwitch=ok | providerAfter=${switchedChainId}`)
        return
      }

      setChainSwitchDebug((current) => `${current} | directSwitch=stale | providerAfter=${switchedChainId ?? 'unknown'}`)
      return
    } catch (error) {
      const code = typeof error === 'object' && error !== null && 'code' in error ? (error as { code?: number }).code : undefined
      const message = error instanceof Error ? error.message : String(error)
      logChainSwitch('requestWalletChainSwitch:wallet_switchEthereumChain:error', {
        code: code ?? 'unknown',
        message,
      })
      setChainSwitchDebug((current) => `${current} | directSwitch=${String(code ?? 'unknown')}:${message}`)
      if (code !== 4902) {
        throw error
      }
    }

    logChainSwitch('requestWalletChainSwitch:wallet_addEthereumChain:start', {
      targetChainId: target.chainId,
      targetHexChainId: target.hexChainId,
    })
    await switchProvider.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: target.hexChainId,
        chainName: target.chainName,
        nativeCurrency: {
          name: 'Ether',
          symbol: 'ETH',
          decimals: 18,
        },
        rpcUrls: target.rpcUrls,
        blockExplorerUrls: target.blockExplorerUrls,
      }],
    })
    const addedChainId = await waitForProviderChainId(switchProvider, target.chainId)
    logChainSwitch('requestWalletChainSwitch:wallet_addEthereumChain:result', {
      targetChainId: target.chainId,
      addedChainId: addedChainId ?? 'unknown',
    })
    setChainSwitchDebug((current) => `${current} | addChain=ok | providerAfter=${addedChainId ?? 'unknown'}`)
  }

  async function readActiveProviderChainId(): Promise<number | undefined> {
    const browserEthereum = (window as typeof window & { ethereum?: BrowserEthereumProvider }).ethereum
    if (browserEthereum?.request && isBrowserInjectedConnector(activeConnector)) {
      const browserChainId = await readProviderChainId(browserEthereum)
      if (typeof browserChainId === 'number') return browserChainId
    }

    const connectorProvider = activeConnector?.getProvider
      ? await activeConnector.getProvider().catch(() => undefined)
      : undefined
    const directChainId = await readProviderChainId(connectorProvider)
    if (typeof directChainId === 'number') return directChainId
    return readProviderChainId(browserEthereum)
  }

  async function handleChainSelection(nextOption: HeaderChainOption) {
    const target = chainOptions[nextOption]
    logChainSwitch('handleChainSelection:start', {
      nextOption,
      targetChainId: target.chainId,
      wagmiChainId: chainId ?? 'unknown',
    })
    setChainSwitchError('')
    setChainSwitchDebug('')

    if (nextOption === selectedChainOption) {
      setChainSwitchNotice(null)
      return
    }

    setSelectedChainId(target.chainId as typeof selectedChainId)

    if (!isConnected) {
      setChainSwitchNotice({ tone: 'success', message: `Showing ${target.label}` })
      return
    }

    if (chainId === CHAIN_ID_ANVIL || chainId === CHAIN_ID_LOCALHOST) {
      setChainSwitchDebug('')
      setChainSwitchNotice({
        tone: 'success',
        message: `Using local wallet chain ${chainId} for ${target.label}`,
      })
      return
    }

    logChainSwitch('handleChainSelection:provider-before', {
      providerChainIdBefore: chainId ?? 'unknown',
      targetChainId: target.chainId,
    })

    if (chainId === target.chainId) {
      setChainSwitchNotice({ tone: 'success', message: `Wallet already on ${target.label}` })
      return
    }

    await promptWalletSwitch(target)

    const providerChainIdAfter = await readActiveProviderChainId()
    if (providerChainIdAfter === target.chainId) {
      return
    }

    setChainSwitchNotice({
      tone: 'info',
      message: `Showing ${target.label}. Use the wallet switch button below to prompt your wallet from chain ${chainId ?? 'unknown'}.`,
    })
  }

  async function promptWalletSwitch(target: SwitchableChain) {
    setChainSwitchError('')
    setChainSwitchDebug('')
    setIsPromptingWalletSwitch(true)
    setChainSwitchNotice({ tone: 'info', message: `Requesting wallet switch to ${target.label}...` })

    const context = switchInspection
    const debugPrefix = `promptSwitch | ${context?.summary ?? `connector=${activeConnector?.name ?? connectorId ?? 'none'}`} | wagmiChain=${chainId ?? 'unknown'} | providerBefore=${chainId ?? 'unknown'} | target=${target.chainId}`
    setChainSwitchDebug(debugPrefix)

    const metaMaskSwitchAllowed = context != null
      && context.connectorLooksMetaMask
      && (context.connectorProviderIsMetaMask || context.browserProviderIsMetaMask || context.switchProviderIsMetaMask)

    if (!metaMaskSwitchAllowed) {
      setChainSwitchError('Wallet network switching is only enabled when the active connector is clearly MetaMask EVM. Reconnect with the MetaMask connector and try again.')
      setChainSwitchNotice(null)
      setIsPromptingWalletSwitch(false)
      return
    }

    try {
      const browserEthereum = (window as typeof window & { ethereum?: BrowserEthereumProvider }).ethereum
      const directMetaMaskProvider = isMetaMaskProvider(browserEthereum) ? browserEthereum : undefined

      if (directMetaMaskProvider?.request) {
        try {
          logChainSwitch('handleWalletSwitchPrompt:direct-metamask-switch:start', {
            targetChainId: target.chainId,
            targetHexChainId: target.hexChainId,
          })
          await directMetaMaskProvider.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: target.hexChainId }],
          })
          logChainSwitch('handleWalletSwitchPrompt:direct-metamask-switch:result', {
            targetChainId: target.chainId,
          })
        } catch (error) {
          const code = typeof error === 'object' && error !== null && 'code' in error ? (error as { code?: number }).code : undefined
          if (code === 4902) {
            logChainSwitch('handleWalletSwitchPrompt:direct-metamask-add:start', {
              targetChainId: target.chainId,
              targetHexChainId: target.hexChainId,
            })
            await directMetaMaskProvider.request({
              method: 'wallet_addEthereumChain',
              params: [{
                chainId: target.hexChainId,
                chainName: target.chainName,
                nativeCurrency: {
                  name: 'Ether',
                  symbol: 'ETH',
                  decimals: 18,
                },
                rpcUrls: target.rpcUrls,
                blockExplorerUrls: target.blockExplorerUrls,
              }],
            })
            logChainSwitch('handleWalletSwitchPrompt:direct-metamask-add:result', {
              targetChainId: target.chainId,
            })
          } else {
            throw error
          }
        }
      } else if (switchChainAsync) {
        logChainSwitch('handleWalletSwitchPrompt:wagmi-switch:start', {
          targetChainId: target.chainId,
          connectorId: connectorId ?? 'none',
        })
        await switchChainAsync({ chainId: target.chainId })
        logChainSwitch('handleWalletSwitchPrompt:wagmi-switch:result', {
          targetChainId: target.chainId,
        })
      } else {
        await requestWalletChainSwitch(target, debugPrefix)
      }

      const providerChainIdAfter = await readActiveProviderChainId()
      if (providerChainIdAfter !== target.chainId) {
        await requestWalletChainSwitch(target, `${debugPrefix} | wagmiProviderAfter=${providerChainIdAfter ?? 'unknown'}`)
      }

      const verifiedProviderChainId = await readActiveProviderChainId()
      if (verifiedProviderChainId === target.chainId) {
        setChainSwitchError('')
        setChainSwitchDebug('')
        setChainSwitchNotice({ tone: 'success', message: `Wallet switched to ${target.label}` })
        return
      }

      setChainSwitchError(`Wallet did not switch to ${target.label}. Current wallet chain is ${verifiedProviderChainId ?? 'unknown'}.`)
      setChainSwitchNotice(null)
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to switch wallet network'
      setChainSwitchError(message)
      setChainSwitchNotice(null)
    } finally {
      setIsPromptingWalletSwitch(false)
    }
  }

  async function handleWalletSwitchPrompt() {
    await promptWalletSwitch(selectedTargetChain)
  }

  return (
    <header className="border-b border-gray-700 bg-gray-800">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex min-h-16 py-2 justify-between items-center flex-wrap gap-2">
          <div className="flex items-center flex-wrap">
            <Link href="/" className="flex items-center flex-shrink-0">
              <Image src="/logo.svg" alt="Pachira" width={120} height={32} priority />
            </Link>
            <nav className="ml-4 lg:ml-10 flex flex-wrap gap-x-2 gap-y-1">
                <Link
                    href="/create"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Create
                </Link>
                <Link
                    href="/swap"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Swap
                </Link>
                <Link
                    href="/batch-swap"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Batch Swap
                </Link>
                <Link
                    href="/vaults"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Vaults
                </Link>
                <Link
                    href="/portfolio"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Portfolio
                </Link>
                <Link
                  href="/detfs"
                  className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                DETFs
                </Link>
                <Link
                  href="/staking"
                  className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Staking
                </Link>
                <Link
                    href="/insights"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Insights
                </Link>
                <Link
                    href="/pools"
                    className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors"
                >
                Pools
                </Link>
                <Link
                    href="/admin"
                    className="text-blue-300 hover:text-blue-200 px-3 py-2 text-sm font-medium transition-colors"
                >
                Admin
                </Link>
              {/* Testnet Dropdown */}
              <div className="relative" ref={dropdownRef}>
                <button
                  onClick={() => setIsTestnetDropdownOpen(!isTestnetDropdownOpen)}
                  className="text-orange-300 hover:text-orange-200 px-3 py-2 text-sm font-medium transition-colors flex items-center"
                >
                  Testnet
                  <svg
                    className={`ml-1 w-4 h-4 transition-transform ${isTestnetDropdownOpen ? 'rotate-180' : ''}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                
                {isTestnetDropdownOpen && (
                  <div className="absolute top-full left-0 mt-1 w-48 bg-gray-700 rounded-md shadow-lg z-50 border border-gray-600">
                    <div className="py-1">
                      <Link
                        href="/mint"
                        className="block px-4 py-2 text-sm text-yellow-300 hover:text-yellow-200 hover:bg-gray-600 transition-colors"
                        onClick={() => setIsTestnetDropdownOpen(false)}
                      >
                        Mint Test Tokens
                      </Link>
                      <Link
                        href="/token-info"
                            className="block px-4 py-2 text-sm text-yellow-300 hover:text-yellow-200 hover:bg-gray-600 transition-colors"
                        onClick={() => setIsTestnetDropdownOpen(false)}
                      >
                        Token Info
                      </Link>
                    </div>
                  </div>
                )}
              </div>
              
            </nav>
          </div>
          <div className="flex items-center gap-3 flex-shrink-0">
            <div className="flex flex-col items-end gap-1">
              <label className="text-[10px] uppercase tracking-wide text-gray-400" htmlFor="header-chain-selector">
                App Network
              </label>
              <select
                id="header-chain-selector"
                className="rounded-md border border-gray-600 bg-gray-700 px-2 py-1 text-xs text-gray-100"
                value={selectedChainOption}
                onChange={(event) => void handleChainSelection(event.target.value as HeaderChainOption)}
                disabled={isPromptingWalletSwitch}
                title="Select app network"
              >
                <option value="ethereum">Ethereum Sepolia</option>
                <option value="base">Base Sepolia</option>
              </select>
              <div className="max-w-[220px] text-right text-[10px] leading-tight text-gray-400">
                Selecting a network updates the app and prompts your wallet when a non-local wallet chain does not match.
              </div>
              {walletNeedsSwitchPrompt ? (
                <button
                  onClick={() => void handleWalletSwitchPrompt()}
                  disabled={isPromptingWalletSwitch}
                  className="rounded-md border border-sky-600 bg-sky-700 px-2 py-1 text-[10px] text-white hover:bg-sky-600 disabled:opacity-50"
                  title={`Prompt wallet to switch to ${selectedTargetChain.label}`}
                >
                  {isPromptingWalletSwitch ? 'Switching Wallet…' : `Switch Wallet Network to ${selectedTargetChain.label}`}
                </button>
              ) : null}
              {chainSwitchError ? (
                <div className="max-w-[220px] text-right text-[10px] leading-tight text-red-300">
                  {chainSwitchError}
                </div>
              ) : null}
              {!chainSwitchError && chainSwitchNotice ? (
                <div
                  className={[
                    'max-w-[220px] text-right text-[10px] leading-tight',
                    chainSwitchNotice.tone === 'success' ? 'text-emerald-300' : 'text-sky-300',
                  ].join(' ')}
                >
                  {chainSwitchNotice.message}
                </div>
              ) : null}
            </div>
            <button
              onClick={toggleTheme}
              className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600"
              aria-label="Toggle style theme"
              title="Toggle style theme"
            >
              Style: {styleTheme === 'pachira' ? 'Pachira' : 'Current'}
            </button>
            {isConnected ? (
              <button
                onClick={() => disconnect()}
                className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600"
                title={address}
              >
                {address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'Connected'}
              </button>
            ) : (
              <div className="flex flex-col items-end gap-1">
                <button
                  onClick={async () => {
                    setConnectAttempted(true);
                    setNoPopupHint(false);
                    if (!preferredConnector) {
                      console.warn('[wallet] No injected connector available');
                      return;
                    }
                    try {
                      setIsOpeningWallet(true);
                      const hintTimer = window.setTimeout(() => setNoPopupHint(true), 1200);

                      await connectAsync({ connector: preferredConnector });

                      window.clearTimeout(hintTimer);
                    } catch (e) {
                      console.error('[wallet] connectAsync failed', e);

                      if (fallbackConnector && fallbackConnector.id !== preferredConnector.id) {
                        try {
                          await connectAsync({ connector: fallbackConnector as typeof preferredConnector });
                        } catch (e2) {
                          console.error('[wallet] fallback connectAsync failed', e2);
                        }
                      }
                    }
                    setIsOpeningWallet(false);
                  }}
                  disabled={!preferredConnector || status === 'pending' || isOpeningWallet}
                  className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600 disabled:opacity-50"
                  title={error ? String(error?.message ?? error) : undefined}
                >
                  {status === 'pending' ? 'Connecting…' : isOpeningWallet ? 'Opening wallet…' : 'Connect Wallet'}
                </button>
                {connectAttempted && error ? (
                  <div className="text-[10px] leading-tight text-red-300 max-w-[240px] text-right">
                    {error.message}
                  </div>
                ) : noPopupHint ? (
                  <div className="text-[10px] leading-tight text-yellow-300 max-w-[240px] text-right">
                    No popup? Check your wallet extension / pop-up blocker.
                  </div>
                ) : null}
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
