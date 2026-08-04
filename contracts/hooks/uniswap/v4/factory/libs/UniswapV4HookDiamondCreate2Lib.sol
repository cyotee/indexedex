// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {Creation} from "@crane/contracts/utils/Creation.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";

/**
 * @title UniswapV4HookDiamondCreate2Lib
 * @notice Pure CREATE2 salt / flag / mine helpers for UniswapV4HookDiamondPackageCallBackFactory.
 * @dev Salt law (P19): processArgs → packageSalt → finalSalt = keccak256(abi.encode(packageSalt, mineNonce)).
 *      Package address is never mixed into the salt.
 */
library UniswapV4HookDiamondCreate2Lib {
    using Creation for address;

    uint160 internal constant FLAG_MASK = Hooks.ALL_HOOK_MASK;
    uint256 internal constant MAX_LOOP = 160_444;

    error HookMineExhausted();

    function previewFinalSalt(bytes32 packageSalt, uint256 mineNonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(packageSalt, mineNonce));
    }

    function predictAddress(address factory, bytes32 initCodeHash, bytes32 packageSalt, uint256 mineNonce)
        internal
        pure
        returns (address)
    {
        return Creation._create2AddressFromOf(factory, initCodeHash, previewFinalSalt(packageSalt, mineNonce));
    }

    function flagsMatch(address predicted, uint160 requiredFlags) internal pure returns (bool) {
        return (uint160(predicted) & FLAG_MASK) == (requiredFlags & FLAG_MASK);
    }

    /**
     * @notice Mine mineNonce in [0, maxLoop) such that CREATE2 address flags match requiredFlags.
     * @dev Production deploy uses MAX_LOOP. Tests inject small maxLoop for exhaustion (H7).
     */
    function findMineNonce(
        address factory,
        bytes32 initCodeHash,
        bytes32 packageSalt,
        uint160 requiredFlags,
        uint256 maxLoop
    ) internal pure returns (uint256 mineNonce) {
        uint160 want = requiredFlags & FLAG_MASK;
        for (mineNonce = 0; mineNonce < maxLoop; mineNonce++) {
            address predicted = predictAddress(factory, initCodeHash, packageSalt, mineNonce);
            if ((uint160(predicted) & FLAG_MASK) == want) {
                return mineNonce;
            }
        }
        revert HookMineExhausted();
    }
}
