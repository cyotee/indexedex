// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveCrossVersionLoopDeposit_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopDeposit_Decimals.sol";

/// @notice Combo `P18_R6`: pair tokenA 18 / tokenB 6.
contract AaveCrossVersionLoopDeposit_P18_R6 is AaveCrossVersionLoopDeposit_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
