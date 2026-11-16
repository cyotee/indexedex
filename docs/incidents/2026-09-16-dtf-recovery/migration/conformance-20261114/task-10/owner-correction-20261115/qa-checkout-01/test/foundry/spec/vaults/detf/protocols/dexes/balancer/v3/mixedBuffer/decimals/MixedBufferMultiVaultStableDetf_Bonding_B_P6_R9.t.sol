// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Bonding_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Bonding_Decimals.sol";

/// @notice Book `B_P6_R9`. pairToken 6-dec; one other raw leg 9-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. DETF, sDETF and DETF SYs use 9 decimals; SE shares retain their existing precision.
contract MixedBufferMultiVaultStableDetf_Bonding_B_P6_R9 is MixedBufferMultiVaultStableDetf_Bonding_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
