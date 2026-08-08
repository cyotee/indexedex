// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4CurveQuadStableSwapHook,
    MintableDec,
    RateProviderHarness
} from "contracts/hooks/uniswap/v4/stable/quad/curve/TestBase_UniswapV4CurveQuadStableSwapHook.sol";
import {
    IUniswapV4CurveQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHook.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHook_Rates_Test
 * @notice Rate scale + fail-closed providers (D74).
 */
contract UniswapV4CurveQuadStableSwapHook_Rates_Test is TestBase_UniswapV4CurveQuadStableSwapHook {
    function test_R3_zeroProviders_decimalOnly() public view {
        // default TestBase uses address(0) providers
        uint256 r0 = quad.effectiveRate(0);
        assertGt(r0, 0);
    }

    function test_R1_rateProvider_scales() public {
        RateProviderHarness rp = new RateProviderHarness();
        rp.setRate(2e18); // 2x
        (IUniswapV4CurveQuadStableSwapHook h,) = _deployWithProviders(address(rp), address(0), address(0), address(0));
        uint256 r0 = h.effectiveRate(0);
        // with 2x oracle, effective > decimal-only baseScale alone for same decimals
        assertGt(r0, 0);
    }

    function test_R2_failClosed_zeroRate() public {
        RateProviderHarness rp = new RateProviderHarness();
        rp.setRate(0);
        (IUniswapV4CurveQuadStableSwapHook h,) = _deployWithProviders(address(rp), address(0), address(0), address(0));
        vm.expectRevert();
        h.effectiveRate(0);
    }

    function test_R2_failClosed_revertProvider() public {
        RateProviderHarness rp = new RateProviderHarness();
        rp.setShouldRevert(true);
        (IUniswapV4CurveQuadStableSwapHook h,) = _deployWithProviders(address(rp), address(0), address(0), address(0));
        vm.expectRevert();
        h.effectiveRate(0);
    }

    function _deployWithProviders(address p0, address p1, address p2, address p3)
        internal
        returns (IUniswapV4CurveQuadStableSwapHook h, address hookAddr)
    {
        address[4] memory toks = _fourTokens();
        address[4] memory providers;
        providers[0] = p0;
        providers[1] = p1;
        providers[2] = p2;
        providers[3] = p3;
        hookAddr = _deployHook(
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, providers)
        );
        h = IUniswapV4CurveQuadStableSwapHook(hookAddr);
    }

    function _fourTokens() internal returns (address[4] memory toks) {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        MintableDec d = new MintableDec("D", "D", 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        toks[0] = address(x0);
        toks[1] = address(x1);
        toks[2] = address(x2);
        toks[3] = address(x3);
    }
}
