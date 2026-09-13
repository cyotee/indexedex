// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveCrossVersionLoopDeposit_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopDeposit_Decimals.sol";

/// @notice Combo `P6_R9`: pair tokenA 6 / tokenB 9.
contract AaveCrossVersionLoopDeposit_P6_R9 is AaveCrossVersionLoopDeposit_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
