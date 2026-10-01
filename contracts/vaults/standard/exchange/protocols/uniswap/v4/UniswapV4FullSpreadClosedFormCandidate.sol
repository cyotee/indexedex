// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";

library UniswapV4FullSpreadClosedFormCandidate {
    uint256 internal constant WAD = 1e18;

    function targetFree(uint256 total, uint256 pWad) internal pure returns (uint256) {
        return (total * pWad) / (WAD + pWad);
    }

    function oldPercentOfTotal(uint256 total, uint256 pWad) internal pure returns (uint256) {
        return (total * pWad) / WAD;
    }

    function cfBShares(uint256 reserveOut, uint256 amountOut, uint256 supply) internal pure returns (uint256) {
        uint256 radicand = (supply * supply * (reserveOut - amountOut)) / reserveOut;
        return supply - FixedPointMathLib.sqrt(radicand);
    }
}
