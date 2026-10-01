// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {ApexD41RateProviderFixture} from "contracts/test/stubs/ApexD41RateProviderFixture.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHook_APEX_D41 is TestBase {
    function _bind(ApexD41RateProviderFixture rp) internal {
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
        _firstMintEqual(100 ether);
    }

    function test_APEX_D41_curve_getRateOnly_ratedBalance() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Revert);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 2e18);
        _bind(rp);
        assertGt(quad.ratedBalance(0), 0);
        assertEq(quad.rateProvider(0), address(rp));
    }

    function test_APEX_D41_curve_probeTrue_usesQuoteRate() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 3e18);
        _bind(rp);
        assertGt(quad.ratedBalance(0), 0);
    }

}
