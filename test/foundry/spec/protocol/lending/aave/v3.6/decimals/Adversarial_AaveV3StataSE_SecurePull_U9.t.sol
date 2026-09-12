// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_AaveV3StataSE_SecurePull_Decimals} from
    "test/foundry/spec/protocol/lending/aave/v3.6/decimals/Adversarial_AaveV3StataSE_SecurePull_Decimals.sol";

/// @notice Combo `U9`: Stata SE adversarial I1/FreeMint/A0–A3/E1/E4/E5/H2/H3 on listed NINE.
contract Adversarial_AaveV3StataSE_SecurePull_U9 is Adversarial_AaveV3StataSE_SecurePull_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
