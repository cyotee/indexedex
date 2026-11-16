// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_TrustFlags_Decimals_DexUniV4Det} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_TrustFlags_Decimals.sol";

/// @notice Combo `P6_R9`. pairToken 6-dec mint/bond input; other/rate role 9-dec.
/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible. Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role.
contract Adversarial_TrustFlags_P6_R9 is Adversarial_TrustFlags_Decimals_DexUniV4Det {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
}
