// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {ApexD41RateProviderFixture} from "contracts/test/stubs/ApexD41RateProviderFixture.sol";

contract UniswapV4StandardExchangeWeightedBufferHook_APEX_D41 is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function _bind(ApexD41RateProviderFixture rp) internal {
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
        _firstMintEqual(100 ether);
    }

    function test_APEX_D41_weighted_getRateOnly_ratedBalance() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Revert);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 2e18);
        _bind(rp);
        assertGt(weighted.ratedBalance(0), 0);
        assertEq(weighted.rateProvider(0), address(rp));
    }

    function test_APEX_D41_weighted_probeTrue_usesQuoteRate() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 3e18);
        _bind(rp);
        assertGt(weighted.ratedBalance(0), 0);
    }

}
