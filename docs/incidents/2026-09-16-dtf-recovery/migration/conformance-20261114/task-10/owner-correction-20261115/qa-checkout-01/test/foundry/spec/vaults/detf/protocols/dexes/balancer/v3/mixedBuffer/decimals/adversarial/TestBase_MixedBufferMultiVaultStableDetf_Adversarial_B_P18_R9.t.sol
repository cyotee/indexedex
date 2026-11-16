// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_MixedBufferMultiVaultStableDetf_Adversarial_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial_Decimals.sol";

/// @notice Book `B_P18_R9`. pairToken 18-dec; one other raw leg 9-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. SE shares retain native precision; DETF and funded staking receipts use 9 decimals.
contract TestBase_MixedBufferMultiVaultStableDetf_Adversarial_B_P18_R9 is TestBase_MixedBufferMultiVaultStableDetf_Adversarial_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
