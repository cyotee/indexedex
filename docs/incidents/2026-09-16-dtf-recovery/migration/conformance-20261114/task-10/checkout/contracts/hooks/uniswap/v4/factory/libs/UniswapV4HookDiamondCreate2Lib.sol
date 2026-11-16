// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";

/**
 * @title UniswapV4HookDiamondCreate2Lib
 * @notice Pure CREATE2 salt / flag / mine helpers for UniswapV4HookDiamondPackageCallBackFactory.
 * @dev Salt law (P19): processArgs → packageSalt → finalSalt = keccak256(abi.encode(packageSalt, mineNonce)).
 *      Package address is never mixed into the salt.
 *
 *      Mining helpers MUST NOT allocate via `abi.encode` / `abi.encodePacked` in the hot loop — Solidity
 *      never frees memory within a call, so ~MAX_LOOP allocations OOGs (MemoryOOG / OutOfGas) on
 *      `deploy()` auto-mine. All address prediction uses fixed scratch memory in assembly.
 */
library UniswapV4HookDiamondCreate2Lib {
    uint160 internal constant FLAG_MASK = Hooks.ALL_HOOK_MASK;
    uint256 internal constant MAX_LOOP = 160_444;

    error HookMineExhausted();

    /// @dev Equivalent to `keccak256(abi.encode(packageSalt, mineNonce))` without growing free memory.
    function previewFinalSalt(bytes32 packageSalt, uint256 mineNonce) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, packageSalt)
            mstore(0x20, mineNonce)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Predict CREATE2 proxy address for (factory, packageSalt, mineNonce).
     * @dev Matches `Creation._create2AddressFromOf(factory, initCodeHash, keccak256(abi.encode(packageSalt, mineNonce)))`
     *      but reuses only the 0x00–0x60 scratch region so on-chain auto-mine loops stay memory-bounded.
     *      Free-memory pointer at 0x40 is saved/restored because the CREATE2 preimage layout uses 0x40.
     */
    function predictAddress(address factory, bytes32 initCodeHash, bytes32 packageSalt, uint256 mineNonce)
        internal
        pure
        returns (address predicted)
    {
        assembly ("memory-safe") {
            let free := mload(0x40)
            // finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
            mstore(0x00, packageSalt)
            mstore(0x20, mineNonce)
            let finalSalt := keccak256(0x00, 0x40)

            // CREATE2: keccak256(0xff ++ factory ++ finalSalt ++ initCodeHash)
            // Preimage at 0x0b..0x60 (85 bytes): 0xff | factory | salt | initCodeHash
            mstore(0x00, factory)
            mstore(0x20, finalSalt)
            mstore(0x40, initCodeHash)
            mstore8(0x0b, 0xff)
            predicted := and(keccak256(0x0b, 85), 0xffffffffffffffffffffffffffffffffffffffff)
            mstore(0x40, free)
        }
    }

    function flagsMatch(address predicted, uint160 requiredFlags) internal pure returns (bool) {
        return (uint160(predicted) & FLAG_MASK) == (requiredFlags & FLAG_MASK);
    }

    /**
     * @notice Mine mineNonce in [0, maxLoop) such that CREATE2 address flags match requiredFlags.
     * @dev Entire loop is one assembly block — no Solidity per-iteration allocations.
     *      Production deploy uses MAX_LOOP. Tests inject small maxLoop for exhaustion (H7).
     */
    function findMineNonce(
        address factory,
        bytes32 initCodeHash,
        bytes32 packageSalt,
        uint160 requiredFlags,
        uint256 maxLoop
    ) internal pure returns (uint256 mineNonce) {
        uint160 want = requiredFlags & FLAG_MASK;
        uint160 mask = FLAG_MASK;
        bool found;
        assembly ("memory-safe") {
            let free := mload(0x40)
            // factory left-padded once (upper 12 bytes zero)
            let factoryWord := factory
            for { let n := 0 } lt(n, maxLoop) { n := add(n, 1) } {
                // finalSalt = keccak256(abi.encode(packageSalt, n))
                mstore(0x00, packageSalt)
                mstore(0x20, n)
                let finalSalt := keccak256(0x00, 0x40)

                // CREATE2 preimage
                mstore(0x00, factoryWord)
                mstore(0x20, finalSalt)
                mstore(0x40, initCodeHash)
                mstore8(0x0b, 0xff)
                let predicted := and(keccak256(0x0b, 85), 0xffffffffffffffffffffffffffffffffffffffff)

                if eq(and(predicted, mask), want) {
                    mineNonce := n
                    found := 1
                    break
                }
            }
            mstore(0x40, free)
        }
        if (!found) revert HookMineExhausted();
    }
}
