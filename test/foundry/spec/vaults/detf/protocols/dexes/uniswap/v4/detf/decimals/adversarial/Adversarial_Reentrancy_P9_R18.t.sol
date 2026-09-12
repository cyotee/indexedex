// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_Reentrancy_Decimals_DexUniV4Det} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_Reentrancy_Decimals.sol";

/// @notice Combo `P9_R18`. pairToken 9-dec mint/bond input; other/rate role 18-dec.
/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible. Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role.
contract Adversarial_Reentrancy_P9_R18_DexUniV4Det is Adversarial_Reentrancy_Decimals_DexUniV4Det {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }
}
