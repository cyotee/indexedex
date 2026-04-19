"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getArtifactBundle = exports.DEPLOYMENT_ENVIRONMENTS = exports.ARTIFACT_REGISTRY = exports.CHAIN_ID_BASE_SEPOLIA = exports.CHAIN_ID_SEPOLIA = void 0;
const base_deployments_json_1 = __importDefault(require("./sepolia/base_deployments.json"));
const sepolia_factories_contractlist_json_1 = __importDefault(require("./sepolia/sepolia-factories.contractlist.json"));
const sepolia_tokens_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-tokens.tokenlist.json"));
const sepolia_erc4626_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-erc4626.tokenlist.json"));
const sepolia_strategy_vaults_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-strategy-vaults.tokenlist.json"));
const sepolia_uniV2pool_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-uniV2pool.tokenlist.json"));
const sepolia_aerodrome_pools_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-aerodrome-pools.tokenlist.json"));
const sepolia_aerodrome_strategy_vaults_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-aerodrome-strategy-vaults.tokenlist.json"));
const sepolia_balancerv3_pools_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-balancerv3-pools.tokenlist.json"));
const sepolia_seigniorage_detfs_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-seigniorage-detfs.tokenlist.json"));
const sepolia_protocol_detf_tokenlist_json_1 = __importDefault(require("./sepolia/sepolia-protocol-detf.tokenlist.json"));
const base_deployments_json_2 = __importDefault(require("./public_sepolia/ethereum/base_deployments.json"));
const public_sepolia_tokens_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-tokens.tokenlist.json"));
const public_sepolia_erc4626_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-erc4626.tokenlist.json"));
const public_sepolia_strategy_vaults_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-strategy-vaults.tokenlist.json"));
const public_sepolia_uniV2pool_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-uniV2pool.tokenlist.json"));
const public_sepolia_aerodrome_pools_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-aerodrome-pools.tokenlist.json"));
const public_sepolia_aerodrome_strategy_vaults_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-aerodrome-strategy-vaults.tokenlist.json"));
const public_sepolia_balancerv3_pools_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-balancerv3-pools.tokenlist.json"));
const public_sepolia_seigniorage_detfs_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-seigniorage-detfs.tokenlist.json"));
const public_sepolia_protocol_detf_tokenlist_json_1 = __importDefault(require("./public_sepolia/ethereum/public_sepolia-protocol-detf.tokenlist.json"));
const base_deployments_json_3 = __importDefault(require("./public_sepolia/base/base_deployments.json"));
const public_sepolia_tokens_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-tokens.tokenlist.json"));
const public_sepolia_erc4626_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-erc4626.tokenlist.json"));
const public_sepolia_strategy_vaults_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-strategy-vaults.tokenlist.json"));
const public_sepolia_uniV2pool_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-uniV2pool.tokenlist.json"));
const public_sepolia_aerodrome_pools_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-aerodrome-pools.tokenlist.json"));
const public_sepolia_aerodrome_strategy_vaults_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-aerodrome-strategy-vaults.tokenlist.json"));
const public_sepolia_balancerv3_pools_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-balancerv3-pools.tokenlist.json"));
const public_sepolia_seigniorage_detfs_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-seigniorage-detfs.tokenlist.json"));
const public_sepolia_protocol_detf_tokenlist_json_2 = __importDefault(require("./public_sepolia/base/public_sepolia-protocol-detf.tokenlist.json"));
const base_deployments_json_4 = __importDefault(require("./supersim_sepolia/ethereum/base_deployments.json"));
const sepolia_factories_contractlist_json_2 = __importDefault(require("./supersim_sepolia/ethereum/sepolia-factories.contractlist.json"));
const supersim_sepolia_tokens_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-tokens.tokenlist.json"));
const supersim_sepolia_erc4626_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-erc4626.tokenlist.json"));
const supersim_sepolia_strategy_vaults_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-strategy-vaults.tokenlist.json"));
const supersim_sepolia_uniV2pool_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-uniV2pool.tokenlist.json"));
const supersim_sepolia_aerodrome_pools_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-aerodrome-pools.tokenlist.json"));
const supersim_sepolia_aerodrome_strategy_vaults_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-aerodrome-strategy-vaults.tokenlist.json"));
const supersim_sepolia_balancerv3_pools_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-balancerv3-pools.tokenlist.json"));
const supersim_sepolia_seigniorage_detfs_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-seigniorage-detfs.tokenlist.json"));
const supersim_sepolia_protocol_detf_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/ethereum/supersim_sepolia-protocol-detf.tokenlist.json"));
const base_deployments_json_5 = __importDefault(require("./supersim_sepolia/base/base_deployments.json"));
const anvil_base_main_tokens_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-tokens.tokenlist.json"));
const anvil_base_main_erc4626_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-erc4626.tokenlist.json"));
const anvil_base_main_strategy_vaults_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-strategy-vaults.tokenlist.json"));
const anvil_base_main_uniV2pool_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-uniV2pool.tokenlist.json"));
const anvil_base_main_aerodrome_pools_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-aerodrome-pools.tokenlist.json"));
const anvil_base_main_aerodrome_strategy_vaults_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-aerodrome-strategy-vaults.tokenlist.json"));
const anvil_base_main_balancerv3_pools_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-balancerv3-pools.tokenlist.json"));
const anvil_base_main_seigniorage_detfs_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-seigniorage-detfs.tokenlist.json"));
const anvil_base_main_protocol_detf_tokenlist_json_1 = __importDefault(require("./supersim_sepolia/base/anvil_base_main-protocol-detf.tokenlist.json"));
const base_deployments_json_6 = __importDefault(require("./public_sepolia_supersim/ethereum/base_deployments.json"));
const public_sepolia_supersim_factories_contractlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-factories.contractlist.json"));
const public_sepolia_supersim_tokens_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-tokens.tokenlist.json"));
const public_sepolia_supersim_erc4626_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-erc4626.tokenlist.json"));
const public_sepolia_supersim_strategy_vaults_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-strategy-vaults.tokenlist.json"));
const public_sepolia_supersim_uniV2pool_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-uniV2pool.tokenlist.json"));
const public_sepolia_supersim_aerodrome_pools_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-aerodrome-pools.tokenlist.json"));
const public_sepolia_supersim_aerodrome_strategy_vaults_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-aerodrome-strategy-vaults.tokenlist.json"));
const public_sepolia_supersim_balancerv3_pools_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-balancerv3-pools.tokenlist.json"));
const public_sepolia_supersim_seigniorage_detfs_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-seigniorage-detfs.tokenlist.json"));
const public_sepolia_supersim_protocol_detf_tokenlist_json_1 = __importDefault(require("./public_sepolia_supersim/ethereum/public_sepolia_supersim-protocol-detf.tokenlist.json"));
const base_deployments_json_7 = __importDefault(require("./public_sepolia_supersim/base/base_deployments.json"));
const public_sepolia_supersim_tokens_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-tokens.tokenlist.json"));
const public_sepolia_supersim_erc4626_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-erc4626.tokenlist.json"));
const public_sepolia_supersim_strategy_vaults_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-strategy-vaults.tokenlist.json"));
const public_sepolia_supersim_uniV2pool_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-uniV2pool.tokenlist.json"));
const public_sepolia_supersim_aerodrome_pools_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-aerodrome-pools.tokenlist.json"));
const public_sepolia_supersim_aerodrome_strategy_vaults_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-aerodrome-strategy-vaults.tokenlist.json"));
const public_sepolia_supersim_balancerv3_pools_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-balancerv3-pools.tokenlist.json"));
const public_sepolia_supersim_seigniorage_detfs_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-seigniorage-detfs.tokenlist.json"));
const public_sepolia_supersim_protocol_detf_tokenlist_json_2 = __importDefault(require("./public_sepolia_supersim/base/public_sepolia_supersim-protocol-detf.tokenlist.json"));
exports.CHAIN_ID_SEPOLIA = 11155111;
exports.CHAIN_ID_BASE_SEPOLIA = 84532;
const CANONICAL_PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
const normalizePlatform = (platform, chainId) => {
    const normalized = {
        ...(platform ?? {}),
        chainId,
    };
    const weth9 = normalized.weth9 ?? normalized.weth ?? null;
    if (weth9) {
        normalized.weth9 = weth9;
        normalized.weth = weth9;
    }
    if (!normalized.permit2) {
        normalized.permit2 = CANONICAL_PERMIT2_ADDRESS;
    }
    return normalized;
};
const normalizeList = (list, chainId) => Array.isArray(list)
    ? list.map((entry) => ({
        ...(entry ?? {}),
        chainId,
    }))
    : [];
const buildBundle = (environment, chainId, chainRole, source) => ({
    environment,
    chainId,
    chainRole,
    platform: normalizePlatform(source.platform, chainId),
    factories: Array.isArray(source.factories) ? source.factories : [],
    tokenlists: {
        tokens: normalizeList(source.tokens, chainId),
        erc4626: normalizeList(source.erc4626, chainId),
        seigniorageDetfs: normalizeList(source.seigniorageDetfs, chainId),
        protocolDetf: normalizeList(source.protocolDetf, chainId),
        strategyVaults: normalizeList(source.strategyVaults, chainId),
        uniV2Pools: normalizeList(source.uniV2Pools, chainId),
        aerodromePools: normalizeList(source.aerodromePools, chainId),
        aerodromeStrategyVaults: normalizeList(source.aerodromeStrategyVaults, chainId),
        balancerPools: normalizeList(source.balancerPools, chainId),
    },
});
exports.ARTIFACT_REGISTRY = {
    sepolia: {
        [exports.CHAIN_ID_SEPOLIA]: buildBundle('sepolia', exports.CHAIN_ID_SEPOLIA, 'ethereum', {
            platform: base_deployments_json_1.default,
            factories: sepolia_factories_contractlist_json_1.default,
            tokens: sepolia_tokens_tokenlist_json_1.default,
            erc4626: sepolia_erc4626_tokenlist_json_1.default,
            seigniorageDetfs: sepolia_seigniorage_detfs_tokenlist_json_1.default,
            protocolDetf: sepolia_protocol_detf_tokenlist_json_1.default,
            strategyVaults: sepolia_strategy_vaults_tokenlist_json_1.default,
            uniV2Pools: sepolia_uniV2pool_tokenlist_json_1.default,
            aerodromePools: sepolia_aerodrome_pools_tokenlist_json_1.default,
            aerodromeStrategyVaults: sepolia_aerodrome_strategy_vaults_tokenlist_json_1.default,
            balancerPools: sepolia_balancerv3_pools_tokenlist_json_1.default,
        }),
    },
    public_sepolia: {
        [exports.CHAIN_ID_SEPOLIA]: buildBundle('public_sepolia', exports.CHAIN_ID_SEPOLIA, 'ethereum', {
            platform: base_deployments_json_2.default,
            tokens: public_sepolia_tokens_tokenlist_json_1.default,
            erc4626: public_sepolia_erc4626_tokenlist_json_1.default,
            seigniorageDetfs: public_sepolia_seigniorage_detfs_tokenlist_json_1.default,
            protocolDetf: public_sepolia_protocol_detf_tokenlist_json_1.default,
            strategyVaults: public_sepolia_strategy_vaults_tokenlist_json_1.default,
            uniV2Pools: public_sepolia_uniV2pool_tokenlist_json_1.default,
            aerodromePools: public_sepolia_aerodrome_pools_tokenlist_json_1.default,
            aerodromeStrategyVaults: public_sepolia_aerodrome_strategy_vaults_tokenlist_json_1.default,
            balancerPools: public_sepolia_balancerv3_pools_tokenlist_json_1.default,
        }),
        [exports.CHAIN_ID_BASE_SEPOLIA]: buildBundle('public_sepolia', exports.CHAIN_ID_BASE_SEPOLIA, 'base', {
            platform: base_deployments_json_3.default,
            tokens: public_sepolia_tokens_tokenlist_json_2.default,
            erc4626: public_sepolia_erc4626_tokenlist_json_2.default,
            seigniorageDetfs: public_sepolia_seigniorage_detfs_tokenlist_json_2.default,
            protocolDetf: public_sepolia_protocol_detf_tokenlist_json_2.default,
            strategyVaults: public_sepolia_strategy_vaults_tokenlist_json_2.default,
            uniV2Pools: public_sepolia_uniV2pool_tokenlist_json_2.default,
            aerodromePools: public_sepolia_aerodrome_pools_tokenlist_json_2.default,
            aerodromeStrategyVaults: public_sepolia_aerodrome_strategy_vaults_tokenlist_json_2.default,
            balancerPools: public_sepolia_balancerv3_pools_tokenlist_json_2.default,
        }),
    },
    supersim_sepolia: {
        [exports.CHAIN_ID_SEPOLIA]: buildBundle('supersim_sepolia', exports.CHAIN_ID_SEPOLIA, 'ethereum', {
            platform: base_deployments_json_4.default,
            factories: sepolia_factories_contractlist_json_2.default,
            tokens: supersim_sepolia_tokens_tokenlist_json_1.default,
            erc4626: supersim_sepolia_erc4626_tokenlist_json_1.default,
            seigniorageDetfs: supersim_sepolia_seigniorage_detfs_tokenlist_json_1.default,
            protocolDetf: supersim_sepolia_protocol_detf_tokenlist_json_1.default,
            strategyVaults: supersim_sepolia_strategy_vaults_tokenlist_json_1.default,
            uniV2Pools: supersim_sepolia_uniV2pool_tokenlist_json_1.default,
            aerodromePools: supersim_sepolia_aerodrome_pools_tokenlist_json_1.default,
            aerodromeStrategyVaults: supersim_sepolia_aerodrome_strategy_vaults_tokenlist_json_1.default,
            balancerPools: supersim_sepolia_balancerv3_pools_tokenlist_json_1.default,
        }),
        [exports.CHAIN_ID_BASE_SEPOLIA]: buildBundle('supersim_sepolia', exports.CHAIN_ID_BASE_SEPOLIA, 'base', {
            platform: base_deployments_json_5.default,
            tokens: anvil_base_main_tokens_tokenlist_json_1.default,
            erc4626: anvil_base_main_erc4626_tokenlist_json_1.default,
            seigniorageDetfs: anvil_base_main_seigniorage_detfs_tokenlist_json_1.default,
            protocolDetf: anvil_base_main_protocol_detf_tokenlist_json_1.default,
            strategyVaults: anvil_base_main_strategy_vaults_tokenlist_json_1.default,
            uniV2Pools: anvil_base_main_uniV2pool_tokenlist_json_1.default,
            aerodromePools: anvil_base_main_aerodrome_pools_tokenlist_json_1.default,
            aerodromeStrategyVaults: anvil_base_main_aerodrome_strategy_vaults_tokenlist_json_1.default,
            balancerPools: anvil_base_main_balancerv3_pools_tokenlist_json_1.default,
        }),
    },
};
exports.DEPLOYMENT_ENVIRONMENTS = ['sepolia', 'public_sepolia', 'supersim_sepolia'];
function getArtifactBundle(environment, chainId) {
    return exports.ARTIFACT_REGISTRY[environment][chainId] ?? null;
}
exports.getArtifactBundle = getArtifactBundle;
