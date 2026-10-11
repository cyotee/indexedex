// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

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

    function _projectedQuote(address target) internal view returns (bool, bytes memory) {
        return target.staticcall(abi.encodeWithSignature(
            "previewSwapAfterExchange(address,address,address,uint256)",
            se0, address(token0), address(token1), uint256(1 ether)
        ));
    }

    function _fundProjectionShares() internal {
        token0.mint(address(this), 10 ether);
        token0.approve(se0, 10 ether);
        assertGt(IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), 10 ether, IERC20(se0), 0,
            address(this), false, block.timestamp
        ), 1 ether, "external caller owns shares used by the composed quote");
    }

    function test_recurrence_D41_projectionFallbackProbeMatrix() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Zero, 0);
        _bind(rp);
        address target = hook;
        _fundProjectionShares();
        uint256 baselineQuote;
        for (uint256 mode; mode <= uint256(ApexD41RateProviderFixture.ProbeKind.DecodeFalse); ++mode) {
            if (mode == uint256(ApexD41RateProviderFixture.ProbeKind.DecodeTrue)) continue;
            rp.setProbe(ApexD41RateProviderFixture.ProbeKind(mode));
            (bool ok, bytes memory result) = _projectedQuote(target);
            assertTrue(ok, "real hook projection accepts getRate fallback");
            uint256 output = abi.decode(result, (uint256));
            assertGt(output, 0, "funded composed route reaches projection");
            if (baselineQuote == 0) baselineQuote = output;
            else assertEq(output, baselineQuote, "fallback probe shape does not change quote");
        }
        vm.expectCall(address(rp), abi.encodeWithSelector(
            bytes4(keccak256("quoteRate(address,address,bytes)"))
        ), uint64(0));
        (bool finalOk,) = _projectedQuote(target);
        assertTrue(finalOk);
    }

    function test_recurrence_D41_projectionUsesQuoteRateAndFailsClosed() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        _bind(rp);
        address target = hook;
        _fundProjectionShares();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        (bool ok, bytes memory result) = _projectedQuote(target);
        assertTrue(ok, "valid projected provider control");
        assertGt(abi.decode(result, (uint256)), 0);
        for (uint256 mode = 1; mode <= uint256(ApexD41RateProviderFixture.RateKind.Zero); ++mode) {
            rp.setQuoteRate(ApexD41RateProviderFixture.RateKind(mode), 1e18);
            (ok, result) = _projectedQuote(target);
            assertFalse(ok, "selected quoteRate failure cannot use valid live rate");
            assertEq(result, abi.encodeWithSignature("RateProviderFailed()"), "exact projected-rate boundary");
        }
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        vm.expectCall(address(rp), abi.encodeWithSelector(
            bytes4(keccak256("quoteRate(address,address,bytes)")), se0, address(token0)
        ), uint64(1));
        (ok, result) = _projectedQuote(target);
        assertTrue(ok, "restoring the selected dependency restores the same route");
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
