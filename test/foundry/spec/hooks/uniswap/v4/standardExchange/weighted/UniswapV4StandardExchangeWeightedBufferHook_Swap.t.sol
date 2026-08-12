// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

/**
 * @notice H7–H8: V4 exact-in/out, SE In/Out, RP rated, gross buffer on SE in.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Swap is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_swapExactIn_v4Door_afterFirstMint() public {
        _firstMintEqual(100 ether);
        uint256 amountIn = 1 ether;
        uint256 preview = weighted.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0, "preview out");

        uint256 bal1Before = token1.balanceOf(user);
        uint256 seBefore = weighted.seBalance(0);
        _swapExactIn(address(token0), address(token1), amountIn);
        uint256 got = token1.balanceOf(user) - bal1Before;
        assertGt(got, 0, "swap delivered");
        assertApproxEqAbs(got, preview, 10, "swap out ~ preview");
        // Gross buffer SE in: live SE shares increase after token0 (SE leg) exact-in
        assertGt(weighted.seBalance(0), seBefore, "gross SE buffer on tokenIn");
    }

    function test_swapExactOut_previewAndSeExec() public {
        _firstMintEqual(500 ether);
        uint256 amountOut = 0.1 ether;
        // V4-rated exact-out quote is live and finite
        uint256 previewInV4 = weighted.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(previewInV4, 0, "V4 exact-out quote");

        // Exact-out execution with bit-exact preview==exec on SE surface (same rated book)
        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(token1)), amountOut
        );
        assertGt(previewIn, 0);
        // Same composition as V4 doors (may differ by wei on buffer map — require close)
        assertApproxEqAbs(previewIn, previewInV4, previewInV4 / 100 + 10, "SE vs V4 quote");

        uint256 bal0Before = token0.balanceOf(user);
        uint256 bal1Before = token1.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            type(uint256).max,
            IERC20(address(token1)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn, "exact-out exec==preview");
        assertEq(bal0Before - token0.balanceOf(user), spent);
        assertEq(token1.balanceOf(user) - bal1Before, amountOut);
    }

    function test_seExchangeIn_previewEqualsExec() public {
        _firstMintEqual(100 ether);
        uint256 amountIn = 1 ether;
        uint256 preview =
            weighted.previewSwapExactIn(address(token1), address(token0), amountIn);
        assertGt(preview, 0);

        uint256 bal0 = token0.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token0)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview, "SE In preview==exec");
        assertEq(token0.balanceOf(user) - bal0, out);
    }

    function test_seExchangeOut_previewEqualsExec() public {
        _firstMintEqual(200 ether);
        uint256 amountOut = 0.25 ether;
        uint256 previewIn =
            IStandardExchangeOut(hook).previewExchangeOut(
                IERC20(address(token1)), IERC20(address(token0)), amountOut
            );
        assertGt(previewIn, 0);

        uint256 bal1 = token1.balanceOf(user);
        uint256 bal0 = token0.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            type(uint256).max,
            IERC20(address(token0)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn, "SE Out preview==exec");
        assertEq(bal1 - token1.balanceOf(user), spent);
        assertEq(token0.balanceOf(user) - bal0, amountOut);
    }

    function test_ratedSwap_withRateProvider() public {
        RateProviderMock rp = new RateProviderMock();
        rp.mockRate(1.1e18);

        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        address[] memory rps = new address[](2);
        rps[0] = address(rp);
        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));
        _fundAndApprove(token0);
        _fundAndApprove(token1);

        assertEq(weighted.rateProvider(0), address(rp));
        _firstMintEqual(100 ether);

        // Rated balances use seBal * rate (not raw claim alone)
        uint256 rated0 = weighted.ratedBalance(0);
        assertGt(rated0, 0);

        uint256 amountIn = 1 ether;
        uint256 preview = weighted.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0);
        uint256 bal1 = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), amountIn);
        assertGt(token1.balanceOf(user) - bal1, 0);
    }

    function test_rateProvider_failClosed_onZeroRate() public {
        RateProviderMock rp = new RateProviderMock();
        rp.mockRate(1e18);

        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        address[] memory rps = new address[](2);
        rps[0] = address(rp);
        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _firstMintEqual(50 ether);

        rp.mockRate(0); // fail-closed
        vm.expectRevert();
        weighted.ratedBalance(0);
        vm.expectRevert();
        weighted.previewSwapExactIn(address(token0), address(token1), 1 ether);
    }
}
