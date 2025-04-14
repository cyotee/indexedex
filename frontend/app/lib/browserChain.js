'use client';

const react_1 = require("react");

function parseChainId(value) {
    if (typeof value === 'number' && Number.isFinite(value))
        return value;
    if (typeof value !== 'string')
        return undefined;
    if (value.startsWith('0x') || value.startsWith('0X')) {
        const parsed = Number.parseInt(value, 16);
        return Number.isFinite(parsed) ? parsed : undefined;
    }
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : undefined;
}

function useBrowserChainId(enabled) {
    const [chainId, setChainId] = (0, react_1.useState)(undefined);
    (0, react_1.useEffect)(() => {
        if (!enabled || typeof window === 'undefined') {
            setChainId(undefined);
            return;
        }
        const provider = window.ethereum;
        if (!provider) {
            setChainId(undefined);
            return;
        }
        let cancelled = false;
        const sync = async () => {
            try {
                const requested = await provider.request?.({ method: 'eth_chainId' });
                const nextChainId = parseChainId(requested ?? provider.chainId);
                if (!cancelled)
                    setChainId(nextChainId);
            }
            catch {
                const nextChainId = parseChainId(provider.chainId);
                if (!cancelled)
                    setChainId(nextChainId);
            }
        };
        const handleChainChanged = (value) => {
            if (cancelled)
                return;
            setChainId(parseChainId(value));
        };
        void sync();
        provider.on?.('chainChanged', handleChainChanged);
        return () => {
            cancelled = true;
            provider.removeListener?.('chainChanged', handleChainChanged);
        };
    }, [enabled]);
    return chainId;
}

function useConnectedWalletChainId(enabled, connector) {
    const [chainId, setChainId] = (0, react_1.useState)(undefined);
    (0, react_1.useEffect)(() => {
        if (!enabled || !connector) {
            setChainId(undefined);
            return;
        }
        let cancelled = false;
        let provider;
        const sync = async () => {
            try {
                provider = await connector.getProvider();
                const requested = await provider?.request?.({ method: 'eth_chainId' });
                const nextChainId = parseChainId(requested ?? provider?.chainId);
                if (!cancelled && nextChainId !== undefined) {
                    setChainId(nextChainId);
                    return;
                }
            }
            catch {
            }
            try {
                const nextChainId = await connector.getChainId();
                if (!cancelled)
                    setChainId(nextChainId);
            }
            catch {
                if (!cancelled)
                    setChainId(undefined);
            }
        };
        const handleChainChanged = (value) => {
            if (cancelled)
                return;
            setChainId(parseChainId(value));
        };
        void sync();
        void connector.getProvider().then((nextProvider) => {
            if (cancelled)
                return;
            provider = nextProvider;
            provider?.on?.('chainChanged', handleChainChanged);
        });
        return () => {
            cancelled = true;
            provider?.removeListener?.('chainChanged', handleChainChanged);
        };
    }, [connector, enabled]);
    return chainId;
}

async function readProviderChainId(provider) {
    if (!provider)
        return undefined;
    try {
        const requested = await provider.request?.({ method: 'eth_chainId' });
        return parseChainId(requested ?? provider.chainId);
    }
    catch {
        return parseChainId(provider.chainId);
    }
}

function matchesConnector(provider, connectorId) {
    if (!connectorId)
        return false;
    if (connectorId === 'metaMask')
        return provider.isMetaMask === true;
    if (connectorId === 'coinbaseWallet')
        return provider.isCoinbaseWallet === true;
    return false;
}

async function matchesAccount(provider, walletAddress) {
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

async function resolvePreferredChainId(provider, preferredChainIds, connectorId, walletAddress) {
    const topLevelChainId = await readProviderChainId(provider);
    const nestedProviders = Array.isArray(provider.providers) ? provider.providers : [];
    const accountMatchedProviders = (await Promise.all(nestedProviders.map(async (nestedProvider) => ({
        provider: nestedProvider,
        matchesAccount: await matchesAccount(nestedProvider, walletAddress),
    }))))
        .filter((entry) => entry.matchesAccount)
        .map((entry) => entry.provider);
    const preferredProviders = nestedProviders.filter((nestedProvider) => matchesConnector(nestedProvider, connectorId));
    const candidateProviders = accountMatchedProviders.length > 0
        ? accountMatchedProviders
        : preferredProviders.length > 0
            ? preferredProviders
            : nestedProviders;
    const candidateChainIds = (await Promise.all(candidateProviders.map(readProviderChainId)))
        .filter((value) => value !== undefined);
    if (topLevelChainId !== undefined && preferredChainIds.includes(topLevelChainId)) {
        return topLevelChainId;
    }
    if (candidateChainIds.length === 1)
        return candidateChainIds[0];
    for (const preferredChainId of preferredChainIds) {
        if (candidateChainIds.includes(preferredChainId)) {
            return preferredChainId;
        }
    }
    return topLevelChainId ?? candidateChainIds[0];
}

function usePreferredBrowserChainId(enabled, preferredChainIds, connectorId, walletAddress) {
    const [chainId, setChainId] = (0, react_1.useState)(undefined);
    (0, react_1.useEffect)(() => {
        if (!enabled || typeof window === 'undefined') {
            setChainId(undefined);
            return;
        }
        const provider = window.ethereum;
        if (!provider) {
            setChainId(undefined);
            return;
        }
        let cancelled = false;
        const sync = async () => {
            const nextChainId = await resolvePreferredChainId(provider, preferredChainIds, connectorId, walletAddress);
            if (!cancelled)
                setChainId(nextChainId);
        };
        const handleChainChanged = (value) => {
            if (cancelled)
                return;
            const nextChainId = parseChainId(value);
            if (nextChainId !== undefined && preferredChainIds.includes(nextChainId)) {
                setChainId(nextChainId);
                return;
            }
            void sync();
        };
        void sync();
        provider.on?.('chainChanged', handleChainChanged);
        for (const nestedProvider of Array.isArray(provider.providers) ? provider.providers : []) {
            nestedProvider.on?.('chainChanged', handleChainChanged);
        }
        return () => {
            cancelled = true;
            provider.removeListener?.('chainChanged', handleChainChanged);
            for (const nestedProvider of Array.isArray(provider.providers) ? provider.providers : []) {
                nestedProvider.removeListener?.('chainChanged', handleChainChanged);
            }
        };
    }, [connectorId, enabled, preferredChainIds, walletAddress]);
    return chainId;
}

exports.useBrowserChainId = useBrowserChainId;
exports.useConnectedWalletChainId = useConnectedWalletChainId;
exports.usePreferredBrowserChainId = usePreferredBrowserChainId;