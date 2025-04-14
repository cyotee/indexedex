"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolvePoolTypeForChain = exports.resolvePoolType = exports.resolveTokenAddressFromOptionForChain = exports.resolveTokenAddressFromOption = exports.buildTokenOptionsForChain = exports.buildTokenOptions = exports.buildPoolOptionsForChain = exports.buildPoolOptions = exports.getTokenDecimalsByAddressForChain = exports.getTokenDecimalsByAddress = exports.isStrategyVaultTokenForChain = exports.isStrategyVaultToken = exports.findPoolByAddress = exports.findPoolBySymbol = exports.findTokenByAddress = exports.findTokenBySymbol = exports.getAllTokensForChain = exports.getAllTokens = exports.getMintableTestTokensForChain = exports.getBalancerPoolTokensForChain = exports.getAerodromePoolTokensForChain = exports.getUniV2PoolTokensForChain = exports.getStrategyVaultTokensForChain = exports.getProtocolDetfsForChain = exports.getProtocolDetfTokensForChain = exports.getSeigniorageDetfsForChain = exports.getErc4626TokensForChain = exports.getBaseTokensForChain = exports.getBalancerPoolTokens = exports.getAerodromePoolTokens = exports.getUniV2PoolTokens = exports.getStrategyVaultTokens = exports.getErc4626Tokens = exports.getBaseTokens = void 0;
const addressArtifacts_1 = require("./addressArtifacts");
function filterChain(list, chainId) {
    return list.filter((t) => t.chainId === chainId);
}
function isHexAddress(value) {
    if (typeof value !== 'string')
        return false;
    return /^0x[0-9a-fA-F]{40}$/.test(value);
}
function isZeroAddress(address) {
    return address.toLowerCase() === '0x0000000000000000000000000000000000000000';
}
function shortAddress(address) {
    const a = address;
    if (a.length !== 42)
        return a;
    return `${a.slice(0, 6)}...${a.slice(-4)}`;
}
function buildDisplay(entry) {
    const addr = shortAddress(entry.address);
    const name = (entry.name ?? '').trim();
    const symbol = (entry.symbol ?? '').trim();
    // Prefer symbol-first for regular tokens; name-first for pools/vault-like entries.
    const looksLikePoolOrVault = /pool|vault|erc4626|detf/i.test(name) || /pool|vault|erc4626|detf/i.test(symbol);
    const head = looksLikePoolOrVault
        ? [name || symbol, name && symbol && name !== symbol ? symbol : ''].filter(Boolean).join(' - ')
        : [symbol || name, symbol && name && symbol !== name ? name : ''].filter(Boolean).join(' - ');
    return head ? `${head} (${addr})` : `${addr}`;
}
function withDisplay(list) {
    return list.map((t) => ({ ...t, display: t.display || buildDisplay(t) }));
}
function humanizeKey(key) {
    // e.g. uniV2VaultTTATTB -> uni V2 Vault TTA TTB
    return key
        .replace(/([a-z])([A-Z0-9])/g, '$1 $2')
        .replace(/([0-9])([A-Za-z])/g, '$1 $2')
        .replace(/\s+/g, ' ')
        .trim();
}
function mergeUniqueByAddress(a, b) {
    const out = [...a];
    const seen = new Set(a.map((t) => t.address.toLowerCase()));
    for (const t of b) {
        const addr = t.address.toLowerCase();
        if (seen.has(addr))
            continue;
        seen.add(addr);
        out.push(t);
    }
    return out;
}
function mergeUniqueBySymbolPreferFirst(a, b) {
    const out = [...a];
    const seenSymbols = new Set(a.map((t) => t.symbol.trim().toLowerCase()));
    const seenAddresses = new Set(a.map((t) => t.address.toLowerCase()));
    for (const t of b) {
        const symbol = t.symbol.trim().toLowerCase();
        const address = t.address.toLowerCase();
        if (seenSymbols.has(symbol) || seenAddresses.has(address))
            continue;
        seenSymbols.add(symbol);
        seenAddresses.add(address);
        out.push(t);
    }
    return out;
}
function buildStrategyVaultEntriesFromPlatform(platform, chainId) {
    if (!platform || typeof platform !== 'object')
        return [];
    const ignoreKeys = new Set([
        // Core infra addresses that contain the substring "vault" but are not strategy vaults
        'balancerV3Vault',
        'vaultRegistry',
        'vaultFeeOracle',
    ]);
    const out = [];
    for (const [key, value] of Object.entries(platform)) {
        if (ignoreKeys.has(key))
            continue;
        // Only include actual vault instances, not packages/facets/registries/etc.
        if (!/vault/i.test(key))
            continue;
        if (/pkg|dfpkg|facet|factory|oracle|registry|rateprovider/i.test(key))
            continue;
        if (!isHexAddress(value))
            continue;
        if (isZeroAddress(value))
            continue;
        out.push({
            chainId,
            address: value,
            name: humanizeKey(key),
            symbol: key,
            decimals: 18,
        });
    }
    return withDisplay(out);
}
function buildProtocolDetfEntriesFromPlatform(platform, chainId) {
    if (!platform || typeof platform !== 'object')
        return [];
    const record = platform;
    const entries = [];
    const protocolDetf = record.protocolDetf;
    if (isHexAddress(protocolDetf) && !isZeroAddress(protocolDetf)) {
        entries.push({
            chainId,
            address: protocolDetf,
            name: 'Protocol DETF CHIR',
            symbol: 'CHIR',
            decimals: 18,
        });
    }
    const richToken = record.richToken;
    if (isHexAddress(richToken) && !isZeroAddress(richToken)) {
        entries.push({
            chainId,
            address: richToken,
            name: 'Rich Token',
            symbol: 'RICH',
            decimals: 18,
        });
    }
    const richirToken = record.richirToken;
    if (isHexAddress(richirToken) && !isZeroAddress(richirToken)) {
        entries.push({
            chainId,
            address: richirToken,
            name: 'RICHIR',
            symbol: 'RICHIR',
            decimals: 18,
        });
    }
    return withDisplay(entries);
}
function resolvePlatformWethAddress(platform) {
    if (!platform || typeof platform !== 'object')
        return null;
    const record = platform;
    const candidate = record.weth9 ?? record.weth ?? null;
    return isHexAddress(candidate) ? candidate : null;
}
const cacheByChainAndEnvironment = {};
const EMPTY_CACHE = {
    baseTokens: [],
    erc4626Tokens: [],
    seigniorageDetfs: [],
    protocolDetfTokens: [],
    strategyVaultTokens: [],
    uniV2PoolTokens: [],
    aerodromePoolTokens: [],
    balancerPoolTokens: [],
};
function getCacheKey(chainId, environment) {
    return `${environment}:${chainId}`;
}
function getArtifactsOrNull(chainId, environment) {
    const resolved = (0, addressArtifacts_1.resolveArtifactsChainId)(chainId, environment);
    if (resolved === null)
        return null;
    try {
        return (0, addressArtifacts_1.getAddressArtifacts)(chainId, environment);
    }
    catch {
        return null;
    }
}
function getCached(chainId = addressArtifacts_1.CHAIN_ID_SEPOLIA, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    const cacheKey = getCacheKey(chainId, environment);
    const existing = cacheByChainAndEnvironment[cacheKey];
    if (existing)
        return existing;
    const resolvedChainId = (0, addressArtifacts_1.resolveArtifactsChainId)(chainId, environment);
    const artifacts = getArtifactsOrNull(chainId, environment);
    if (!artifacts || resolvedChainId === null) {
        cacheByChainAndEnvironment[cacheKey] = EMPTY_CACHE;
        return EMPTY_CACHE;
    }
    const artifactsChainId = resolvedChainId;
    const baseTokens = withDisplay(filterChain(artifacts.tokenlists.tokens, artifactsChainId));
    const erc4626Tokens = withDisplay(filterChain(artifacts.tokenlists.erc4626, artifactsChainId));
    const seigniorageDetfs = withDisplay(filterChain((artifacts.tokenlists.seigniorageDetfs ?? []), artifactsChainId));
    const protocolDetfTokens = withDisplay(filterChain((artifacts.tokenlists.protocolDetf ?? []), artifactsChainId));
    const platformProtocolDetfTokens = buildProtocolDetfEntriesFromPlatform(artifacts.platform, artifactsChainId);
    const mergedProtocolDetfTokens = platformProtocolDetfTokens.length > 0
        ? mergeUniqueBySymbolPreferFirst(platformProtocolDetfTokens, protocolDetfTokens)
        : protocolDetfTokens;
    let strategyVaultTokens = withDisplay(filterChain(artifacts.tokenlists.strategyVaults, artifactsChainId));
    const uniV2PoolTokens = withDisplay(filterChain(artifacts.tokenlists.uniV2Pools, artifactsChainId));
    const aerodromePoolTokens = withDisplay(filterChain((artifacts.tokenlists.aerodromePools ?? []), artifactsChainId));
    const balancerPoolTokens = withDisplay(filterChain(artifacts.tokenlists.balancerPools, artifactsChainId));
    const aerodromeStrategyVaultTokens = filterChain((artifacts.tokenlists.aerodromeStrategyVaults ?? []), artifactsChainId);
    if (aerodromeStrategyVaultTokens.length > 0) {
        strategyVaultTokens = mergeUniqueByAddress(strategyVaultTokens, withDisplay(aerodromeStrategyVaultTokens));
    }
    // Anvil fork: the generated strategy-vaults tokenlist can be empty.
    // Fall back to any known vault addresses embedded in platform/base_deployments.json.
    // This keeps Swap/Batch-Swap pool dropdowns usable without additional script stages.
    if (strategyVaultTokens.length === 0) {
        const platformDerivedVaults = buildStrategyVaultEntriesFromPlatform(artifacts.platform, artifactsChainId);
        if (platformDerivedVaults.length > 0) {
            strategyVaultTokens = mergeUniqueByAddress(strategyVaultTokens, platformDerivedVaults);
        }
    }
    const cached = {
        baseTokens,
        erc4626Tokens,
        seigniorageDetfs,
        protocolDetfTokens: mergedProtocolDetfTokens,
        strategyVaultTokens,
        uniV2PoolTokens,
        aerodromePoolTokens,
        balancerPoolTokens,
    };
    cacheByChainAndEnvironment[cacheKey] = cached;
    return cached;
}
// Public getters
function getBaseTokens() {
    return getCached().baseTokens;
}
exports.getBaseTokens = getBaseTokens;
function getErc4626Tokens() {
    return getCached().erc4626Tokens;
}
exports.getErc4626Tokens = getErc4626Tokens;
function getStrategyVaultTokens() {
    return getCached().strategyVaultTokens;
}
exports.getStrategyVaultTokens = getStrategyVaultTokens;
function getUniV2PoolTokens() {
    return getCached().uniV2PoolTokens;
}
exports.getUniV2PoolTokens = getUniV2PoolTokens;
function getAerodromePoolTokens() {
    return getCached().aerodromePoolTokens;
}
exports.getAerodromePoolTokens = getAerodromePoolTokens;
function getBalancerPoolTokens() {
    return getCached().balancerPoolTokens;
}
exports.getBalancerPoolTokens = getBalancerPoolTokens;
function getBaseTokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).baseTokens;
}
exports.getBaseTokensForChain = getBaseTokensForChain;
function isTestTokenEntry(t) {
    // Keep this intentionally strict: Mint page should only expose dev/test ERC20s.
    // Our canonical test tokens are named "Test Token X" with symbols like TTA/TTB/TTC.
    return /test token/i.test(t.name) || /^TT[A-Z0-9]+$/.test(t.symbol);
}
function getErc4626TokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).erc4626Tokens;
}
exports.getErc4626TokensForChain = getErc4626TokensForChain;
function getSeigniorageDetfsForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).seigniorageDetfs;
}
exports.getSeigniorageDetfsForChain = getSeigniorageDetfsForChain;
function getProtocolDetfTokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).protocolDetfTokens;
}
exports.getProtocolDetfTokensForChain = getProtocolDetfTokensForChain;
function getProtocolDetfsForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).protocolDetfTokens.filter((t) => t.symbol === 'CHIR');
}
exports.getProtocolDetfsForChain = getProtocolDetfsForChain;
function getStrategyVaultTokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).strategyVaultTokens;
}
exports.getStrategyVaultTokensForChain = getStrategyVaultTokensForChain;
function getUniV2PoolTokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).uniV2PoolTokens;
}
exports.getUniV2PoolTokensForChain = getUniV2PoolTokensForChain;
function getAerodromePoolTokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).aerodromePoolTokens;
}
exports.getAerodromePoolTokensForChain = getAerodromePoolTokensForChain;
function getBalancerPoolTokensForChain(chainId, environment = (0, addressArtifacts_1.getDefaultDeploymentEnvironment)()) {
    return getCached(chainId, environment).balancerPoolTokens;
}
exports.getBalancerPoolTokensForChain = getBalancerPoolTokensForChain;
// Mint page helpers
function getMintableTestTokensForChain(chainId) {
    return getBaseTokensForChain(chainId).filter(isTestTokenEntry);
}
exports.getMintableTestTokensForChain = getMintableTestTokensForChain;
function getAllTokens() {
    const { baseTokens, erc4626Tokens, seigniorageDetfs, protocolDetfTokens, uniV2PoolTokens, aerodromePoolTokens, strategyVaultTokens, } = getCached();
    return [
        ...baseTokens,
        ...erc4626Tokens,
        ...seigniorageDetfs,
        ...protocolDetfTokens,
        ...uniV2PoolTokens,
        ...aerodromePoolTokens,
        ...strategyVaultTokens,
    ];
}
exports.getAllTokens = getAllTokens;
function getAllTokensForChain(chainId) {
    const { baseTokens, erc4626Tokens, seigniorageDetfs, protocolDetfTokens, uniV2PoolTokens, aerodromePoolTokens, strategyVaultTokens, } = getCached(chainId);
    return [
        ...baseTokens,
        ...erc4626Tokens,
        ...seigniorageDetfs,
        ...protocolDetfTokens,
        ...uniV2PoolTokens,
        ...aerodromePoolTokens,
        ...strategyVaultTokens,
    ];
}
exports.getAllTokensForChain = getAllTokensForChain;
// Lookups
function findTokenBySymbol(symbol) {
    const s = symbol.trim();
    return getAllTokens().find((t) => t.symbol === s);
}
exports.findTokenBySymbol = findTokenBySymbol;
function findTokenByAddress(address) {
    if (!address)
        return undefined;
    const a = address.toLowerCase();
    return getAllTokens().find((t) => t.address.toLowerCase() === a);
}
exports.findTokenByAddress = findTokenByAddress;
function findPoolBySymbol(symbol) {
    const s = symbol.trim();
    // Balancer pools and vaults (strategy + ERC4626) can both appear as selectable pools depending on context
    const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached();
    return (balancerPoolTokens.find((p) => p.symbol === s) ||
        strategyVaultTokens.find((p) => p.symbol === s) ||
        erc4626Tokens.find((p) => p.symbol === s) ||
        protocolDetfTokens.find((p) => p.symbol === s));
}
exports.findPoolBySymbol = findPoolBySymbol;
function findPoolByAddress(address) {
    if (!address)
        return undefined;
    const a = address.toLowerCase();
    const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached();
    return (balancerPoolTokens.find((p) => p.address.toLowerCase() === a) ||
        strategyVaultTokens.find((p) => p.address.toLowerCase() === a) ||
        erc4626Tokens.find((p) => p.address.toLowerCase() === a) ||
        protocolDetfTokens.find((p) => p.address.toLowerCase() === a));
}
exports.findPoolByAddress = findPoolByAddress;
function isStrategyVaultToken(address) {
    if (!address)
        return false;
    const a = address.toLowerCase();
    return getCached().strategyVaultTokens.some((t) => t.address.toLowerCase() === a);
}
exports.isStrategyVaultToken = isStrategyVaultToken;
function isStrategyVaultTokenForChain(chainId, address) {
    if (!address)
        return false;
    const a = address.toLowerCase();
    return getCached(chainId).strategyVaultTokens.some((t) => t.address.toLowerCase() === a);
}
exports.isStrategyVaultTokenForChain = isStrategyVaultTokenForChain;
function getTokenDecimalsByAddress(address) {
    if (!address)
        return 18;
    const platform = (0, addressArtifacts_1.getAddressArtifacts)(addressArtifacts_1.CHAIN_ID_SEPOLIA).platform;
    // WETH is always 18 decimals; use platform mapping for the current default chain.
    const weth = resolvePlatformWethAddress(platform);
    if (weth && address.toLowerCase() === weth.toLowerCase())
        return 18;
    const entry = findTokenByAddress(address);
    return entry?.decimals ?? 18;
}
exports.getTokenDecimalsByAddress = getTokenDecimalsByAddress;
function getTokenDecimalsByAddressForChain(chainId, address) {
    if (!address)
        return 18;
    const platform = (0, addressArtifacts_1.getAddressArtifacts)(chainId).platform;
    const weth = resolvePlatformWethAddress(platform);
    if (weth && address.toLowerCase() === weth.toLowerCase())
        return 18;
    const entry = getAllTokensForChain(chainId).find((t) => t.address.toLowerCase() === address.toLowerCase());
    return entry?.decimals ?? 18;
}
exports.getTokenDecimalsByAddressForChain = getTokenDecimalsByAddressForChain;
// UI option builders
function buildPoolOptions() {
    const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached();
    const balancerOptions = balancerPoolTokens.map((p) => ({
        value: p.address,
        label: p.display || p.name || p.symbol,
        type: 'balancer'
    }));
    const vaultOptions = strategyVaultTokens.map((p) => ({
        value: p.address,
        label: `${p.display || p.name || p.symbol} (Vault)`,
        type: 'vault'
    }));
    const erc4626VaultOptions = erc4626Tokens.map((p) => ({
        value: p.address,
        label: `${p.display || p.name || p.symbol} (ERC4626)`,
        type: 'vault',
    }));
    const protocolDetfOptions = protocolDetfTokens.map((t) => ({
        value: t.address,
        label: `${t.display || t.name || t.symbol} (Protocol DETF)`,
        type: 'vault',
    }));
    return [...balancerOptions, ...vaultOptions, ...erc4626VaultOptions, ...protocolDetfOptions];
}
exports.buildPoolOptions = buildPoolOptions;
function buildPoolOptionsForChain(chainId) {
    const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached(chainId);
    const platform = getArtifactsOrNull(chainId)?.platform;
    const weth = resolvePlatformWethAddress(platform);
    const specialOptions = [];
    // WETH sentinel pool: select this to do pure wrap/unwrap flows.
    if (weth && !isZeroAddress(weth)) {
        specialOptions.push({ value: weth, label: 'WETH (Wrap/Unwrap)', type: 'balancer' });
    }
    const balancerOptions = balancerPoolTokens.map((p) => ({
        value: p.address,
        label: p.display || p.name || p.symbol,
        type: 'balancer',
    }));
    const vaultOptions = strategyVaultTokens.map((p) => ({
        value: p.address,
        label: `${p.display || p.name || p.symbol} (Vault)`,
        type: 'vault',
    }));
    const erc4626VaultOptions = erc4626Tokens.map((p) => ({
        value: p.address,
        label: `${p.display || p.name || p.symbol} (ERC4626)`,
        type: 'vault',
    }));
    const protocolDetfOptions = protocolDetfTokens.map((t) => ({
        value: t.address,
        label: `${t.display || t.name || t.symbol} (Protocol DETF)`,
        type: 'vault',
    }));
    return [...specialOptions, ...balancerOptions, ...vaultOptions, ...erc4626VaultOptions, ...protocolDetfOptions];
}
exports.buildPoolOptionsForChain = buildPoolOptionsForChain;
function buildTokenOptions(includeVaultShares = true, includeLpTokens = true) {
    const opts = [];
    const { baseTokens, erc4626Tokens, seigniorageDetfs, protocolDetfTokens, uniV2PoolTokens, aerodromePoolTokens, strategyVaultTokens, } = getCached();
    const platform = (0, addressArtifacts_1.getAddressArtifacts)(addressArtifacts_1.CHAIN_ID_SEPOLIA).platform;
    // ETH and WETH
    opts.push({ value: 'ETH', label: 'ETH', chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'token' });
    if (resolvePlatformWethAddress(platform)) {
        opts.push({ value: 'WETH9', label: 'WETH9', chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'token' });
    }
    for (const t of baseTokens)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'token' });
    for (const t of erc4626Tokens)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'vault' });
    for (const t of seigniorageDetfs)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'vault' });
    for (const t of protocolDetfTokens)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'vault' });
    if (includeLpTokens)
        for (const t of uniV2PoolTokens)
            opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'lp' });
    if (includeLpTokens)
        for (const t of aerodromePoolTokens)
            opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'lp' });
    if (includeVaultShares)
        for (const t of strategyVaultTokens)
            opts.push({ value: t.address, label: t.display || t.symbol, chainId: addressArtifacts_1.CHAIN_ID_SEPOLIA, type: 'vault' });
    return opts;
}
exports.buildTokenOptions = buildTokenOptions;
function buildTokenOptionsForChain(chainId, includeVaultShares = true, includeLpTokens = true) {
    const opts = [];
    const { baseTokens, erc4626Tokens, seigniorageDetfs, protocolDetfTokens, uniV2PoolTokens, aerodromePoolTokens, strategyVaultTokens, } = getCached(chainId);
    const platform = getArtifactsOrNull(chainId)?.platform;
    opts.push({ value: 'ETH', label: 'ETH', chainId, type: 'token' });
    if (resolvePlatformWethAddress(platform)) {
        opts.push({ value: 'WETH9', label: 'WETH9', chainId, type: 'token' });
    }
    for (const t of baseTokens)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'token' });
    for (const t of erc4626Tokens)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' });
    for (const t of seigniorageDetfs)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' });
    for (const t of protocolDetfTokens)
        opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' });
    if (includeLpTokens)
        for (const t of uniV2PoolTokens)
            opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'lp' });
    if (includeLpTokens)
        for (const t of aerodromePoolTokens)
            opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'lp' });
    if (includeVaultShares)
        for (const t of strategyVaultTokens)
            opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' });
    return opts;
}
exports.buildTokenOptionsForChain = buildTokenOptionsForChain;
function resolveTokenAddressFromOption(value) {
    if (value === 'ETH')
        return null;
    if (value === 'WETH9') {
        const platform = (0, addressArtifacts_1.getAddressArtifacts)(addressArtifacts_1.CHAIN_ID_SEPOLIA).platform;
        return resolvePlatformWethAddress(platform);
    }
    return value;
}
exports.resolveTokenAddressFromOption = resolveTokenAddressFromOption;
function resolveTokenAddressFromOptionForChain(chainId, value) {
    if (value === 'ETH')
        return null;
    if (value === 'WETH9') {
        const platform = getArtifactsOrNull(chainId)?.platform;
        return resolvePlatformWethAddress(platform);
    }
    return value;
}
exports.resolveTokenAddressFromOptionForChain = resolveTokenAddressFromOptionForChain;
function resolvePoolType(address) {
    if (!address)
        return undefined;
    const pool = findPoolByAddress(address);
    if (!pool)
        return undefined;
    const { balancerPoolTokens } = getCached();
    return balancerPoolTokens.some((p) => p.address.toLowerCase() === pool.address.toLowerCase()) ? 'balancer' : 'vault';
}
exports.resolvePoolType = resolvePoolType;
function resolvePoolTypeForChain(chainId, address) {
    if (!address)
        return undefined;
    const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached(chainId);
    const a = address.toLowerCase();
    const platform = getArtifactsOrNull(chainId)?.platform;
    const weth = resolvePlatformWethAddress(platform);
    if (weth && a === weth.toLowerCase())
        return 'balancer';
    if (balancerPoolTokens.some((p) => p.address.toLowerCase() === a))
        return 'balancer';
    if (strategyVaultTokens.some((p) => p.address.toLowerCase() === a))
        return 'vault';
    if (erc4626Tokens.some((p) => p.address.toLowerCase() === a))
        return 'vault';
    if (protocolDetfTokens.some((p) => p.address.toLowerCase() === a))
        return 'vault';
    return undefined;
}
exports.resolvePoolTypeForChain = resolvePoolTypeForChain;
