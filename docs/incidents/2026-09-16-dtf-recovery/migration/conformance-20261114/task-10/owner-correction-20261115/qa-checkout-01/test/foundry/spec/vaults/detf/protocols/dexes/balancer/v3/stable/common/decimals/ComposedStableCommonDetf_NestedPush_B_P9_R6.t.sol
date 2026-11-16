// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ComposedStableCommonDetf_NestedPush_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/decimals/ComposedStableCommonDetf_NestedPush_Decimals.sol";

/// @notice Book `B_P9_R6`. pairToken 9-dec; one other raw leg 6-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract ComposedStableCommonDetf_NestedPush_B_P9_R6 is ComposedStableCommonDetf_NestedPush_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
