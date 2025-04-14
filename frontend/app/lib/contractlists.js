"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildOptionsFromUI = exports.resolveLabel = exports.getFactoryFunctions = exports.getFactories = void 0;
const tokenlists_1 = require("./tokenlists");
const addressArtifacts_1 = require("./addressArtifacts");
function resolveTokenlistEntries(path, chainId) {
    const normalized = path.toLowerCase();
    if (normalized.includes('protocol-detf'))
        return (0, tokenlists_1.getProtocolDetfTokensForChain)(chainId);
    if (normalized.includes('seigniorage-detfs'))
        return (0, tokenlists_1.getSeigniorageDetfsForChain)(chainId);
    if (normalized.includes('aerodrome-strategy-vaults'))
        return (0, tokenlists_1.getStrategyVaultTokensForChain)(chainId);
    if (normalized.includes('strategy-vaults'))
        return (0, tokenlists_1.getStrategyVaultTokensForChain)(chainId);
    if (normalized.includes('balancerv3-pools'))
        return (0, tokenlists_1.getBalancerPoolTokensForChain)(chainId);
    if (normalized.includes('aerodrome-pools'))
        return (0, tokenlists_1.getAerodromePoolTokensForChain)(chainId);
    if (normalized.includes('univ2pool'))
        return (0, tokenlists_1.getUniV2PoolTokensForChain)(chainId);
    if (normalized.includes('erc4626'))
        return (0, tokenlists_1.getErc4626TokensForChain)(chainId);
    if (normalized.includes('tokens'))
        return (0, tokenlists_1.getBaseTokensForChain)(chainId);
    return [];
}
function getFactories(chainId) {
    const artifacts = (0, addressArtifacts_1.getAddressArtifacts)(chainId);
    return artifacts.factories.filter(f => f.chainId === chainId);
}
exports.getFactories = getFactories;
function getFactoryFunctions(factory) {
    return factory.functions.map(fn => {
        const entries = Object.entries(fn).filter(([k]) => !['simulate', 'resultStrategies', 'arguments'].includes(k));
        if (entries.length !== 1) {
            throw new Error(`Invalid function entry: Expected exactly one function name-label pair, got ${entries.length}`);
        }
        const [functionName, label] = entries[0];
        const args = fn.arguments ?? [];
        return { functionName, label: label, args };
    });
}
exports.getFactoryFunctions = getFactoryFunctions;
function resolveLabel(value, labelField, chainId = addressArtifacts_1.CHAIN_ID_SEPOLIA) {
    if (!labelField)
        return value;
    if (typeof labelField === 'string') {
        return value;
    }
    const { tokenlistPath, labelField: key } = labelField;
    const entries = resolveTokenlistEntries(tokenlistPath, chainId);
    const token = entries.find((t) => t.address?.toLowerCase() === value.toLowerCase());
    return token ? token[key] || value : value;
}
exports.resolveLabel = resolveLabel;
function buildOptionsFromUI(ui, chainId = addressArtifacts_1.CHAIN_ID_SEPOLIA) {
    if (!ui)
        return [];
    if (ui.source === 'static' && ui.options)
        return ui.options;
    if (ui.source === 'tokenlist') {
        const path = ui.sourcePath || '';
        let entries = resolveTokenlistEntries(path, chainId);
        if (ui.filters) {
            entries = entries.filter(e => Object.entries(ui.filters).every(([k, v]) => e[k] === v));
        }
        const valueKey = ui.valueField || 'address';
        const labelKey = typeof ui.labelField === 'string' ? ui.labelField : 'symbol';
        // If the token list entry provides a derived `display` label, prefer it.
        const effectiveLabelKey = (entries.length > 0 && entries[0].display) ? 'display' : labelKey;
        return entries.map(e => ({ value: e[valueKey], label: e[effectiveLabelKey] || e[valueKey] }));
    }
    if (ui.source === 'contractFunction') {
        console.warn('contractFunction source not implemented; returning empty options');
        return [];
    }
    if (ui.source === 'contractlist') {
        console.warn('contractlist source not implemented; returning empty options');
        return [];
    }
    return [];
}
exports.buildOptionsFromUI = buildOptionsFromUI;
