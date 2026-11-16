// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_ComposedStable_P0_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/decimals/adversarial/Adversarial_ComposedStable_P0_Decimals.sol";

/// @notice Book `B_ALL9`. pairToken 9-dec; one other raw leg 9-dec; remaining 9-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract Adversarial_ComposedStable_P0_B_ALL9 is Adversarial_ComposedStable_P0_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
