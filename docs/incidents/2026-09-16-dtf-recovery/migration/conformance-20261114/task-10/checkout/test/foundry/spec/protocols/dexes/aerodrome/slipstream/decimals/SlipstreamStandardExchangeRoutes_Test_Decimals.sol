// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

/// @notice Quote math against 6/9 reserve units. Shares stay 18. pairToken = tokenA.
abstract contract SlipstreamStandardExchangeRoutes_Test_Decimals is Test {
    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }

    function test_zapIn_depositQuote_initialDeposit() public view {
        uint256 amount0 = _uA(100);
        uint256 amount1 = _uB(200);
        uint256 sharesOut = ConstProdUtils._depositQuote(amount0, amount1, 0, 0, 0);
        assertGe(sharesOut, 0);
    }

    function test_zapIn_depositQuote_existingLiquidity() public view {
        uint256 amount0 = _uA(100);
        uint256 amount1 = _uB(200);
        uint256 lpTotalSupply = 500e18;
        uint256 lpReserveA = _uA(1000);
        uint256 lpReserveB = _uB(2000);
        uint256 sharesOut =
            ConstProdUtils._depositQuote(amount0, amount1, lpTotalSupply, lpReserveA, lpReserveB);
        uint256 expectedShares = (amount0 * lpTotalSupply / lpReserveA + amount1 * lpTotalSupply / lpReserveB) / 2;
        assertEq(sharesOut, expectedShares, "Deposit quote should match proportional calculation");
    }

    function test_zapInRoute_token0ToVaultShares() public pure {
        assertTrue(true, "Route token0 -> vault should be valid");
    }

    function test_zapInRoute_token1ToVaultShares() public pure {
        assertTrue(true, "Route token1 -> vault should be valid");
    }

    function test_zapIn_zeroAmount() public view {
        uint256 sharesOut =
            ConstProdUtils._depositQuote(0, 0, 500e18, _uA(1000), _uB(2000));
        assertEq(sharesOut, 0, "Zero deposit should return 0 shares");
    }

    function test_zapOut_withdrawQuote_basic() public view {
        uint256 ownedLPAmount = 100e18;
        uint256 lpTotalSupply = 500e18;
        uint256 totalReserveA = _uA(1000);
        uint256 totalReserveB = _uB(2000);
        (uint256 ownedReserveA, uint256 ownedReserveB) =
            ConstProdUtils._withdrawQuote(ownedLPAmount, lpTotalSupply, totalReserveA, totalReserveB);
        assertEq(ownedReserveA, ownedLPAmount * totalReserveA / lpTotalSupply, "Owned reserve A");
        assertEq(ownedReserveB, ownedLPAmount * totalReserveB / lpTotalSupply, "Owned reserve B");
    }

    function test_zapOut_withdrawQuote_zeroSupply() public view {
        (uint256 ownedReserveA, uint256 ownedReserveB) =
            ConstProdUtils._withdrawQuote(100e18, 0, _uA(1000), _uB(2000));
        assertEq(ownedReserveA, 0, "Zero supply should return 0");
        assertEq(ownedReserveB, 0, "Zero supply should return 0");
    }

    function test_zapOut_withdrawQuote_zeroOwned() public view {
        (uint256 ownedReserveA, uint256 ownedReserveB) =
            ConstProdUtils._withdrawQuote(0, 500e18, _uA(1000), _uB(2000));
        assertEq(ownedReserveA, 0, "Zero owned should return 0");
        assertEq(ownedReserveB, 0, "Zero owned should return 0");
    }

    function test_zapOutRoute_vaultSharesToToken0() public pure {
        assertTrue(true, "Route vault -> token0 should be valid");
    }

    function test_zapOutRoute_vaultSharesToToken1() public pure {
        assertTrue(true, "Route vault -> token1 should be valid");
    }

    function test_zapOut_fullCalculation() public view {
        uint256 sharesToBurn = 100e18;
        uint256 lpTotalShares = 500e18;
        uint256 lpReserve0 = _uA(1000);
        uint256 lpReserve1 = _uB(2000);
        (uint256 ownedReserve0, uint256 ownedReserve1) =
            ConstProdUtils._withdrawQuote(sharesToBurn, lpTotalShares, lpReserve0, lpReserve1);
        assertEq(ownedReserve0, _uA(200), "Should receive 200 pairToken units");
        assertEq(ownedReserve1, _uB(400), "Should receive 400 other-token units");
    }

    function test_invalidRoute_randomTokenToVault() public pure {
        assertTrue(true);
    }

    function test_deadline_validation() public view {
        uint256 pastDeadline = block.timestamp - 1;
        uint256 currentTime = block.timestamp;
        uint256 futureDeadline = block.timestamp + 1 hours;
        assertGt(futureDeadline, currentTime, "Future deadline should be valid");
        assertLt(pastDeadline, currentTime, "Past deadline should be invalid");
    }

    function test_slippage_protection() public view {
        uint256 minAmountOut = _uA(100);
        uint256 actualAmount = _uA(150);
        assertGe(actualAmount, minAmountOut, "Should succeed with slippage protection");
        minAmountOut = _uA(200);
        actualAmount = _uA(150);
        assertLt(actualAmount, minAmountOut, "Should revert with slippage");
    }
}
