// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @notice H5–H6 full-book LP: prop / unbalanced / single / aliases / D42a.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Liquidity is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_firstMint_fullBook_inventoryBook() public {
        uint256 amount = 100 ether;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        (uint256 previewShares, uint256[] memory previewUsed) = weighted.previewJoinProportional(amounts);

        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);

        assertEq(shares, previewShares, "preview==exec shares");
        assertEq(used[0], previewUsed[0], "preview used0");
        assertEq(used[1], previewUsed[1], "preview used1");
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).totalSupply(), shares + 1000);
        assertGt(weighted.nativeReserve(0), 0, "SE book");
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "live SE shares");
        assertEq(weighted.nativeReserve(1), amount, "raw face book");
        assertTrue(weighted.isFullBook());
    }

    function test_joinUnbalanced_previewEqualsExec() public {
        _firstMintEqual(200 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 30 ether;
        uint256 preview = weighted.previewJoinUnbalanced(amounts);
        assertGt(preview, 0);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 shares = weighted.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview, "unbalanced preview==exec");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, shares);
    }

    function test_joinSingleAssetExactIn_and_alias_exec() public {
        _firstMintEqual(100 ether);
        uint256 amountIn = 10 ether;

        uint256 preview = weighted.previewJoinSingleAssetExactIn(address(token1), amountIn);
        assertEq(preview, weighted.previewDepositSingle(address(token1), amountIn), "alias preview");

        vm.prank(user);
        uint256 shares =
            weighted.joinSingleAssetExactIn(address(token1), amountIn, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview, "single join preview==exec");

        // depositSingle alias executes on live book
        uint256 previewDep = weighted.previewDepositSingle(address(token1), amountIn);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 tBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 depShares =
            weighted.depositSingle(address(token1), amountIn, user, 0, block.timestamp + 1 hours);
        assertEq(depShares, previewDep, "depositSingle preview==exec");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, depShares);
        assertEq(tBefore - token1.balanceOf(user), amountIn);
    }

    function test_joinSingleAssetExactOut_required() public {
        _firstMintEqual(100 ether);
        uint256 sharesOut = 1 ether;
        uint256 previewIn = weighted.previewJoinSingleAssetExactOut(address(token1), sharesOut);
        assertGt(previewIn, 0);

        uint256 balBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 amountIn = weighted.joinSingleAssetExactOut(
            address(token1), sharesOut, user, type(uint256).max, block.timestamp + 1 hours
        );
        assertEq(amountIn, previewIn, "exactOut join preview==exec");
        assertEq(balBefore - token1.balanceOf(user), amountIn);
        assertGe(IERC20(hook).balanceOf(user), sharesOut);
    }

    function test_exitProportional_previewEqualsExec() public {
        uint256 mintShares = _firstMintEqual(100 ether);
        uint256 burn = mintShares / 4;
        uint256[] memory preview = weighted.previewExitProportional(burn);
        uint256[] memory mins = new uint256[](2);

        uint256 bal0 = token0.balanceOf(user);
        uint256 bal1 = token1.balanceOf(user);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        assertEq(got[0], preview[0]);
        assertEq(got[1], preview[1]);
        assertEq(token0.balanceOf(user) - bal0, got[0]);
        assertEq(token1.balanceOf(user) - bal1, got[1]);
    }

    function test_exitProportional_doesNotDumpDustOnCaller() public {
        uint256 mintShares = _firstMintEqual(100 ether);
        assertLe(token0.balanceOf(hook), 10, "SE-buffered pair after deposit is dust");
        uint256[] memory mins = new uint256[](2);
        uint256 userBefore = token0.balanceOf(user);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(mintShares / 4, user, mins, block.timestamp + 1 hours);
        assertEq(token0.balanceOf(user) - userBefore, got[0], "caller not inflated by dust dump");
        assertLe(token0.balanceOf(hook), 10, "SE-buffered pair after withdraw is dust");
    }

    function test_exitSingleAssetExactTokenOut_d42a() public {
        _firstMintEqual(200 ether);
        uint256 amountOut = 5 ether;
        uint256 previewShares = weighted.previewExitSingleAssetExactTokenOut(address(token1), amountOut);
        assertGt(previewShares, 0);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 tBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 burned = weighted.exitSingleAssetExactTokenOut(
            address(token1), amountOut, user, type(uint256).max, block.timestamp + 1 hours
        );
        assertEq(burned, previewShares, "D42a preview==exec");
        assertEq(lpBefore - IERC20(hook).balanceOf(user), burned);
        assertEq(token1.balanceOf(user) - tBefore, amountOut);
    }

    function test_withdrawSingle_alias() public {
        uint256 mintShares = _firstMintEqual(100 ether);
        uint256 burn = mintShares / 10;
        uint256 preview = weighted.previewWithdrawSingle(address(token1), burn);
        vm.prank(user);
        uint256 out =
            weighted.withdrawSingle(address(token1), burn, user, 0, block.timestamp + 1 hours);
        assertEq(out, preview);
    }
}
