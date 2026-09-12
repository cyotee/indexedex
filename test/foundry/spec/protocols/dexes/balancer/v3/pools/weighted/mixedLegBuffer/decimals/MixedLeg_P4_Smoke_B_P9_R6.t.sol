// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedLeg_P4_Smoke_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/decimals/MixedLeg_P4_Smoke_Decimals.sol";

/// @notice Book `B_P9_R6`. pairToken 9-dec; one other raw leg 6-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract MixedLeg_P4_Smoke_B_P9_R6 is MixedLeg_P4_Smoke_Decimals {
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
