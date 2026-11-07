// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHook_Fees is TestBase {
    function test_dexFeePricesPaidSingleJoinPreparation() public {
        _firstMintEqual(500 ether);
        _ensureFeeTo();
        _setDexFee(0.001e18);
        uint256 lowFeeLp = quad.previewDepositSingle(address(token1), 20 ether);
        assertGt(lowFeeLp, 0);
        uint256 lowFeeOutput = quad.previewSwapExactIn(address(token1), address(token2), 20 ether);
        assertEq(quad.dexSwapFee(), 0.001e18);
        _setDexFee(0.05e18);
        uint256 highFeeLp = quad.previewDepositSingle(address(token1), 20 ether);
        assertGt(highFeeLp, 0);
        assertLt(highFeeLp, lowFeeLp);
        uint256 highFeeOutput = quad.previewSwapExactIn(address(token1), address(token2), 20 ether);
        assertEq(quad.dexSwapFee(), 0.05e18);
        assertGt(highFeeOutput, 0);
        assertLt(highFeeOutput, lowFeeOutput, "trading fee still prices actual swaps");
        uint256 beforeOutput = token2.balanceOf(user);
        _swapExactIn(address(token1), address(token2), 20 ether);
        assertEq(token2.balanceOf(user) - beforeOutput, highFeeOutput);
    }

    function test_mintFee_isBackedGrossSplit_notPriorGrowth() public {
        _ensureFeeTo();
        _setUsageFee(0.05e18);
        uint256 first = _firstMintEqual(100 ether);
        assertGt(first, 0);
        assertEq(quad.kLast(), 0, "retired growth checkpoint");

        address feeTo_ = address(quad.feeTo());
        assertTrue(feeTo_ != address(0));
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 bookedBefore = quad.seBalance(0);

        // Donate SE shares → inventory k rises without minting LP → rootK > kLast
        uint256 amountIn = 20 ether;
        token0.mint(user, amountIn);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);(uint256 seOut,) = IStandardExchangeIn(se0).exchangeIn(IERC20(address(token0)), amountIn, IERC20(se0), 0, user, false, block.timestamp + 1 hours
        );
        require(seOut > 0, "se mint");
        IERC20(se0).transfer(hook, seOut);
        vm.stopPrank();
        assertEq(quad.seBalance(0), bookedBefore, "ambient share donation is not booked");
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "donation does not mint LP");

        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        (uint256 prevShares,) = quad.previewJoinProportional(amounts);

        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, prevShares, "net LP preview equals actual mint");

        uint256 feeLpAfter = IERC20(hook).balanceOf(feeTo_);
        uint256 gross = IERC20(hook).totalSupply() - supplyBefore;
        assertEq(feeLpAfter - feeLpBefore, gross * 0.05e18 / 1e18);
        assertEq(shares + feeLpAfter - feeLpBefore, gross, "fee is not minted on top");
        assertGt(gross, 0);
        assertEq(quad.kLast(), 0);
    }

    function test_dexSwapFee_affectsExactIn() public {
        _firstMintEqual(200 ether);
        uint256 amountIn = 2 ether;
        _setDexFee(0.001e18);
        uint256 outLow = quad.previewSwapExactIn(address(token1), address(token0), amountIn);
        _setDexFee(0.05e18);
        uint256 outHigh = quad.previewSwapExactIn(address(token1), address(token0), amountIn);
        assertLt(outHigh, outLow, "higher dex fee reduces swap out");
    }
}
