// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_CommonBufferMultiVaultWeightedPool_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool_Decimals.sol";

/// @notice Book `B_P6_R18`. pairToken 6-dec; one other raw leg 18-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
abstract contract TestBase_CommonBufferMultiVaultWeightedPool_B_P6_R18 is TestBase_CommonBufferMultiVaultWeightedPool_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }
    function _restDecimals() internal pure override returns (uint8) { return 18; }
}
