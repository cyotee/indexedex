"use strict";
'use client';
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildPermit2WitnessDigest = exports.createWitnessFromSwapParams = exports.signPermit2Witness = exports.getPermit2TypedData = exports.getFullDomainSeparator = exports.getWitnessTypehash = exports.getTokenPermissionsTypehash = exports.getPermitTypehash = exports.getPermit2DomainSeparator = void 0;
const viem_1 = require("viem");
const PERMIT2_NAME = 'Permit2';
const PERMIT_TRANSFER_FROM_TYPE = [
    { name: 'permitted', type: 'TokenPermissions' },
    { name: 'spender', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
    { name: 'witness', type: 'Witness' },
];
const TOKEN_PERMISSIONS_TYPE = [
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' },
];
const WITNESS_TYPE_STRING = 'Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)';
const WITNESS_TYPE = [
    { name: 'owner', type: 'address' },
    { name: 'pool', type: 'address' },
    { name: 'tokenIn', type: 'address' },
    { name: 'tokenInVault', type: 'address' },
    { name: 'tokenOut', type: 'address' },
    { name: 'tokenOutVault', type: 'address' },
    { name: 'amountIn', type: 'uint256' },
    { name: 'limit', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
    { name: 'wethIsEth', type: 'bool' },
    { name: 'userData', type: 'bytes32' },
];
const EMPTY_USERDATA_HASH = (0, viem_1.keccak256)('0x');
const PERMIT2_DOMAIN_TYPE = [
    { name: 'name', type: 'string' },
    { name: 'chainId', type: 'uint256' },
    { name: 'verifyingContract', type: 'address' },
];
function getPermit2DomainSeparator(chainId, permit2Address) {
    return (0, viem_1.keccak256)((0, viem_1.encodeAbiParameters)(PERMIT2_DOMAIN_TYPE, [
        PERMIT2_NAME,
        BigInt(chainId),
        permit2Address,
    ]));
}
exports.getPermit2DomainSeparator = getPermit2DomainSeparator;
function getPermitTypehash() {
    const stub = 'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,';
    return (0, viem_1.keccak256)((0, viem_1.toHex)(stub + WITNESS_TYPE_STRING, { size: 1024 }));
}
exports.getPermitTypehash = getPermitTypehash;
function getTokenPermissionsTypehash() {
    return (0, viem_1.keccak256)((0, viem_1.toHex)('TokenPermissions(address token,uint256 amount)', { size: 1024 }));
}
exports.getTokenPermissionsTypehash = getTokenPermissionsTypehash;
function getWitnessTypehash() {
    return (0, viem_1.keccak256)((0, viem_1.toHex)(WITNESS_TYPE_STRING, { size: 2048 }));
}
exports.getWitnessTypehash = getWitnessTypehash;
function getFullDomainSeparator(chainId, permit2Address) {
    const message = {};
    return {
        domain: {
            name: PERMIT2_NAME,
            chainId,
            verifyingContract: permit2Address,
        },
        types: {
            EIP712Domain: PERMIT2_DOMAIN_TYPE,
        },
        primaryType: 'EIP712Domain',
        message,
    };
}
exports.getFullDomainSeparator = getFullDomainSeparator;
function getPermit2TypedData(chainId, permit2Address, params) {
    const { token, amount, nonce, deadline, owner, spender, witness } = params;
    const message = {
        permitted: {
            token,
            amount,
        },
        spender,
        nonce,
        deadline,
        witness,
    };
    return {
        domain: {
            name: PERMIT2_NAME,
            chainId,
            verifyingContract: permit2Address,
        },
        types: {
            EIP712Domain: PERMIT2_DOMAIN_TYPE,
            PermitWitnessTransferFrom: PERMIT_TRANSFER_FROM_TYPE,
            TokenPermissions: TOKEN_PERMISSIONS_TYPE,
            Witness: WITNESS_TYPE,
        },
        primaryType: 'PermitWitnessTransferFrom',
        message,
    };
}
exports.getPermit2TypedData = getPermit2TypedData;
async function signPermit2Witness(signTypedData, chainId, permit2Address, params) {
    const typedData = getPermit2TypedData(chainId, permit2Address, params);
    return signTypedData(typedData);
}
exports.signPermit2Witness = signPermit2Witness;
function createWitnessFromSwapParams(owner, pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amountIn, limit, deadline, wethIsEth, userData = EMPTY_USERDATA_HASH) {
    return {
        owner,
        pool,
        tokenIn,
        tokenInVault,
        tokenOut,
        tokenOutVault,
        amountIn,
        limit,
        deadline,
        wethIsEth,
        userData,
    };
}
exports.createWitnessFromSwapParams = createWitnessFromSwapParams;
const DOMAIN_TYPEHASH = (0, viem_1.keccak256)((0, viem_1.toHex)('EIP712Domain(string name,uint256 chainId,address verifyingContract)'));
const TOKEN_PERMISSIONS_TYPEHASH = (0, viem_1.keccak256)((0, viem_1.toHex)('TokenPermissions(address token,uint256 amount)'));
const WITNESS_TYPEHASH = (0, viem_1.keccak256)((0, viem_1.toHex)('Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)'));
const PERMIT_STUB = 'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,';
function buildPermit2WitnessDigest(params) {
    const domainSeparator = (0, viem_1.keccak256)((0, viem_1.encodeAbiParameters)([
        { name: 'typeHash', type: 'bytes32' },
        { name: 'nameHash', type: 'bytes32' },
        { name: 'chainId', type: 'uint256' },
        { name: 'verifyingContract', type: 'address' },
    ], [DOMAIN_TYPEHASH, (0, viem_1.keccak256)((0, viem_1.toHex)(PERMIT2_NAME)), BigInt(params.chainId), params.permit2Address]));
    const tokenPermissionsHash = (0, viem_1.keccak256)((0, viem_1.encodeAbiParameters)([
        { name: 'typeHash', type: 'bytes32' },
        { name: 'token', type: 'address' },
        { name: 'amount', type: 'uint256' },
    ], [TOKEN_PERMISSIONS_TYPEHASH, params.token, params.amount]));
    const witnessHash = (0, viem_1.keccak256)((0, viem_1.encodeAbiParameters)([
        { name: 'typeHash', type: 'bytes32' },
        { name: 'owner', type: 'address' },
        { name: 'pool', type: 'address' },
        { name: 'tokenIn', type: 'address' },
        { name: 'tokenInVault', type: 'address' },
        { name: 'tokenOut', type: 'address' },
        { name: 'tokenOutVault', type: 'address' },
        { name: 'amountIn', type: 'uint256' },
        { name: 'limit', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'wethIsEth', type: 'bool' },
        { name: 'userData', type: 'bytes32' },
    ], [
        WITNESS_TYPEHASH,
        params.witness.owner,
        params.witness.pool,
        params.witness.tokenIn,
        params.witness.tokenInVault,
        params.witness.tokenOut,
        params.witness.tokenOutVault,
        params.witness.amountIn,
        params.witness.limit,
        params.witness.deadline,
        params.witness.wethIsEth,
        params.witness.userData,
    ]));
    const permitTypeHash = (0, viem_1.keccak256)((0, viem_1.toHex)(PERMIT_STUB + WITNESS_TYPE_STRING));
    const permitHash = (0, viem_1.keccak256)((0, viem_1.encodeAbiParameters)([
        { name: 'typeHash', type: 'bytes32' },
        { name: 'tokenPermissionsHash', type: 'bytes32' },
        { name: 'spender', type: 'address' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'witnessHash', type: 'bytes32' },
    ], [permitTypeHash, tokenPermissionsHash, params.spender, params.nonce, params.deadline, witnessHash]));
    return (0, viem_1.keccak256)((0, viem_1.concatHex)(['0x1901', domainSeparator, permitHash]));
}
exports.buildPermit2WitnessDigest = buildPermit2WitnessDigest;
