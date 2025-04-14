"use strict";
'use client';
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Header = void 0;
const link_1 = __importDefault(require("next/link"));
const react_1 = require("react");
const image_1 = __importDefault(require("next/image"));
const wagmi_1 = require("wagmi");
const chains_1 = require("wagmi/chains");
const deploymentEnvironment_1 = require("../../lib/deploymentEnvironment");
const localRpcUrl = process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545';
const baseRpcUrl = process.env.NEXT_PUBLIC_BASE_RPC_URL ?? 'http://127.0.0.1:9545';
function getSwitchableChains(environment) {
  const ethereumRpcUrls = environment === 'supersim_sepolia'
    ? [localRpcUrl]
    : [...chains_1.sepolia.rpcUrls.default.http];
  const baseRpcUrls = environment === 'supersim_sepolia'
    ? [baseRpcUrl]
    : [...chains_1.baseSepolia.rpcUrls.default.http];
  return {
    ethereum: {
      option: 'ethereum',
      label: 'Ethereum',
      chainId: chains_1.sepolia.id,
      hexChainId: `0x${chains_1.sepolia.id.toString(16)}`,
      chainName: chains_1.sepolia.name,
      rpcUrls: ethereumRpcUrls,
      blockExplorerUrls: chains_1.sepolia.blockExplorers?.default?.url ? [chains_1.sepolia.blockExplorers.default.url] : undefined,
    },
    base: {
      option: 'base',
      label: 'Base',
      chainId: chains_1.baseSepolia.id,
      hexChainId: `0x${chains_1.baseSepolia.id.toString(16)}`,
      chainName: chains_1.baseSepolia.name,
      rpcUrls: baseRpcUrls,
      blockExplorerUrls: chains_1.baseSepolia.blockExplorers?.default?.url ? [chains_1.baseSepolia.blockExplorers.default.url] : undefined,
    },
  };
}
function resolveHeaderChainOption(chainId) {
  return chainId === chains_1.baseSepolia.id ? 'base' : 'ethereum';
}
function connectorHasRdns(connector, value) {
  if (!connector?.rdns)
    return false;
  return Array.isArray(connector.rdns) ? connector.rdns.includes(value) : connector.rdns === value;
}
function isMetaMaskConnector(connector) {
  if (!connector)
    return false;
  return connector.id === 'metaMaskSDK'
    || connector.id === 'metaMask'
    || /metamask/i.test(connector.name ?? '')
    || connectorHasRdns(connector, 'io.metamask')
    || connectorHasRdns(connector, 'io.metamask.mobile');
}
function isCoinbaseConnector(connector) {
  if (!connector)
    return false;
  return connector.id === 'coinbaseWallet' || connectorHasRdns(connector, 'com.coinbase.wallet');
}
function resolvePreferredConnector(connectors) {
  return connectors.find((connector) => isMetaMaskConnector(connector))
    ?? connectors.find((connector) => isCoinbaseConnector(connector))
    ?? connectors.find((connector) => connector.id === 'injected')
    ?? connectors[0];
}
function resolveFallbackConnector(connectors, preferredConnector) {
  return connectors.find((connector) => connector.id === 'injected' && connector.id !== preferredConnector?.id)
    ?? connectors.find((connector) => !isMetaMaskConnector(connector) && connector.id !== preferredConnector?.id)
    ?? connectors.find((connector) => connector.id !== preferredConnector?.id);
}
function matchesConnectorProvider(provider, connectorId) {
  if (provider.isMetaMask === true && isMetaMaskConnector({ id: connectorId }))
    return true;
  if (provider.isCoinbaseWallet === true && isCoinbaseConnector({ id: connectorId }))
    return true;
  if (provider.isMetaMask === true && !provider.isCoinbaseWallet)
    return true;
  if (!connectorId)
    return false;
  if (connectorId === 'metaMask' || connectorId === 'metaMaskSDK')
    return provider.isMetaMask === true;
  if (connectorId === 'coinbaseWallet')
    return provider.isCoinbaseWallet === true;
  return false;
}
function isMetaMaskProvider(provider) {
  return provider?.isMetaMask === true && provider?.isCoinbaseWallet !== true;
}
function isBrowserInjectedConnector(connector) {
  if (!connector)
    return false;
  return isMetaMaskConnector(connector)
    || isCoinbaseConnector(connector)
    || connector.id === 'injected';
}
function logChainSwitch(event, details) {
  console.info('[chain-switch]', event, details);
}
async function getProviderAccounts(provider) {
  if (!provider?.request)
    return [];
  try {
    const accounts = await provider.request({ method: 'eth_accounts' });
    return Array.isArray(accounts) ? accounts.filter((account) => typeof account === 'string') : [];
  }
  catch {
    return [];
  }
}
async function matchesWalletAddress(provider, walletAddress) {
  if (!walletAddress)
    return false;
  const normalizedWalletAddress = walletAddress.toLowerCase();
  if (typeof provider.selectedAddress === 'string' && provider.selectedAddress.toLowerCase() === normalizedWalletAddress) {
    return true;
  }
  try {
    const accounts = await provider.request?.({ method: 'eth_accounts' });
    if (!Array.isArray(accounts))
      return false;
    return accounts.some((account) => typeof account === 'string' && account.toLowerCase() === normalizedWalletAddress);
  }
  catch {
    return false;
  }
}
async function readProviderChainId(provider) {
  if (!provider)
    return undefined;
  const rawChainId = await provider.request?.({ method: 'eth_chainId' }).catch(() => undefined)
    ?? provider.chainId;
  if (typeof rawChainId !== 'string')
    return undefined;
  const normalized = rawChainId.startsWith('0x')
    ? Number.parseInt(rawChainId, 16)
    : Number.parseInt(rawChainId, 10);
  return Number.isFinite(normalized) ? normalized : undefined;
}
async function waitForProviderChainId(provider, targetChainId, attempts = 6, delayMs = 250) {
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
async function waitForAnyProviderChainId(targetChainId, providers, attempts = 6, delayMs = 250) {
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
function Header() {
    const { address, isConnected } = (0, wagmi_1.useAccount)();
  const chainId = (0, wagmi_1.useChainId)();
    const { connectAsync, connectors, status, error } = (0, wagmi_1.useConnect)();
  const connection = (0, wagmi_1.useConnection)();
    const { disconnect } = (0, wagmi_1.useDisconnect)();
  const { switchChainAsync, isPending: isSwitchingChain } = (0, wagmi_1.useSwitchChain)();
  const { environment } = (0, deploymentEnvironment_1.useDeploymentEnvironment)();
    const availableConnectors = connectors;
    const preferredConnector = resolvePreferredConnector(availableConnectors);
    const fallbackConnector = resolveFallbackConnector(availableConnectors, preferredConnector);
    const [connectAttempted, setConnectAttempted] = (0, react_1.useState)(false);
    const [isOpeningWallet, setIsOpeningWallet] = (0, react_1.useState)(false);
    const [noPopupHint, setNoPopupHint] = (0, react_1.useState)(false);
    const [isTestnetDropdownOpen, setIsTestnetDropdownOpen] = (0, react_1.useState)(false);
    const dropdownRef = (0, react_1.useRef)(null);
    // Close dropdown when clicking outside
    (0, react_1.useEffect)(() => {
        const handleClickOutside = (event) => {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
                setIsTestnetDropdownOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => {
            document.removeEventListener('mousedown', handleClickOutside);
        };
    }, []);
    const [styleTheme, setStyleTheme] = (0, react_1.useState)('pachira');
    const [chainSwitchError, setChainSwitchError] = (0, react_1.useState)('');
    const [chainSwitchDebug, setChainSwitchDebug] = (0, react_1.useState)('');
    const [pendingChainOption, setPendingChainOption] = (0, react_1.useState)(null);
    const [chainSwitchNotice, setChainSwitchNotice] = (0, react_1.useState)(null);
    const chainOptions = getSwitchableChains(environment);
    const selectedChainOption = pendingChainOption ?? resolveHeaderChainOption(chainId);
    const activeConnector = connection.connector ?? preferredConnector;
    const connectorId = activeConnector?.id;
    (0, react_1.useEffect)(() => {
        try {
            const saved = localStorage.getItem('style-theme');
            const theme = saved === 'current' ? 'current' : 'pachira';
            setStyleTheme(theme);
        }
        catch { }
    }, []);
    (0, react_1.useEffect)(() => {
      if (pendingChainOption && resolveHeaderChainOption(chainId) === pendingChainOption) {
        setPendingChainOption(null);
        setChainSwitchError('');
        setChainSwitchDebug('');
        setChainSwitchNotice({
          tone: 'success',
          message: `Wallet switched to ${chainOptions[resolveHeaderChainOption(chainId)].label}`,
        });
        return;
      }
      if (!isSwitchingChain) {
        setPendingChainOption(null);
      }
    }, [chainId, chainOptions, isSwitchingChain, pendingChainOption]);
    (0, react_1.useEffect)(() => {
      if (!chainSwitchNotice)
        return;
      const timeout = window.setTimeout(() => {
        setChainSwitchNotice(null);
      }, 2500);
      return () => window.clearTimeout(timeout);
    }, [chainSwitchNotice]);
    (0, react_1.useEffect)(() => {
      const browserEthereum = window.ethereum;
      if (!browserEthereum?.on || !browserEthereum?.removeListener)
        return;
      const handleChainChanged = (nextChainId) => {
        const normalizedChainId = nextChainId.startsWith('0x')
          ? Number.parseInt(nextChainId, 16)
          : Number.parseInt(nextChainId, 10);
        logChainSwitch('chainChanged', { nextChainId, normalizedChainId });
        if (!Number.isFinite(normalizedChainId))
          return;
        setPendingChainOption(null);
        setChainSwitchError('');
        setChainSwitchDebug('');
        const resolvedOption = resolveHeaderChainOption(normalizedChainId);
        setChainSwitchNotice({
          tone: 'success',
          message: `Wallet switched to ${chainOptions[resolvedOption].label}`,
        });
      };
      browserEthereum.on('chainChanged', handleChainChanged);
      return () => {
        browserEthereum.removeListener?.('chainChanged', handleChainChanged);
      };
    }, [chainOptions]);
    function toggleTheme() {
        const next = styleTheme === 'pachira' ? 'current' : 'pachira';
        setStyleTheme(next);
        try {
            localStorage.setItem('style-theme', next);
        }
        catch { }
        if (typeof document !== 'undefined') {
            document.documentElement.setAttribute('data-theme', next);
        }
    }
      async function requestWalletChainSwitch(target, priorDebug) {
      const browserEthereum = window.ethereum;
      const connectorProvider = await activeConnector?.getProvider?.().catch(() => undefined);
      const preferBrowserProvider = Boolean(browserEthereum?.request) && isBrowserInjectedConnector(activeConnector);
      const nestedProviders = Array.isArray(browserEthereum?.providers) ? browserEthereum.providers : [];
        const candidateProviders = [connectorProvider, ...nestedProviders, browserEthereum]
          .filter((provider) => !!provider)
          .filter((provider, index, providers) => providers.indexOf(provider) === index);
      const providerMatches = await Promise.all(candidateProviders.map(async (provider) => ({
        provider,
        matchesConnector: matchesConnectorProvider(provider, connectorId),
        matchesWallet: await matchesWalletAddress(provider, address),
      })));
      const provider = providerMatches.find((entry) => entry.matchesConnector && entry.matchesWallet)?.provider
        ?? providerMatches.find((entry) => entry.matchesWallet)?.provider
        ?? providerMatches.find((entry) => entry.matchesConnector)?.provider
        ?? connectorProvider
        ?? browserEthereum;
        const directMetaMaskProvider = [browserEthereum, ...nestedProviders]
            .find((candidate) => isMetaMaskProvider(candidate));
        const switchProvider = preferBrowserProvider
          ? browserEthereum
          : isMetaMaskConnector(activeConnector)
            ? directMetaMaskProvider ?? provider
            : provider;
        const [browserAccounts, connectorAccounts, selectedAccounts] = await Promise.all([
          getProviderAccounts(browserEthereum),
          getProviderAccounts(connectorProvider),
          getProviderAccounts(switchProvider),
        ]);
        const selectedChainId = await readProviderChainId(switchProvider);
        const directDebugPrefix = [
            priorDebug,
            `connector=${connectorId ?? 'none'}`,
          `target=${target.chainId}`,
            `candidates=${candidateProviders.length}`,
            `selectedMetaMask=${switchProvider?.isMetaMask === true ? 'yes' : 'no'}`,
            `selectedCoinbase=${switchProvider?.isCoinbaseWallet === true ? 'yes' : 'no'}`,
            `selectedAddress=${switchProvider?.selectedAddress ?? 'unknown'}`,
            `selectedChain=${selectedChainId ?? switchProvider?.chainId ?? 'unknown'}`,
        ].filter(Boolean).join(' | ');
        setChainSwitchDebug(directDebugPrefix);
        logChainSwitch('requestWalletChainSwitch:selected-provider', {
            connectorId: connectorId ?? 'none',
            targetChainId: target.chainId,
            candidateProviders: candidateProviders.length,
          preferBrowserProvider,
          browserHasProvidersArray: Array.isArray(browserEthereum?.providers),
          browserProvidersCount: nestedProviders.length,
          browserIsMetaMask: browserEthereum?.isMetaMask === true,
          connectorIsMetaMask: connectorProvider?.isMetaMask === true,
            selectedMetaMask: switchProvider?.isMetaMask === true,
            selectedCoinbase: switchProvider?.isCoinbaseWallet === true,
          browserEqualsConnectorProvider: Boolean(browserEthereum && connectorProvider && browserEthereum === connectorProvider),
          browserEqualsSwitchProvider: Boolean(browserEthereum && switchProvider && browserEthereum === switchProvider),
          connectorEqualsSwitchProvider: Boolean(connectorProvider && switchProvider && connectorProvider === switchProvider),
          browserAccounts,
          connectorAccounts,
          selectedAccounts,
            selectedAddress: switchProvider?.selectedAddress ?? 'unknown',
            selectedChainId: selectedChainId ?? switchProvider?.chainId ?? 'unknown',
        });
        if (!switchProvider?.request) {
          throw new Error('No injected wallet provider found');
        }
        try {
          logChainSwitch('requestWalletChainSwitch:wallet_switchEthereumChain:start', {
            targetChainId: target.chainId,
            targetHexChainId: target.hexChainId,
          });
          await switchProvider.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: target.hexChainId }],
          });
          const switchedChainId = preferBrowserProvider
            ? await waitForAnyProviderChainId(target.chainId, [browserEthereum, connectorProvider].filter((entry) => Boolean(entry)))
            : await waitForProviderChainId(switchProvider, target.chainId);
          logChainSwitch('requestWalletChainSwitch:wallet_switchEthereumChain:result', {
            targetChainId: target.chainId,
            switchedChainId: switchedChainId ?? 'unknown',
          });
          if (switchedChainId === target.chainId) {
            setChainSwitchDebug((current) => `${current} | directSwitch=ok | providerAfter=${switchedChainId}`);
            return;
          }
          setChainSwitchDebug((current) => `${current} | directSwitch=stale | providerAfter=${switchedChainId ?? 'unknown'}`);
          return;
        }
        catch (error) {
          const code = typeof error === 'object' && error !== null && 'code' in error ? error.code : undefined;
          const message = error instanceof Error ? error.message : String(error);
          logChainSwitch('requestWalletChainSwitch:wallet_switchEthereumChain:error', {
            code: code ?? 'unknown',
            message,
          });
          setChainSwitchDebug((current) => `${current} | directSwitch=${String(code ?? 'unknown')}:${message}`);
          if (code !== 4902) {
            throw error;
          }
        }
        logChainSwitch('requestWalletChainSwitch:wallet_addEthereumChain:start', {
          targetChainId: target.chainId,
          targetHexChainId: target.hexChainId,
        });
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
        });
        const addedChainId = preferBrowserProvider
          ? await waitForAnyProviderChainId(target.chainId, [browserEthereum, connectorProvider].filter((entry) => Boolean(entry)))
          : await waitForProviderChainId(switchProvider, target.chainId);
        logChainSwitch('requestWalletChainSwitch:wallet_addEthereumChain:result', {
          targetChainId: target.chainId,
          addedChainId: addedChainId ?? 'unknown',
        });
        setChainSwitchDebug((current) => `${current} | addChain=ok | providerAfter=${addedChainId ?? 'unknown'}`);
      }
      async function readActiveProviderChainId() {
        const browserEthereum = window.ethereum;
        if (browserEthereum?.request && isBrowserInjectedConnector(activeConnector)) {
          const browserChainId = await readProviderChainId(browserEthereum);
          if (typeof browserChainId === 'number')
            return browserChainId;
        }
        const connectorProvider = activeConnector?.getProvider
          ? await activeConnector.getProvider().catch(() => undefined)
          : undefined;
        const directChainId = await readProviderChainId(connectorProvider);
        if (typeof directChainId === 'number')
          return directChainId;
        return readProviderChainId(browserEthereum);
      }
      async function handleChainSelection(nextOption) {
        const target = chainOptions[nextOption];
        logChainSwitch('handleChainSelection:start', {
          nextOption,
          targetChainId: target.chainId,
          wagmiChainId: chainId ?? 'unknown',
        });
        setChainSwitchError('');
        setChainSwitchDebug('');
        setChainSwitchNotice({ tone: 'info', message: `Switching wallet to ${target.label}...` });
        if (nextOption === selectedChainOption) {
          setChainSwitchNotice(null);
          return;
        }
        setPendingChainOption(nextOption);
        const providerChainIdBefore = await readActiveProviderChainId();
        logChainSwitch('handleChainSelection:provider-before', {
          providerChainIdBefore: providerChainIdBefore ?? 'unknown',
          targetChainId: target.chainId,
        });
        if (providerChainIdBefore === target.chainId) {
          setPendingChainOption(null);
          setChainSwitchNotice({ tone: 'success', message: `Wallet already on ${target.label}` });
          return;
        }
        let wagmiError;
        let wagmiDebug = `preSwitch | connector=${connectorId ?? 'none'} | wagmiChain=${chainId ?? 'unknown'} | providerBefore=${providerChainIdBefore ?? 'unknown'} | target=${target.chainId}`;
        try {
          logChainSwitch('handleChainSelection:wagmi-switch:start', {
            targetChainId: target.chainId,
          });
          await switchChainAsync({ chainId: target.chainId });
          const browserEthereum = window.ethereum;
          const connectorProvider = activeConnector?.getProvider
            ? await activeConnector.getProvider().catch(() => undefined)
            : undefined;
          const providerChainId = isBrowserInjectedConnector(activeConnector) && browserEthereum?.request
            ? await waitForAnyProviderChainId(target.chainId, [browserEthereum, connectorProvider].filter((entry) => Boolean(entry)))
            : await waitForProviderChainId(connectorProvider, target.chainId);
          logChainSwitch('handleChainSelection:wagmi-switch:result', {
            targetChainId: target.chainId,
            providerChainId: providerChainId ?? 'unknown',
          });
          if (providerChainId === target.chainId) {
            setChainSwitchDebug('');
            return;
          }
          wagmiDebug = `wagmiSwitch=stale | connector=${connectorId ?? 'none'} | wagmiChain=${chainId ?? 'unknown'} | providerBefore=${providerChainIdBefore ?? 'unknown'} | target=${target.chainId} | provider=${providerChainId ?? 'unknown'}`;
          setChainSwitchDebug(wagmiDebug);
        }
        catch (error) {
          wagmiError = error;
          const message = error instanceof Error ? error.message : String(error);
          logChainSwitch('handleChainSelection:wagmi-switch:error', { message });
          wagmiDebug = `wagmiSwitch=error:${message} | connector=${connectorId ?? 'none'} | wagmiChain=${chainId ?? 'unknown'} | providerBefore=${providerChainIdBefore ?? 'unknown'} | target=${target.chainId}`;
          setChainSwitchDebug(wagmiDebug);
        }
        try {
          await requestWalletChainSwitch(target, wagmiDebug);
          const providerChainId = await readActiveProviderChainId();
          if (providerChainId === target.chainId) {
            setChainSwitchDebug('');
            return;
          }
        }
        catch (fallbackError) {
          const message = fallbackError instanceof Error
            ? fallbackError.message
            : wagmiError instanceof Error
              ? wagmiError.message
              : 'Failed to switch wallet network';
          setChainSwitchError(message);
          setChainSwitchNotice(null);
          setPendingChainOption(null);
          return;
        }
        setPendingChainOption(null);
      }
    return (<header className="border-b border-gray-700 bg-gray-800">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex min-h-16 py-2 justify-between items-center flex-wrap gap-2">
          <div className="flex items-center flex-wrap">
            <link_1.default href="/" className="flex items-center flex-shrink-0">
              <image_1.default src="/logo.svg" alt="Pachira" width={120} height={32} priority/>
            </link_1.default>
            <nav className="ml-4 lg:ml-10 flex flex-wrap gap-x-2 gap-y-1">
                <link_1.default href="/create" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Create
                </link_1.default>
                <link_1.default href="/swap" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Swap
                </link_1.default>
                <link_1.default href="/batch-swap" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Batch Swap
                </link_1.default>
                <link_1.default href="/vaults" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Vaults
                </link_1.default>
                <link_1.default href="/portfolio" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Portfolio
                </link_1.default>
                <link_1.default href="/detfs" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                DETFs
                </link_1.default>
                <link_1.default href="/staking" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Staking
                </link_1.default>
                <link_1.default href="/insights" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Insights
                </link_1.default>
                <link_1.default href="/pools" className="text-green-300 hover:text-white px-3 py-2 text-sm font-medium transition-colors">
                Pools
                </link_1.default>
                <link_1.default href="/admin" className="text-blue-300 hover:text-blue-200 px-3 py-2 text-sm font-medium transition-colors">
                Admin
                </link_1.default>
              {/* Testnet Dropdown */}
              <div className="relative" ref={dropdownRef}>
                <button onClick={() => setIsTestnetDropdownOpen(!isTestnetDropdownOpen)} className="text-orange-300 hover:text-orange-200 px-3 py-2 text-sm font-medium transition-colors flex items-center">
                  Testnet
                  <svg className={`ml-1 w-4 h-4 transition-transform ${isTestnetDropdownOpen ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>
                
                {isTestnetDropdownOpen && (<div className="absolute top-full left-0 mt-1 w-48 bg-gray-700 rounded-md shadow-lg z-50 border border-gray-600">
                    <div className="py-1">
                      <link_1.default href="/mint" className="block px-4 py-2 text-sm text-yellow-300 hover:text-yellow-200 hover:bg-gray-600 transition-colors" onClick={() => setIsTestnetDropdownOpen(false)}>
                        Mint Test Tokens
                      </link_1.default>
                      <link_1.default href="/token-info" className="block px-4 py-2 text-sm text-yellow-300 hover:text-yellow-200 hover:bg-gray-600 transition-colors" onClick={() => setIsTestnetDropdownOpen(false)}>
                        Token Info
                      </link_1.default>
                    </div>
                  </div>)}
              </div>
              
            </nav>
          </div>
          <div className="flex items-center gap-3 flex-shrink-0">
            <div className="flex flex-col items-end gap-1">
              <label className="text-[10px] uppercase tracking-wide text-gray-400" htmlFor="header-chain-selector">
                Chain
              </label>
              <select id="header-chain-selector" className="rounded-md border border-gray-600 bg-gray-700 px-2 py-1 text-xs text-gray-100" value={selectedChainOption} onChange={(event) => void handleChainSelection(event.target.value)} disabled={isSwitchingChain} title="Switch wallet network">
                <option value="ethereum">Ethereum</option>
                <option value="base">Base</option>
              </select>
              {chainSwitchError ? (<div className="max-w-[220px] text-right text-[10px] leading-tight text-red-300">
                  {chainSwitchError}
                </div>) : null}
              {!chainSwitchError && chainSwitchNotice ? (<div className={[
                    'max-w-[220px] text-right text-[10px] leading-tight',
                    chainSwitchNotice.tone === 'success' ? 'text-emerald-300' : 'text-sky-300',
                ].join(' ')}>
                  {chainSwitchNotice.message}
                </div>) : null}
            </div>
            <button onClick={toggleTheme} className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600" aria-label="Toggle style theme" title="Toggle style theme">
              Style: {styleTheme === 'pachira' ? 'Pachira' : 'Current'}
            </button>
            {isConnected ? (<button onClick={() => disconnect()} className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600" title={address}>
                {address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'Connected'}
              </button>) : (<div className="flex flex-col items-end gap-1">
                <button onClick={async () => {
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
                }
                catch (e) {
                    console.error('[wallet] connectAsync failed', e);
                  if (fallbackConnector && fallbackConnector.id !== preferredConnector.id) {
                    try {
                      await connectAsync({ connector: fallbackConnector });
                    }
                    catch (e2) {
                      console.error('[wallet] fallback connectAsync failed', e2);
                    }
                    }
                }
                setIsOpeningWallet(false);
              }} disabled={!preferredConnector || status === 'pending' || isOpeningWallet} className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600 disabled:opacity-50" title={error ? String(error?.message ?? error) : undefined}>
                  {status === 'pending' ? 'Connecting…' : isOpeningWallet ? 'Opening wallet…' : 'Connect Wallet'}
                </button>
                {connectAttempted && error ? (<div className="text-[10px] leading-tight text-red-300 max-w-[240px] text-right">
                    {error.message}
                  </div>) : noPopupHint ? (<div className="text-[10px] leading-tight text-yellow-300 max-w-[240px] text-right">
                    No popup? Check your wallet extension / pop-up blocker.
                  </div>) : null}
              </div>)}
          </div>
        </div>
      </div>
    </header>);
}
exports.Header = Header;
