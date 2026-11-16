// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Liquidity is TestBase {
    /// @notice Paid preparation is independently priced before checking every post-trade component.
    function test_singleJoin_grossMintCannotDilutePostSwapComponents() public {
        _ensureFeeTo();
        _setUsageFee(0.05e18);
        _setDexFee(0.001e18);
        _firstMintEqual(500 ether);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 fees = IERC20(hook).balanceOf(quad.feeTo());
        uint256[] memory book = quad.nativeReserves();
        uint256 local = token0.balanceOf(hook);
        uint256[] memory rated = new uint256[](4);
        for (uint256 i; i < 4; ++i) rated[i] = book[i];
        uint256 rate = IRateProvider(quad.rateProvider(address(token0))).getRate();
        rated[0] = book[0] * rate / 1e18 + local;
        uint256 totalBook;
        for (uint256 i; i < 4; ++i) totalBook += rated[i];
        uint256[] memory offered = new uint256[](4);
        offered[1] = 20 ether;
        uint256 remaining = 20 ether - 20 ether * rated[1] / totalBook;
        uint256 offeredLocal;
        // Independently allocate the raw caller input across the initial book's target weights.
        for (uint256 j; j < 4; ++j) {
            if (j == 1) continue;
            uint256 sold = 20 ether * rated[j] / totalBook;
            if (sold > remaining) sold = remaining;
            remaining -= sold;
            uint256 budget = StableMath.computeOutGivenExactIn(
                quad.getCurrentAmp(), rated, 1, j, sold - sold * quad.dexSwapFee() / 1e18,
                StableMath.computeInvariant(quad.getCurrentAmp(), rated)
            );
            uint256 denominator = j == 0 ? (book[0] * rate + 1e18 - 1) / 1e18 + local : rated[j];
            uint256 bought = book[j] * budget / denominator;
            offered[j] = bought;
            book[j] -= bought;
            if (j == 0) {
                offeredLocal = local * budget / denominator;
                local -= offeredLocal;
                rated[j] = book[j] * rate / 1e18 + local;
            } else rated[j] = book[j];
            offered[1] -= sold;
            book[1] += sold;
            rated[1] += sold;
        }
        uint256 gross = type(uint256).max;
        for (uint256 i; i < 4; ++i) {
            uint256 limit = offered[i] * supply / book[i];
            if (limit < gross) gross = limit;
        }
        uint256 localLimit = offeredLocal * supply / local;
        if (localLimit < gross) gross = localLimit;
        uint256 predicted = quad.previewDepositSingle(address(token1), 20 ether);
        assertEq(predicted, gross - gross * 0.05e18 / 1e18);
        vm.prank(user);
        uint256 minted = quad.depositSingle(address(token1), 20 ether, user, predicted, block.timestamp);
        assertEq(minted, predicted);
        assertEq(IERC20(hook).totalSupply() - supply, gross, "fee LP is part of backed gross");
        assertEq(IERC20(hook).balanceOf(quad.feeTo()) - fees, gross - minted);
        for (uint256 i; i < 4; ++i) {
            uint256 accepted = (gross * book[i] + supply - 1) / supply;
            assertEq(quad.nativeReserve(i), book[i] + accepted, "ceil-proportional post-swap acceptance");
            assertGe(quad.nativeReserve(i) * supply, book[i] * IERC20(hook).totalSupply());
        }
        assertEq(token0.balanceOf(hook), local + (gross * local + supply - 1) / supply);
    }

    /// @notice Failed minima revert the actual conversion and every paid ownership transfer.
    function test_singleJoin_failedMinimumRestoresPreparation() public {
        _firstMintEqual(500 ether);
        assertGt(quad.previewDepositSingle(address(token0), 20 ether), 0);
        bytes32 before_ = _componentOwnershipState(user);
        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        quad.depositSingle(address(token0), 20 ether, user, type(uint256).max, block.timestamp);
        assertEq(_componentOwnershipState(user), before_);
    }

    function test_propJoinExit_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 50 ether;
        (uint256 pShares,) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, pShares);

        uint256 supply = IERC20(hook).totalSupply();
        uint256 burn = shares / 2;
        uint256[] memory mins = new uint256[](4);
        uint256[] memory pOut = quad.previewExitProportional(burn);
        vm.prank(user);
        uint256[] memory out = quad.exitProportional(burn, user, mins, block.timestamp + 1);
        for (uint256 i; i < 4; ++i) {
            assertEq(out[i], pOut[i]);
            assertGt(out[i], 0);
        }
        // full-book floors
        for (uint256 i; i < 4; ++i) {
            assertGt(quad.nativeReserve(i), 0);
        }
        assertEq(IERC20(hook).totalSupply(), supply - burn);
    }

    function test_exitProportional_allocatesOnlyTheCallersLocalBook() public {
        uint256 shares = _firstMintEqual(500 ether);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 local = token0.balanceOf(hook);
        assertGt(local, 0, "share genesis creates local inventory");
        uint256[] memory minimum = new uint256[](4);
        uint256 userBefore = token0.balanceOf(user);
        vm.prank(user);
        uint256[] memory out = quad.exitProportional(shares / 2, user, minimum, block.timestamp);
        assertEq(token0.balanceOf(user) - userBefore, out[0]);
        assertEq(token0.balanceOf(hook), local - (shares / 2) * local / supply, "remaining local belongs to continuing LP");
    }

    function test_singleRawJoinAndSingleExit_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256 predicted = quad.previewDepositSingle(address(token1), 20 ether);
        assertGt(predicted, 0);
        vm.prank(user);
        uint256 shares = quad.depositSingle(address(token1), 20 ether, user, predicted, block.timestamp + 1);
        assertEq(shares, predicted); assertGt(shares, 0);
        uint256 quotedOut = quad.previewWithdrawSingle(address(token1), shares);
        uint256 beforeOut = IERC20(address(token1)).balanceOf(user);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(address(token1), shares, user, quotedOut, block.timestamp + 1);
        assertEq(out, quotedOut); assertGt(out, 0);
        assertEq(IERC20(address(token1)).balanceOf(user) - beforeOut, out);
    }

    /// @notice B6: buffered leg accepts SE vault share on deposit and withdraw (no unwrap required).
    function test_B6_singleShareJoinAndShareExit() public {
        _firstMintEqual(500 ether);
        token0.mint(user, 100 ether);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        (uint256 seShares,) = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), 50 ether, IERC20(se0), 1, user, false, block.timestamp + 1);
        IERC20(se0).approve(hook, type(uint256).max);
        vm.stopPrank();
        uint256 half = seShares / 2;
        assertGt(half, 0);
        uint256 predicted = quad.previewDepositSingle(se0, half);
        assertGt(predicted, 0);
        vm.prank(user);
        uint256 shares = quad.depositSingle(se0, half, user, predicted, block.timestamp + 1);
        assertEq(shares, predicted); assertGt(shares, 0);
        uint256 seBefore = IERC20(se0).balanceOf(user);
        uint256 quotedOut = quad.previewWithdrawSingle(se0, shares);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(se0, shares, user, quotedOut, block.timestamp + 1);
        assertEq(out, quotedOut); assertGt(out, 0);
        assertEq(IERC20(se0).balanceOf(user) - seBefore, out);
    }

    /// @notice B6: same buffered leg also accepts pair token units (existing path).
    function test_B6_singlePairJoinAndBufferedExit() public {
        _firstMintEqual(500 ether);
        uint256 predicted = quad.previewDepositSingle(address(token0), 20 ether);
        assertGt(predicted, 0);
        vm.prank(user);
        uint256 shares = quad.depositSingle(address(token0), 20 ether, user, predicted, block.timestamp + 1);
        assertEq(shares, predicted); assertGt(shares, 0);
        uint256 quotedOut = quad.previewWithdrawSingle(address(token0), shares);
        uint256 beforeOut = IERC20(address(token0)).balanceOf(user);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(address(token0), shares, user, quotedOut, block.timestamp + 1);
        assertEq(out, quotedOut); assertGt(out, 0);
        assertEq(IERC20(address(token0)).balanceOf(user) - beforeOut, out);
    }

    function test_completeUnbalancedJoinAndExactOutputExitsExecute() public {
        _firstMintEqual(200 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        amounts[1] = 20 ether;
        uint256 quote = quad.previewJoinUnbalanced(amounts);
        assertGt(quote, 0);
        vm.prank(user);
        assertEq(quad.joinUnbalanced(amounts, user, quote, block.timestamp), quote);
        uint256 required = quad.previewJoinSingleAssetExactOut(address(token1), 1 ether);
        assertGt(required, 0);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 feeBefore = IERC20(hook).balanceOf(quad.feeTo());
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 inputBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 spent = quad.joinSingleAssetExactOut(address(token1), 1 ether, user, required, block.timestamp);
        assertEq(inputBefore - token1.balanceOf(user), spent);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, 1 ether);
        assertEq(IERC20(hook).totalSupply() - supply, 1 ether + IERC20(hook).balanceOf(quad.feeTo()) - feeBefore);
        uint256 burned = quad.previewExitSingleAssetExactTokenOut(address(token1), 1 ether);
        uint256 beforeOut = token1.balanceOf(user);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        assertEq(quad.exitSingleAssetExactTokenOut(address(token1), 1 ether, user, burned, block.timestamp), burned);
        assertEq(token1.balanceOf(user) - beforeOut, 1 ether);
        assertEq(beforeLp - IERC20(hook).balanceOf(user), burned);
        burned = quad.previewWithdrawSingleExactOut(address(token1), 1 ether);
        beforeOut = token1.balanceOf(user); beforeLp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        assertEq(quad.withdrawSingleExactOut(address(token1), 1 ether, user, burned, block.timestamp), burned);
        assertEq(token1.balanceOf(user) - beforeOut, 1 ether);
        assertEq(beforeLp - IERC20(hook).balanceOf(user), burned);
    }
}
