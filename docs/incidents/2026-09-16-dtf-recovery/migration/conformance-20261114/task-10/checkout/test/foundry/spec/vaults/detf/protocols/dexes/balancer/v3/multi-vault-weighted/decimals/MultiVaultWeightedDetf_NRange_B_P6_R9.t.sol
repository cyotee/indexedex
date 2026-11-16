// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MultiVaultWeightedDetf_NRange_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_NRange_Decimals.sol";

/// @notice Book `B_P6_R9`. pairToken 6-dec; one other raw leg 9-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract MultiVaultWeightedDetf_NRange_B_P6_R9 is MultiVaultWeightedDetf_NRange_Decimals {
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
