// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/TestBase_UniswapV4StandardExchangeQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/interfaces/IUniswapV4StandardExchangeQuadStableBufferHook.sol";

contract UniswapV4StandardExchangeQuadStableBufferHook_Liquidity is TestBase {
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

    function test_invalidRoute_omitPaths() public {
        _firstMintEqual(200 ether);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.previewJoinUnbalanced(new uint256[](4));
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.joinUnbalanced(new uint256[](4), user, 0, block.timestamp + 1);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.previewJoinSingleAssetExactOut(address(token1), 1e18);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.joinSingleAssetExactOut(address(token1), 1e18, user, type(uint256).max, block.timestamp + 1);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.previewExitSingleAssetExactTokenOut(address(token1), 1e18);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.exitSingleAssetExactTokenOut(address(token1), 1e18, user, type(uint256).max, block.timestamp + 1);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.previewWithdrawSingleExactOut(address(token1), 1e18);
        vm.expectRevert(IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute.selector);
        quad.withdrawSingleExactOut(address(token1), 1e18, user, type(uint256).max, block.timestamp + 1);
    }
}
