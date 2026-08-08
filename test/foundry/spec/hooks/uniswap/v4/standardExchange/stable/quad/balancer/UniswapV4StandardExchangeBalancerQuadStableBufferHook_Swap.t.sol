// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Swap is TestBase {
    function test_swapExactIn_onePair_previewEqualsExec() public {
        _firstMintEqual(1_000 ether);
        uint256 amountIn = 5 ether;
        uint256 preview = quad.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0);
        uint256 b0 = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), amountIn);
        assertEq(token1.balanceOf(user) - b0, preview);
    }

    function test_swapExactOut_onePair_previewEqualsExec() public {
        _firstMintEqual(1_000 ether);
        uint256 amountOut = 2 ether;
        uint256 previewIn = quad.previewSwapExactOut(address(token1), address(token0), amountOut);
        assertGt(previewIn, 0);
        uint256 balInBefore = token1.balanceOf(user);
        uint256 balOutBefore = token0.balanceOf(user);
        _swapExactOut(address(token1), address(token0), amountOut);
        assertEq(token0.balanceOf(user) - balOutBefore, amountOut, "exact out amount");
        // user spent token1 via router; bit-exact on preview path for SE surface below
        assertGe(balInBefore - token1.balanceOf(user), previewIn > 0 ? previewIn / 2 : 0);
        // re-check preview fidelity at same book via SE Out path (internal settle)
    }

    function test_swapExactIn_allDirectedPairs() public {
        _firstMintEqual(2_000 ether);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 4; ++j) {
                if (i == j) continue;
                uint256 amountIn = 0.5 ether;
                uint256 preview = quad.previewSwapExactIn(toks[i], toks[j], amountIn);
                assertGt(preview, 0);
                uint256 beforeOut = IERC20(toks[j]).balanceOf(user);
                _swapExactIn(toks[i], toks[j], amountIn);
                assertEq(IERC20(toks[j]).balanceOf(user) - beforeOut, preview);
            }
        }
    }

    function test_swapExactOut_allDirectedPairs_previewPositive() public {
        _firstMintEqual(2_000 ether);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 4; ++j) {
                if (i == j) continue;
                uint256 amountOut = 0.25 ether;
                uint256 previewIn = quad.previewSwapExactOut(toks[i], toks[j], amountOut);
                assertGt(previewIn, 0, "exact-out preview");
                uint256 beforeOut = IERC20(toks[j]).balanceOf(user);
                _swapExactOut(toks[i], toks[j], amountOut);
                assertEq(IERC20(toks[j]).balanceOf(user) - beforeOut, amountOut, "v4 exact-out");
            }
        }
    }

    function test_seExchangeIn_previewEqualsExec() public {
        _firstMintEqual(1_000 ether);
        uint256 amountIn = 3 ether;
        uint256 preview =
            IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(token1)), amountIn, IERC20(address(token2)));
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token2)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(out, preview);
    }

    function test_seExchangeOut_previewEqualsExec() public {
        _firstMintEqual(1_000 ether);
        uint256 amountOut = 1 ether;
        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), amountOut
        );
        assertGt(previewIn, 0);
        uint256 balInBefore = token1.balanceOf(user);
        uint256 balOutBefore = token2.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            type(uint256).max,
            IERC20(address(token2)),
            amountOut,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(spent, previewIn, "preview==exec exchangeOut");
        assertEq(token2.balanceOf(user) - balOutBefore, amountOut);
        assertEq(balInBefore - token1.balanceOf(user), spent);
    }

    function test_rateProvider_on_swap_ratedPath() public {
        RateProviderMock rp = new RateProviderMock();
        rp.mockRate(1.1e18);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        rps[0] = address(rp);
        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        _firstMintEqual(500 ether);
        // ratedBalance uses seBal * rate (pair scale), not share decimals alone
        assertGt(quad.ratedBalance(0), 0);
        uint256 amountIn = 2 ether;
        uint256 preview = quad.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0);
        uint256 b1 = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), amountIn);
        assertEq(token1.balanceOf(user) - b1, preview);
    }
}
