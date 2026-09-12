// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveV3StataStandardExchange_Real_Decimals} from
    "test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_Decimals.sol";

/// @notice Combo `U9`: Real Stata SE money paths on listed NINE (9-dec base).
contract AaveV3StataStandardExchange_Real_U9 is AaveV3StataStandardExchange_Real_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
