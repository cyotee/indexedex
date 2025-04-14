import {
    getBaseTokensForChain,
    getErc4626TokensForChain,
    getSeigniorageDetfsForChain,
    getProtocolDetfTokensForChain,
    getUniV2PoolTokensForChain,
    getAerodromePoolTokensForChain,
    getStrategyVaultTokensForChain,
    getBalancerPoolTokensForChain
} from './tokenlists';

import { CHAIN_ID_SEPOLIA, getAddressArtifacts } from './addressArtifacts';
export type Address = `0x${string}`;

export type ArgSource = string | { literal: any };

export type ContractListArgUI = {
    widget?: 'address' | 'text' | 'select' | 'multiselect' | 'checkbox' | 'radio' | 'slider';
    allowManual?: boolean;
    source?: 'tokenlist' | 'contractlist' | 'static' | 'contractFunction';
    sourcePath?: string;
    valueField?: string;
    labelField?: string | { tokenlistPath: string; labelField: string };
    filters?: Record<string, unknown>;
    options?: Array<{ value: any; label: string }>;
    dependsOn?: string[];
    hook?: { name: string; argsFrom?: ArgSource[] };
    abiCall?: {
        abiPath?: string;
        inlineAbi?: any[];
        function: string;
        argsFrom?: ArgSource[];
        contractFrom?: ArgSource;
    };
    array?: { addLabel?: string; removeLabel?: string; itemLabelField?: string };
    validation?: { regex?: string; errorMessage?: string };
};

export type ContractListArgComponent = {
    name: string;
    type: 'address' | 'address[]' | 'uint8' | 'uint256' | 'uint256[]' | 'bool' | 'string';
    description: string;
    optional?: boolean;
    default?: string | number | boolean | any[] | null;
    ui?: ContractListArgUI;
};

export type ContractListArgument = ContractListArgComponent & {
    minItems?: number;
    maxItems?: number;
    components?: ContractListArgComponent[];
};

export type ResultStrategy =
    | { type: 'simulate'; label?: string; format?: 'address' | 'link' | 'hex' | 'number'; abiPath?: string; inlineAbi?: any[]; }
    | {
        type: 'event';
        label?: string;
        format?: 'address' | 'link' | 'hex' | 'number';
        hook?: { name: string; argsFrom?: ArgSource[] };
        name?: string;
        arg?: string | number;
        contractAddress?: string;
        abiPath?: string;
        inlineAbi?: any[];
    }
    | {
        type: 'read';
        label?: string;
        format?: 'address' | 'link' | 'hex' | 'number';
        hook?: { name: string; argsFrom?: ArgSource[] };
        function?: string;
        argsFrom?: ArgSource[];
        valueField?: string;
        abiPath?: string;
        inlineAbi?: any[];
    };

export type ContractListFunctionEntry = {
    simulate?: boolean;
    resultStrategies?: ResultStrategy[];
    arguments?: ContractListArgument[];
} & Record<Exclude<string, "simulate" | "resultStrategies" | "arguments">, string>;

export type ContractListFactory = {
    chainId: number;
    hookName: string;
    name: string;
    functions: ContractListFunctionEntry[];
};

function resolveTokenlistEntries(path: string, chainId: number): any[] {
    const normalized = path.toLowerCase();

    if (normalized.includes('protocol-detf')) return getProtocolDetfTokensForChain(chainId);
    if (normalized.includes('seigniorage-detfs')) return getSeigniorageDetfsForChain(chainId);
    if (normalized.includes('aerodrome-strategy-vaults')) return getStrategyVaultTokensForChain(chainId);
    if (normalized.includes('strategy-vaults')) return getStrategyVaultTokensForChain(chainId);
    if (normalized.includes('balancerv3-pools')) return getBalancerPoolTokensForChain(chainId);
    if (normalized.includes('aerodrome-pools')) return getAerodromePoolTokensForChain(chainId);
    if (normalized.includes('univ2pool')) return getUniV2PoolTokensForChain(chainId);
    if (normalized.includes('erc4626')) return getErc4626TokensForChain(chainId);
    if (normalized.includes('tokens')) return getBaseTokensForChain(chainId);

    return [];
}

export function getFactories(chainId: number): ContractListFactory[] {
    const artifacts = getAddressArtifacts(chainId);
    return (artifacts.factories as unknown as ContractListFactory[]).filter(f => f.chainId === chainId);
}

export function getFactoryFunctions(factory: ContractListFactory): { functionName: string; label: string; args: ContractListArgument[] }[] {
    return factory.functions.map(fn => {
        const entries = Object.entries(fn).filter(([k]) => !['simulate', 'resultStrategies', 'arguments'].includes(k));
        if (entries.length !== 1) {
            throw new Error(`Invalid function entry: Expected exactly one function name-label pair, got ${entries.length}`);
        }
        const [functionName, label] = entries[0];
        const args = fn.arguments ?? [];
        return { functionName, label: label as string, args };
    });
}

export function resolveLabel(
    value: string,
    labelField: ContractListArgUI['labelField'] | undefined,
    chainId: number = CHAIN_ID_SEPOLIA
): string {
    if (!labelField) return value;
    if (typeof labelField === 'string') {
        return value;
    }
    const { tokenlistPath, labelField: key } = labelField;
    const entries = resolveTokenlistEntries(tokenlistPath, chainId);
    const token = entries.find((t: any) => t.address?.toLowerCase() === value.toLowerCase());
    return token ? token[key] || value : value;
}

export function buildOptionsFromUI(ui?: ContractListArgUI, chainId: number = CHAIN_ID_SEPOLIA): Array<{ value: any; label: string }> {
    if (!ui) return [];
    if (ui.source === 'static' && ui.options) return ui.options;
    if (ui.source === 'tokenlist') {
        const path = ui.sourcePath || '';
        let entries: Array<{ address: string; name: string; symbol: string; display?: string }> = resolveTokenlistEntries(path, chainId);
        if (ui.filters) {
            entries = entries.filter(e => Object.entries(ui.filters!).every(([k, v]) => (e as any)[k] === v));
        }
        const valueKey = ui.valueField || 'address';
        const labelKey = typeof ui.labelField === 'string' ? ui.labelField : 'symbol';
        // If the token list entry provides a derived `display` label, prefer it.
        const effectiveLabelKey = (entries.length > 0 && (entries[0] as any).display) ? 'display' : labelKey;
        return entries.map(e => ({ value: (e as any)[valueKey], label: (e as any)[effectiveLabelKey] || (e as any)[valueKey] }));
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
