// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_BondClaim_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/adversarial/Adversarial_BondClaim_Decimals.sol";

/// @notice Book `B_P9_R6`. pairToken 9-dec; one other raw leg 6-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract Adversarial_BondClaim_B_P9_R6 is Adversarial_BondClaim_Decimals {
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
