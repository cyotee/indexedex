// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Liveness_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Liveness_Decimals.sol";

/// @notice Book `B_ALL6`. pairToken 6-dec; one other raw leg 6-dec; remaining 6-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. DETF, sDETF and DETF SYs use 9 decimals; SE shares retain their existing precision.
contract MixedBufferMultiVaultStableDetf_Liveness_B_ALL6 is MixedBufferMultiVaultStableDetf_Liveness_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
