"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.findNextUnusedPermit2Nonce = exports.findFirstUnusedNonce = exports.fetchPermit2Nonce = void 0;
// ABI for Permit2's nonceBitmap function
const nonceBitmapAbi = [{
        inputs: [
            { name: 'owner', type: 'address' },
            { name: 'wordIndex', type: 'uint256' }
        ],
        name: 'nonceBitmap',
        outputs: [{ name: 'bitmap', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function'
    }];
function extractBigIntReadResult(result) {
    if (typeof result === 'bigint')
        return result;
    if (Array.isArray(result) && typeof result[0] === 'bigint')
        return result[0];
    if (typeof result === 'object' && result !== null) {
        const record = result;
        const zero = record['0'];
        if (typeof zero === 'bigint')
            return zero;
    }
    throw new Error('Unexpected readContract return shape; expected bigint');
}
/**
 * Fetch the Permit2 nonce bitmap for a given owner
 */
async function fetchPermit2Nonce(publicClient, permit2Address, owner, wordIndex = BigInt(0)) {
    const result = await publicClient.readContract({
        address: permit2Address,
        abi: nonceBitmapAbi,
        functionName: 'nonceBitmap',
        args: [owner, wordIndex]
    });
    return extractBigIntReadResult(result);
}
exports.fetchPermit2Nonce = fetchPermit2Nonce;
/**
 * Find the first unused nonce from a bitmap
 * The bitmap uses 1 for used/nonce and 0 for unused
 * We invert to find the first 0 bit
 */
function findFirstUnusedNonce(bitmap) {
    const inverted = ~bitmap & ((BigInt(1) << BigInt(256)) - BigInt(1));
    for (let i = 0; i < 256; i++) {
        if (((inverted >> BigInt(i)) & BigInt(1)) === BigInt(1)) {
            return BigInt(i);
        }
    }
    // If all 256 nonces in this word are used, return 256 (next word)
    return BigInt(256);
}
exports.findFirstUnusedNonce = findFirstUnusedNonce;
async function findNextUnusedPermit2Nonce(publicClient, permit2Address, owner, maxWords = 8) {
    for (let w = 0; w < maxWords; w++) {
        const wordIndex = BigInt(w);
        const bitmap = await fetchPermit2Nonce(publicClient, permit2Address, owner, wordIndex);
        const bitIndex = findFirstUnusedNonce(bitmap);
        if (bitIndex < BigInt(256)) {
            return (wordIndex << BigInt(8)) | bitIndex;
        }
    }
    throw new Error(`No unused Permit2 nonce found in first ${maxWords} words`);
}
exports.findNextUnusedPermit2Nonce = findNextUnusedPermit2Nonce;
