// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {CommonBufferMultiVaultStable_WalkAndExhaust_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/decimals/CommonBufferMultiVaultStable_WalkAndExhaust_Decimals.sol";

/// @notice Book `B_P6_R18`. pairToken 6-dec; one other raw leg 18-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract CommonBufferMultiVaultStable_WalkAndExhaust_B_P6_R18 is CommonBufferMultiVaultStable_WalkAndExhaust_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
