// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Fees is TestBase {
    function test_zeroRefundSwapCreditsOnlyActualSeShares() public {
        _firstMintEqual(100 ether);
        uint256 amount = 1 ether;
        (uint256 expectedShares, uint256 refund) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(address(token0)), amount, IERC20(se0));
        assertEq(refund, 0, "real ERC4626 SE consumes the input");
        assertGt(expectedShares, 0);
        uint256 sharesBefore = IERC20(se0).balanceOf(hook);
        uint256 localBefore = token0.balanceOf(hook);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        _swapExactIn(address(token0), address(token1), amount);
        assertEq(IERC20(se0).balanceOf(hook) - sharesBefore, expectedShares);
        assertEq(token0.balanceOf(hook), localBefore, "no fictitious refund or cleanup deposit");
        assertEq(IERC20(hook).totalSupply(), supplyBefore);
    }

    function test_dexFeePricesPaidSingleJoinPreparation() public {
        _firstMintEqual(500 ether);
        _ensureFeeTo();
        _setDexFee(0.001e18);
        uint256 lowFeeMint = quad.previewDepositSingle(address(token1), 20 ether);
        assertGt(lowFeeMint, 0);
        uint256 lowFeeOutput = quad.previewSwapExactIn(address(token1), address(token2), 20 ether);
        assertEq(quad.dexSwapFee(), 0.001e18);
        _setDexFee(0.05e18);
        uint256 highFeeMint = quad.previewDepositSingle(address(token1), 20 ether);
        assertGt(highFeeMint, 0);
        assertLt(highFeeMint, lowFeeMint, "preparation pays the trading fee");
        uint256 highFeeOutput = quad.previewSwapExactIn(address(token1), address(token2), 20 ether);
        assertEq(quad.dexSwapFee(), 0.05e18);
        assertGt(highFeeOutput, 0);
        assertLt(highFeeOutput, lowFeeOutput, "trading fee still prices actual swaps");
        vm.prank(user);
        assertEq(quad.depositSingle(address(token1), 20 ether, user, highFeeMint, block.timestamp), highFeeMint);
        highFeeOutput = quad.previewSwapExactIn(address(token1), address(token2), 20 ether);
        uint256 beforeOutput = token2.balanceOf(user);
        _swapExactIn(address(token1), address(token2), 20 ether);
        assertEq(token2.balanceOf(user) - beforeOutput, highFeeOutput);
    }

    function test_depositFee_splitsBackedMint_withoutGrowthMint() public {
        _ensureFeeTo(); _setUsageFee(0.05e18);
        uint256 first = _firstMintEqual(100 ether);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 genesisGross = supply - 1000;
        assertEq(first, genesisGross - genesisGross * 0.05e18 / 1e18);
        assertEq(IERC20(hook).balanceOf(quad.feeTo()), genesisGross * 0.05e18 / 1e18);
        assertEq(quad.kLast(), 0, "retired growth checkpoint");
        uint256 feesBefore = IERC20(hook).balanceOf(quad.feeTo());
        token0.mint(hook, 20 ether);
        assertEq(IERC20(hook).totalSupply(), supply, "ambient transfer cannot mint LP");
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        (uint256 quote,) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 net,) = quad.joinProportional(amounts, user, quote, block.timestamp);
        uint256 gross = IERC20(hook).totalSupply() - supply;
        assertEq(net, quote);
        assertEq(IERC20(hook).balanceOf(quad.feeTo()) - feesBefore, gross * 0.05e18 / 1e18);
        assertEq(net + gross * 0.05e18 / 1e18, gross);
        uint256[] memory minimum = new uint256[](4);
        feesBefore = IERC20(hook).balanceOf(quad.feeTo());
        vm.prank(user);
        quad.exitProportional(net, user, minimum, block.timestamp);
        assertEq(IERC20(hook).balanceOf(quad.feeTo()), feesBefore, "withdrawal does not mint a fee");
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
