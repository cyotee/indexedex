// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_MixedBuffer_TrustFlag_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/adversarial/Adversarial_MixedBuffer_TrustFlag_Decimals.sol";

/// @notice Book `B_P9_R6`. pairToken 9-dec; one other raw leg 6-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. SE shares retain native precision; DETF and funded staking receipts use 9 decimals.
contract Adversarial_MixedBuffer_TrustFlag_B_P9_R6 is Adversarial_MixedBuffer_TrustFlag_Decimals {
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
