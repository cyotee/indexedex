// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity is TestBase {
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

    function test_joinUnbalanced_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 10 ether;
        amounts[1] = 25 ether;
        amounts[2] = 5 ether;
        amounts[3] = 15 ether;
        uint256 preview = quad.previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 shares = quad.joinUnbalanced(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, preview);
        assertGt(shares, 0);
    }

    function test_joinSingleAssetExactOut_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256 sharesOut = 1e18;
        uint256 previewIn = quad.previewJoinSingleAssetExactOut(address(token1), sharesOut);
        assertGt(previewIn, 0);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 amountIn = quad.joinSingleAssetExactOut(
            address(token1), sharesOut, user, type(uint256).max, block.timestamp + 1
        );
        assertEq(amountIn, previewIn);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, sharesOut);
    }

    function test_exitSingleAssetExactTokenOut_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256 amountOut = 3 ether;
        uint256 previewBurn = quad.previewExitSingleAssetExactTokenOut(address(token1), amountOut);
        assertGt(previewBurn, 0);
        uint256 balBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 burned = quad.exitSingleAssetExactTokenOut(
            address(token1), amountOut, user, type(uint256).max, block.timestamp + 1
        );
        assertEq(burned, previewBurn);
        assertEq(token1.balanceOf(user) - balBefore, amountOut);
    }

    function test_withdrawSingleExactOut_alias() public {
        _firstMintEqual(400 ether);
        uint256 amountOut = 2 ether;
        uint256 p = quad.previewWithdrawSingleExactOut(address(token2), amountOut);
        assertEq(p, quad.previewExitSingleAssetExactTokenOut(address(token2), amountOut));
        vm.prank(user);
        uint256 burned = quad.withdrawSingleExactOut(
            address(token2), amountOut, user, type(uint256).max, block.timestamp + 1
        );
        assertEq(burned, p);
    }
}
