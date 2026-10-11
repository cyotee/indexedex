// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

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
