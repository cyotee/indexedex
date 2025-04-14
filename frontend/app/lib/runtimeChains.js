"use strict";
'use client';
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveAppChain = void 0;
const chains_1 = require("wagmi/chains");
const addresses_1 = require("../addresses");
function resolveAppChain(chainId) {
    switch (chainId) {
        case chains_1.baseSepolia.id:
        case addresses_1.CHAIN_ID_BASE_SEPOLIA:
            return chains_1.baseSepolia;
        case chains_1.foundry.id:
            return chains_1.foundry;
        case chains_1.localhost.id:
            return chains_1.localhost;
        case chains_1.base.id:
            return chains_1.base;
        case chains_1.sepolia.id:
        case addresses_1.CHAIN_ID_SEPOLIA:
        default:
            return chains_1.sepolia;
    }
}
exports.resolveAppChain = resolveAppChain;
