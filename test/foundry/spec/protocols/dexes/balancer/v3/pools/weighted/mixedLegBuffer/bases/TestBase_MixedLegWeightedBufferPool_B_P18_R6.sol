// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_MixedLegWeightedBufferPool_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool_Decimals.sol";

/// @notice Book `B_P18_R6`. pairToken 18-dec; one other raw leg 6-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
abstract contract TestBase_MixedLegWeightedBufferPool_B_P18_R6 is TestBase_MixedLegWeightedBufferPool_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
    function _restDecimals() internal pure override returns (uint8) { return 18; }
}
