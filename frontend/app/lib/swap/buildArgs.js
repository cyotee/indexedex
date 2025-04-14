"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildExactOutArgs = exports.buildExactInArgs = exports.ZERO_ADDR = void 0;
// Build arguments for swap transactions
const types_1 = require("./types");
var types_2 = require("./types");
Object.defineProperty(exports, "ZERO_ADDR", { enumerable: true, get: function () { return types_2.ZERO_ADDR; } });
function buildExactInArgs(input) {
    const missing = [];
    const { poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountIn, sender, useTokenInVault, useTokenOutVault } = input;
    let route = null;
    let finalPool = null;
    let tokenInVaultArg = types_1.ZERO_ADDR;
    let tokenOutVaultArg = types_1.ZERO_ADDR;
    const hasPool = !!poolAddress;
    const hasTokenIn = !!tokenInAddress;
    const hasTokenOut = !!tokenOutAddress;
    if (!useTokenInVault && !useTokenOutVault && poolType === 'balancer') {
        route = 'Direct Balancer V3 Swap';
        finalPool = (poolAddress || null);
        tokenInVaultArg = types_1.ZERO_ADDR;
        tokenOutVaultArg = types_1.ZERO_ADDR;
    }
    else if (useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== types_1.ZERO_ADDR && tokenInVaultAddress === tokenOutVaultAddress) {
        route = 'Strategy Vault Pass-Through';
        finalPool = tokenInVaultAddress;
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    else if (useTokenInVault && !useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== types_1.ZERO_ADDR && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
        route = 'Strategy Vault Deposit';
        finalPool = tokenInVaultAddress;
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = types_1.ZERO_ADDR;
    }
    else if (!useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenOutVaultAddress !== types_1.ZERO_ADDR && tokenInAddress && tokenInAddress === tokenOutVaultAddress) {
        route = 'Strategy Vault Withdrawal';
        finalPool = tokenOutVaultAddress;
        tokenInVaultArg = types_1.ZERO_ADDR;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    else if (useTokenInVault && !useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== types_1.ZERO_ADDR) {
        route = 'Vault Deposit + Balancer Swap';
        finalPool = (poolAddress || null);
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = types_1.ZERO_ADDR;
    }
    else if (!useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenOutVaultAddress !== types_1.ZERO_ADDR) {
        route = 'Balancer Swap + Vault Withdrawal';
        finalPool = (poolAddress || null);
        tokenInVaultArg = types_1.ZERO_ADDR;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    else if (useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== types_1.ZERO_ADDR && tokenOutVaultAddress !== types_1.ZERO_ADDR) {
        route = 'Vault Deposit → Balancer Swap → Vault Withdrawal';
        finalPool = (poolAddress || null);
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    if (!route) {
        return { route: null, finalPool: null, args: null, valid: false, missing: ['route'] };
    }
    if (!hasPool)
        missing.push('pool');
    if (!hasTokenIn)
        missing.push('tokenIn');
    if (!hasTokenOut)
        missing.push('tokenOut');
    if (!exactAmountIn)
        missing.push('exactAmountIn');
    if (!sender)
        missing.push('sender');
    // Additional validation: for Deposit -> Balancer Swap, tokenOut must NOT be the deposit vault address
    if (route === 'Vault Deposit + Balancer Swap' && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
        missing.push('tokenOut (must be non-vault token for this route)');
    }
    if (missing.length > 0 || !finalPool || !tokenInAddress || !tokenOutAddress || !exactAmountIn || !sender) {
        return { route, finalPool: finalPool || null, args: null, valid: false, missing };
    }
    const args = [
        finalPool,
        tokenInAddress,
        tokenInVaultArg,
        tokenOutAddress,
        tokenOutVaultArg,
        exactAmountIn,
        sender,
        '0x'
    ];
    return { route, finalPool, args, valid: true, missing };
}
exports.buildExactInArgs = buildExactInArgs;
function buildExactOutArgs(input) {
    const missing = [];
    const { poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountOut, sender, useTokenInVault, useTokenOutVault } = input;
    let route = null;
    let finalPool = null;
    let tokenInVaultArg = types_1.ZERO_ADDR;
    let tokenOutVaultArg = types_1.ZERO_ADDR;
    const hasPool = !!poolAddress;
    const hasTokenIn = !!tokenInAddress;
    const hasTokenOut = !!tokenOutAddress;
    if (!useTokenInVault && !useTokenOutVault && poolType === 'balancer') {
        route = 'Direct Balancer V3 Swap';
        finalPool = (poolAddress || null);
        tokenInVaultArg = types_1.ZERO_ADDR;
        tokenOutVaultArg = types_1.ZERO_ADDR;
    }
    else if (useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== types_1.ZERO_ADDR && tokenInVaultAddress === tokenOutVaultAddress) {
        route = 'Strategy Vault Pass-Through';
        finalPool = tokenInVaultAddress;
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    else if (useTokenInVault && !useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== types_1.ZERO_ADDR && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
        route = 'Strategy Vault Deposit';
        finalPool = tokenInVaultAddress;
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = types_1.ZERO_ADDR;
    }
    else if (!useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenOutVaultAddress !== types_1.ZERO_ADDR && tokenInAddress && tokenInAddress === tokenOutVaultAddress) {
        route = 'Strategy Vault Withdrawal';
        finalPool = tokenOutVaultAddress;
        tokenInVaultArg = types_1.ZERO_ADDR;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    else if (useTokenInVault && !useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== types_1.ZERO_ADDR) {
        route = 'Vault Deposit + Balancer Swap';
        finalPool = (poolAddress || null);
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = types_1.ZERO_ADDR;
    }
    else if (!useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenOutVaultAddress !== types_1.ZERO_ADDR) {
        route = 'Balancer Swap + Vault Withdrawal';
        finalPool = (poolAddress || null);
        tokenInVaultArg = types_1.ZERO_ADDR;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    else if (useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== types_1.ZERO_ADDR && tokenOutVaultAddress !== types_1.ZERO_ADDR) {
        route = 'Vault Deposit → Balancer Swap → Vault Withdrawal';
        finalPool = (poolAddress || null);
        tokenInVaultArg = tokenInVaultAddress;
        tokenOutVaultArg = tokenOutVaultAddress;
    }
    if (!route) {
        return { route: null, finalPool: null, args: null, valid: false, missing: ['route'] };
    }
    if (!hasPool)
        missing.push('pool');
    if (!hasTokenIn)
        missing.push('tokenIn');
    if (!hasTokenOut)
        missing.push('tokenOut');
    if (!exactAmountOut)
        missing.push('exactAmountOut');
    if (!sender)
        missing.push('sender');
    // Mirror ExactIn validation: for Deposit -> Balancer Swap, tokenOut must NOT be the deposit vault address
    if (route === 'Vault Deposit + Balancer Swap' && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
        missing.push('tokenOut (must be non-vault token for this route)');
    }
    if (missing.length > 0 || !finalPool || !tokenInAddress || !tokenOutAddress || !exactAmountOut || !sender) {
        return { route, finalPool: finalPool || null, args: null, valid: false, missing };
    }
    const args = [
        finalPool,
        tokenInAddress,
        tokenInVaultArg,
        tokenOutAddress,
        tokenOutVaultArg,
        exactAmountOut,
        sender,
        '0x'
    ];
    return { route, finalPool, args, valid: true, missing };
}
exports.buildExactOutArgs = buildExactOutArgs;
