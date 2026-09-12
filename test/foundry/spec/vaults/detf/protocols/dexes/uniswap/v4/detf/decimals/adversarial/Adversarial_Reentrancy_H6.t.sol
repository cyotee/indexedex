// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_Reentrancy_Decimals_DexUniV4Det} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_Reentrancy_Decimals.sol";

/// @notice Combo `H6`. pairToken 6-dec mint/bond input; other/rate role 6-dec.
/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible. Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role.
contract Adversarial_Reentrancy_H6_DexUniV4Det is Adversarial_Reentrancy_Decimals_DexUniV4Det {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
