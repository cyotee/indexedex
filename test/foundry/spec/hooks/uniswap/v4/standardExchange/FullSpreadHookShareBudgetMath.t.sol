// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";

/// @notice Independent integer controls for native-share spending ceilings and EO debit valuation.
contract FullSpreadHookShareBudgetMathTest is Test {
    function test_nonUnitRateSixDecimalFaceEighteenDecimalShares() public pure {
        assertEq(Math.sharesForPairUnitsDown(3e6, 2e18, 1e18, 1e30), 15e17);
        assertEq(Math.ratedPairUnitsUp(15e17, 2e18, 1e18, 1e30), 3e6);
    }

    function test_twentyEightDecimalSharesPreserveWholeShareRate() public pure {
        assertEq(Math.sharesForPairUnitsDown(3e18, 2e18, 1e8, 1e18), 15e27);
        assertEq(Math.ratedPairUnitsUp(15e27, 2e18, 1e8, 1e18), 3e18);
    }

    function test_subShareBudgetDoesNotRoundUpToAuthorizeSpending() public pure {
        assertEq(Math.sharesForPairUnitsDown(1, 3e18, 1e18, 1e18), 0);
        assertEq(Math.sharesForPairUnitsUp(1, 3e18, 1e18, 1e18), 1);
        assertEq(Math.ratedPairUnitsUp(1, 15e17, 1e18, 1e18), 2);
    }

    function testFuzz_downBudgetAndUpDebit(uint96 budget, uint64 rateSeed) public pure {
        uint256 rate = uint256(rateSeed) + 1;
        uint256 shares = Math.sharesForPairUnitsDown(budget, rate, 1e18, 1e18);
        assertEq(shares, uint256(budget) * 1e18 / rate);
        assertLe(Math.ratedPairUnitsUp(shares, rate, 1e18, 1e18), budget);
    }
}
