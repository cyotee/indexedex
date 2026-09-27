// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4SeBufferHookLegLib as LegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {ApexD41RateProviderFixture} from "contracts/test/stubs/ApexD41RateProviderFixture.sol";

/// @notice D41 staticcall matrix against `rateAfterExchange` (SUT library).
contract UniswapV4SeBufferHookLegLib_APEX_D41 is Test {
    ApexD41RateProviderFixture internal rp;
    address internal pair = address(0xBEEF);

    function setUp() public {
        rp = new ApexD41RateProviderFixture();
    }

    function _quote() internal view returns (uint256) {
        LegLib.ExternalQuote memory q;
        return LegLib.rateAfterExchange(q, pair, address(rp));
    }

    function test_APEX_D41_getRateOnly_noErc165_quotesGetRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Revert);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1.5e18);
        assertEq(_quote(), 1.5e18);
    }

    function test_APEX_D41_probeEmpty_selectsGetRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Empty);
        assertEq(_quote(), 1e18);
    }

    function test_APEX_D41_probeShort_selectsGetRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Short);
        assertEq(_quote(), 1e18);
    }

    function test_APEX_D41_probeOverlong_selectsGetRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Overlong);
        assertEq(_quote(), 1e18);
    }

    function test_APEX_D41_probeFalse_selectsGetRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeFalse);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 3e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 9e18);
        assertEq(_quote(), 3e18);
    }

    function test_APEX_D41_probeTrue_selectsQuoteRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 3e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 9e18);
        assertEq(_quote(), 9e18);
    }

    function test_APEX_D41_getRate_revert_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeFalse);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Revert, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_getRate_empty_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeFalse);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Empty, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_getRate_short_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeFalse);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Short, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_getRate_overlong_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeFalse);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Overlong, 1e18);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_getRate_zero_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeFalse);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Zero, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_quoteRate_revert_neverFallsBackToGetRate() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Revert, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_quoteRate_empty_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Empty, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_quoteRate_short_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Short, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_quoteRate_overlong_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Overlong, 2e18);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_quoteRate_zero_RateProviderFailed() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Zero, 0);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        _quote();
    }

    function test_APEX_D41_quoteRate_positive() public {
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 7e17);
        assertEq(_quote(), 7e17);
    }
}
