// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Liquidity is TestBase {
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

    function test_depositSingle_withdrawSingle_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256 pShares = quad.previewDepositSingle(address(token1), 20 ether);
        vm.prank(user);
        uint256 shares = quad.depositSingle(address(token1), 20 ether, user, 0, block.timestamp + 1);
        assertEq(shares, pShares);
        assertGt(shares, 0);

        uint256 pOut = quad.previewWithdrawSingle(address(token1), shares);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(address(token1), shares, user, 0, block.timestamp + 1);
        assertEq(out, pOut);
        assertGt(out, 0);
    }

    /// @notice B6: buffered leg accepts SE vault share on deposit and withdraw (no unwrap required).
    function test_B6_depositWithdraw_seShareUnits() public {
        _firstMintEqual(500 ether);

        // User mints SE shares for leg 0 off-hook, then LPs with SE shares.
        token0.mint(user, 100 ether);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seShares = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), 50 ether, IERC20(se0), 0, user, false, block.timestamp + 1
        );
        assertGt(seShares, 0);
        IERC20(se0).approve(hook, type(uint256).max);

        uint256 half = seShares / 2;
        uint256 pShares = quad.previewDepositSingle(se0, half);
        uint256 shares = quad.depositSingle(se0, half, user, 0, block.timestamp + 1);
        assertEq(shares, pShares);
        assertGt(shares, 0);

        uint256 seBalBefore = IERC20(se0).balanceOf(user);
        uint256 pOut = quad.previewWithdrawSingle(se0, shares);
        uint256 out = quad.withdrawSingle(se0, shares, user, 0, block.timestamp + 1);
        assertEq(out, pOut);
        assertGt(out, 0);
        assertEq(IERC20(se0).balanceOf(user), seBalBefore + out);
        vm.stopPrank();
    }

    /// @notice B6: same buffered leg also accepts pair token units (existing path).
    function test_B6_depositWithdraw_pairUnits_bufferedLeg() public {
        _firstMintEqual(500 ether);
        uint256 pShares = quad.previewDepositSingle(address(token0), 20 ether);
        vm.prank(user);
        uint256 shares = quad.depositSingle(address(token0), 20 ether, user, 0, block.timestamp + 1);
        assertEq(shares, pShares);
        assertGt(shares, 0);

        uint256 pOut = quad.previewWithdrawSingle(address(token0), shares);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(address(token0), shares, user, 0, block.timestamp + 1);
        assertEq(out, pOut);
        assertGt(out, 0);
    }

    function test_invalidRoute_omitPaths() public {
        _firstMintEqual(200 ether);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.previewJoinUnbalanced(new uint256[](4));
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.joinUnbalanced(new uint256[](4), user, 0, block.timestamp + 1);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.previewJoinSingleAssetExactOut(address(token1), 1e18);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.joinSingleAssetExactOut(address(token1), 1e18, user, type(uint256).max, block.timestamp + 1);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.previewExitSingleAssetExactTokenOut(address(token1), 1e18);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.exitSingleAssetExactTokenOut(address(token1), 1e18, user, type(uint256).max, block.timestamp + 1);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.previewWithdrawSingleExactOut(address(token1), 1e18);
        vm.expectRevert(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.InvalidRoute.selector);
        quad.withdrawSingleExactOut(address(token1), 1e18, user, type(uint256).max, block.timestamp + 1);
    }
}
