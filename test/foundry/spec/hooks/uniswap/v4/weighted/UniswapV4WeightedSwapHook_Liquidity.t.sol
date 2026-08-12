// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

contract UniswapV4WeightedSwapHook_Liquidity_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_L1_firstMintFull_minOnAddress0() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256 shares = _joinFullN2(hook, t0, t1, 1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), Math.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertTrue(IUniswapV4WeightedSwapHook(hook).isFullBook());
        assertEq(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0)), _raw(t0, 1000));
        assertEq(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t1)), _raw(t1, 1000));
    }

    function test_L2_propJoinExit_previewEqExec() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        (uint256 prevShares, uint256[] memory prevUsed) =
            IUniswapV4WeightedSwapHook(hook).previewJoinProportional(amounts);

        vm.prank(user);
        (uint256 shares, uint256[] memory used) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prevShares);
        assertEq(used[0], prevUsed[0]);
        assertEq(used[1], prevUsed[1]);

        uint256 exitShares = shares / 2;
        uint256[] memory prevExit = IUniswapV4WeightedSwapHook(hook).previewExitProportional(exitShares);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        uint256[] memory exited = IUniswapV4WeightedSwapHook(hook).exitProportional(
            exitShares, user, mins, block.timestamp + 1 hours
        );
        assertEq(exited[0], prevExit[0]);
        assertEq(exited[1], prevExit[1]);
    }

    function test_L3_deadlineExpired() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp - 1, ""
        );
    }

    function test_L4_exitBurnsMsgSenderOnly() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256 shares = _joinFullN2(hook, t0, t1, 1000);
        address other = address(0xCAFE);
        // transfer LP to other
        vm.prank(user);
        IERC20(hook).transfer(other, shares);
        uint256[] memory mins = new uint256[](2);
        // user has 0 LP — cannot exit
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).exitProportional(
            shares / 2, user, mins, block.timestamp + 1 hours
        );
        // other can exit
        vm.prank(other);
        IUniswapV4WeightedSwapHook(hook).exitProportional(
            shares / 2, other, mins, block.timestamp + 1 hours
        );
    }

    function test_L5_wouldZeroReserve_fullExitBlocked() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256 shares = _joinFullN2(hook, t0, t1, 1000);
        // try exit almost all user shares leaving only MIN on dead — may zero a leg depending on ratio
        uint256[] memory mins = new uint256[](2);
        // exit all user shares
        vm.prank(user);
        // With only MIN left, proportional exit of all user shares should leave dust; D67 if any leg would zero
        // If exit would leave reserves with MIN only, legs may still be positive
        uint256[] memory amounts = IUniswapV4WeightedSwapHook(hook).previewExitProportional(shares);
        // if amounts would zero, expect revert
        bool wouldZero = amounts[0] >= IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0))
            || amounts[1] >= IUniswapV4WeightedSwapHook(hook).reserveOf(address(t1));
        if (wouldZero) {
            vm.prank(user);
            vm.expectRevert();
            IUniswapV4WeightedSwapHook(hook).exitProportional(
                shares, user, mins, block.timestamp + 1 hours
            );
        } else {
            vm.prank(user);
            IUniswapV4WeightedSwapHook(hook).exitProportional(
                shares, user, mins, block.timestamp + 1 hours
            );
            // residual with MIN liquidity still full book preferred
            assertGt(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0)), 0);
            assertGt(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t1)), 0);
        }
    }

    function test_L6_unbalancedJoin_fullBook() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 50);
        amounts[1] = _raw(t1, 10); // unbalanced
        uint256 prev = IUniswapV4WeightedSwapHook(hook).previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 shares = IUniswapV4WeightedSwapHook(hook).joinUnbalanced(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prev);
        assertGt(shares, 0);
    }

    function test_L7_singleAssetJoinExit() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 10_000);
        uint256 amountIn = _raw(t0, 50);
        uint256 prevShares =
            IUniswapV4WeightedSwapHook(hook).previewJoinSingleAssetExactIn(address(t0), amountIn);
        vm.prank(user);
        uint256 shares = IUniswapV4WeightedSwapHook(hook).joinSingleAssetExactIn(
            address(t0), amountIn, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prevShares);

        uint256 prevOut =
            IUniswapV4WeightedSwapHook(hook).previewExitSingleAssetExactIn(address(t1), shares / 2);
        vm.prank(user);
        uint256 out = IUniswapV4WeightedSwapHook(hook).exitSingleAssetExactIn(
            address(t1), shares / 2, user, 0, block.timestamp + 1 hours
        );
        assertEq(out, prevOut);
    }
}
