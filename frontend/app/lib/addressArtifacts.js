"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAddressArtifacts = exports.isSupportedChainId = exports.resolveArtifactsChainId = exports.getDefaultDeploymentEnvironment = exports.setDefaultDeploymentEnvironment = exports.CHAIN_ID_BASE = exports.CHAIN_ID_LOCALHOST = exports.CHAIN_ID_ANVIL = exports.getArtifactBundle = exports.CHAIN_ID_SEPOLIA = exports.CHAIN_ID_BASE_SEPOLIA = void 0;
const addresses_1 = require("../addresses");
Object.defineProperty(exports, "CHAIN_ID_BASE_SEPOLIA", { enumerable: true, get: function () { return addresses_1.CHAIN_ID_BASE_SEPOLIA; } });
Object.defineProperty(exports, "CHAIN_ID_SEPOLIA", { enumerable: true, get: function () { return addresses_1.CHAIN_ID_SEPOLIA; } });
Object.defineProperty(exports, "getArtifactBundle", { enumerable: true, get: function () { return addresses_1.getArtifactBundle; } });
exports.CHAIN_ID_ANVIL = 31337;
exports.CHAIN_ID_LOCALHOST = 1337;
exports.CHAIN_ID_BASE = 8453;
function isLocalSepoliaEnvironment(environment) {
    return environment === 'supersim_sepolia';
}
let defaultDeploymentEnvironment = process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT ?? 'supersim_sepolia';
function setDefaultDeploymentEnvironment(environment) {
    defaultDeploymentEnvironment = environment;
}
exports.setDefaultDeploymentEnvironment = setDefaultDeploymentEnvironment;
function getDefaultDeploymentEnvironment() {
    return defaultDeploymentEnvironment;
}
exports.getDefaultDeploymentEnvironment = getDefaultDeploymentEnvironment;
function resolveArtifactsChainId(chainId, environment = defaultDeploymentEnvironment) {
    if (chainId === addresses_1.CHAIN_ID_SEPOLIA)
        return addresses_1.CHAIN_ID_SEPOLIA;
    if (chainId === addresses_1.CHAIN_ID_BASE_SEPOLIA)
        return addresses_1.CHAIN_ID_BASE_SEPOLIA;
    if (chainId === exports.CHAIN_ID_ANVIL || chainId === exports.CHAIN_ID_LOCALHOST) {
        return addresses_1.CHAIN_ID_SEPOLIA;
    }
    if (chainId === exports.CHAIN_ID_BASE && isLocalSepoliaEnvironment(environment)) {
        return addresses_1.CHAIN_ID_BASE_SEPOLIA;
    }
    return null;
}
exports.resolveArtifactsChainId = resolveArtifactsChainId;
function isSupportedChainId(chainId, environment = defaultDeploymentEnvironment) {
    const resolved = resolveArtifactsChainId(chainId, environment);
    if (resolved === null)
        return false;
    return (0, addresses_1.getArtifactBundle)(environment, resolved) !== null;
}
exports.isSupportedChainId = isSupportedChainId;
function getAddressArtifacts(chainId, environment = defaultDeploymentEnvironment) {
    const resolved = resolveArtifactsChainId(chainId, environment);
    if (resolved === null) {
        throw new Error(`Unsupported chainId ${chainId}. Supported chains resolve to ${addresses_1.CHAIN_ID_SEPOLIA} (Ethereum Sepolia) or ${addresses_1.CHAIN_ID_BASE_SEPOLIA} (Base Sepolia) for environment ${environment}.`);
    }
    const bundle = (0, addresses_1.getArtifactBundle)(environment, resolved);
    if (!bundle) {
        throw new Error(`No deployment bundle is registered for environment ${environment} on chain ${resolved}.`);
    }
    return bundle;
}
exports.getAddressArtifacts = getAddressArtifacts;
