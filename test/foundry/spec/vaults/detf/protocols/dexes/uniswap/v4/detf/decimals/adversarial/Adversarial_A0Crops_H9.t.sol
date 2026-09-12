// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_A0Crops_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_Decimals.sol";

/// @notice Combo `H9`. pairToken 9-dec mint/bond input; other/rate role 9-dec.
/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible. Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role.
contract Adversarial_A0Crops_H9_DexUniV4Det is Adversarial_A0Crops_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
}
