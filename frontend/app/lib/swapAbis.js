"use strict";
'use client';
Object.defineProperty(exports, "__esModule", { value: true });
exports.swapExactOutAbi = exports.swapExactInAbi = exports.swapWithPermitOutAbi = exports.swapWithPermitAbi = exports.routerDebugAbi = void 0;
exports.routerDebugAbi = [
    {
        type: 'event',
        name: 'SwapHookParamsDebug',
        inputs: [
            { indexed: true, name: 'sender', type: 'address' },
            { indexed: false, name: 'kind', type: 'uint8' },
            { indexed: true, name: 'pool', type: 'address' },
            { indexed: false, name: 'tokenIn', type: 'address' },
            { indexed: false, name: 'tokenOut', type: 'address' },
            { indexed: false, name: 'tokenInVault', type: 'address' },
            { indexed: false, name: 'tokenOutVault', type: 'address' },
            { indexed: false, name: 'amountGiven', type: 'uint256' },
            { indexed: false, name: 'limit', type: 'uint256' },
            { indexed: false, name: 'wethIsEth', type: 'bool' },
        ],
    },
    {
        type: 'event',
        name: 'WethSentinelDebug',
        inputs: [
            { indexed: true, name: 'sender', type: 'address' },
            { indexed: false, name: 'kind', type: 'uint8' },
            { indexed: false, name: 'amountGiven', type: 'uint256' },
            { indexed: false, name: 'limit', type: 'uint256' },
            { indexed: false, name: 'wrap', type: 'bool' },
            { indexed: false, name: 'unwrap', type: 'bool' },
        ],
    },
];
const swapParamsAbi = [
    { name: 'sender', type: 'address' },
    { name: 'kind', type: 'uint8' },
    { name: 'pool', type: 'address' },
    { name: 'tokenIn', type: 'address' },
    { name: 'tokenInVault', type: 'address' },
    { name: 'tokenOut', type: 'address' },
    { name: 'tokenOutVault', type: 'address' },
    { name: 'amountGiven', type: 'uint256' },
    { name: 'limit', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
    { name: 'wethIsEth', type: 'bool' },
    { name: 'userData', type: 'bytes' }
];
const permitAbi = [
    { name: 'permitted', type: 'tuple', components: [
            { name: 'token', type: 'address' },
            { name: 'amount', type: 'uint256' }
        ] },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
];
exports.swapWithPermitAbi = [
    {
        type: 'function',
        name: 'swapSingleTokenExactInWithPermit',
        inputs: [
            { name: 'swapParams', type: 'tuple', components: swapParamsAbi },
            { name: 'permit', type: 'tuple', components: permitAbi },
            { name: 'signature', type: 'bytes' }
        ],
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'payable'
    }
];
exports.swapWithPermitOutAbi = [
    {
        type: 'function',
        name: 'swapSingleTokenExactOutWithPermit',
        inputs: [
            { name: 'swapParams', type: 'tuple', components: swapParamsAbi },
            { name: 'permit', type: 'tuple', components: permitAbi },
            { name: 'signature', type: 'bytes' }
        ],
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'payable'
    }
];
exports.swapExactInAbi = [
    {
        inputs: [
            { name: 'pool', type: 'address' },
            { name: 'tokenIn', type: 'address' },
            { name: 'tokenInVault', type: 'address' },
            { name: 'tokenOut', type: 'address' },
            { name: 'tokenOutVault', type: 'address' },
            { name: 'exactAmountIn', type: 'uint256' },
            { name: 'minAmountOut', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
            { name: 'wethIsEth', type: 'bool' },
            { name: 'userData', type: 'bytes' }
        ],
        name: 'swapSingleTokenExactIn',
        outputs: [{ name: 'amountOut', type: 'uint256' }],
        stateMutability: 'payable',
        type: 'function'
    }
];
exports.swapExactOutAbi = [
    {
        inputs: [
            { name: 'pool', type: 'address' },
            { name: 'tokenIn', type: 'address' },
            { name: 'tokenInVault', type: 'address' },
            { name: 'tokenOut', type: 'address' },
            { name: 'tokenOutVault', type: 'address' },
            { name: 'exactAmountOut', type: 'uint256' },
            { name: 'maxAmountIn', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
            { name: 'wethIsEth', type: 'bool' },
            { name: 'userData', type: 'bytes' }
        ],
        name: 'swapSingleTokenExactOut',
        outputs: [{ name: 'amountIn', type: 'uint256' }],
        stateMutability: 'payable',
        type: 'function'
    }
];
