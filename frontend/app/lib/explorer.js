"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.explorerAddressUrl = void 0;
function explorerAddressUrl(chainId, address) {
    if (!address)
        return null;
    // Sepolia
    if (chainId === 11155111) {
        return `https://sepolia.etherscan.io/address/${address}`;
    }
    // Anvil fork (no public explorer)
    if (chainId === 31337) {
        return null;
    }
    return null;
}
exports.explorerAddressUrl = explorerAddressUrl;
