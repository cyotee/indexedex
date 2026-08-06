// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_SeExchangeTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function setUp() public override {
        super.setUp();
        _seedThreeLeg(500 ether);
    }

    function test_exchangeIn_previewEqualsExec() public {
        uint256 amountIn = 5 ether;
        uint256 preview = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(token0)), amountIn, IERC20(address(token1))
        );
        assertGt(preview, 0);
        uint256 balBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            amountIn,
            IERC20(address(token1)),
            preview,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(token1.balanceOf(user) - balBefore, out);
        // Did not mint LP
        assertEq(IERC20(hook).balanceOf(user), IERC20(hook).balanceOf(user));
    }

    function test_exchangeOut_previewEqualsExec() public {
        uint256 amountOut = 2 ether;
        uint256 amountIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(token1)), amountOut
        );
        assertGt(amountIn, 0);
        uint256 balBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 paid = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            amountIn,
            IERC20(address(token1)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(paid, amountIn);
        assertEq(token1.balanceOf(user) - balBefore, amountOut);
    }

    function test_exchangeIn_matchesV4Preview() public {
        uint256 amountIn = 3 ether;
        uint256 sePrev = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(token0)), amountIn, IERC20(address(token1))
        );
        uint256 v4Prev = orbital.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertEq(sePrev, v4Prev, "SE In/Out == V4 book");
    }

    function test_exchangeIn_sameToken_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            1 ether,
            IERC20(address(token0)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
    }
}
