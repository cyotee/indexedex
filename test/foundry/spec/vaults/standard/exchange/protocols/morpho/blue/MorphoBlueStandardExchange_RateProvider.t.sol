// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from
    "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ApexD48QuoteReplyFixture} from "contracts/test/stubs/ApexD48QuoteReplyFixture.sol";
import {
    StandardExchangeRateProvider_FactoryService
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/**
 * @title MorphoBlueStandardExchange_RateProvider
 * @notice RP0–RP3: whole-supply StandardExchangeRateProvider DFPkg via diamondPackageFactory.
 */
contract MorphoBlueStandardExchange_RateProvider is TestBase_MorphoBlueStandardExchange {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    IRateProvider internal rp;

    function setUp() public override {
        super.setUp();
        IFacet rpFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        IStandardExchangeRateProviderDFPkg rpPkg = create3Factory.deployStandardExchangeRateProviderDFPkg(
            rpFacet, diamondPackageFactory
        );
        rp = rpPkg.deployRateProvider(
            IStandardExchange(se), IERC20(address(0)), IERC20(address(loanToken))
        );
    }

function _expectFixtureQuote(ApexD48QuoteReplyFixture fx, uint256 amount) internal {
        vm.expectCall(address(fx), abi.encodeWithSignature(
            "previewExchangeIn(address,uint256,address)", address(fx), amount, address(loanToken)
        ), uint64(1));
    }

    function test_recurrence_D48_fullSupplyFailureDoesNotSample() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setFailAbove(25e16);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 5e17);
        IRateProvider provider = _deployFixtureProvider(fx);
        _expectFixtureQuote(fx, fx.totalSupply());
        assertEq(provider.getRate(), 0, "a smaller payable quote cannot replace the whole book");
    }

    function test_recurrence_D48_failureAttemptsFullSupplyOnce() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.RevertCustom, 0);
        IRateProvider provider = _deployFixtureProvider(fx);
        _expectFixtureQuote(fx, fx.totalSupply());
        vm.expectCall(address(fx), abi.encodeWithSignature("previewExchangeIn(address,uint256,address)"), uint64(1));
        assertEq(provider.getRate(), 0);
    }

    function test_recurrence_D48_zeroQuoteScalesUpAndRecovers() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setSupply(100e18, 18);
        fx.setZeroBelow(100e18);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 200e18);
        IRateProvider provider = _deployFixtureProvider(fx);
        _expectFixtureQuote(fx, 100e18);
        assertEq(provider.getRate(), 2e18);
    }

    function test_recurrence_D48_fullSupplyFailureDoesNotRetryZeroSample() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setSupply(100e18, 18);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 0);
        fx.setFailAbove(1e18);
        IRateProvider provider = _deployFixtureProvider(fx);
        _expectFixtureQuote(fx, 100e18);
        vm.expectCall(address(fx), abi.encodeWithSignature("previewExchangeIn(address,uint256,address)"), uint64(1));
        assertEq(provider.getRate(), 0);
    }

    function test_recurrence_D48_projectedPayloadMatrix() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        IRateProvider provider = _deployFixtureProvider(fx);
        for (uint256 mode = 1; mode <= uint256(ApexD48QuoteReplyFixture.Reply.MalformedRevert); ++mode) {
            fx.setReply(ApexD48QuoteReplyFixture.Reply(mode), 1e18);
            assertEq(IStandardExchangeRateQuote(address(provider)).quoteRate(
                address(fx), address(loanToken), hex"01"
            ), 0, "all invalid projected quote payloads fail soft");
        }
    }

    function test_recurrence_D48_supplyAndDecimalsFailuresRemainHard() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        IRateProvider provider = _deployFixtureProvider(fx);
        fx.setMetadataFailures(true, false);
        vm.expectRevert(ApexD48QuoteReplyFixture.QuoteBoom.selector);
        provider.getRate();
        fx.setMetadataFailures(false, true);
        vm.expectRevert(ApexD48QuoteReplyFixture.QuoteBoom.selector);
        provider.getRate();
    }

    function test_recurrence_D48_unrelatedProjectionUsesLiveContext() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 2e18);
        fx.setSnapshotSupplyReverts(true);
        IRateProvider provider = _deployFixtureProvider(fx);
        assertEq(IStandardExchangeRateQuote(address(provider)).quoteRate(
            address(0xBEEF), address(loanToken), hex"01"
        ), 2e18);
        assertEq(IStandardExchangeRateQuote(address(provider)).quoteRate(
            address(fx), address(0xBEEF), hex"01"
        ), 2e18);
    }

    function test_RP0_emptySe_getRateInitialMint() public view {
        // D60 (2026-09-22): an empty SE publishes its initial mint rate (one whole share per whole target token
        // at first mint, scaled to 18 decimals of the target) instead of 0, so hooks can price a first buffer.
        assertEq(rp.getRate(), 10 ** (36 - uint256(IERC20Metadata(address(loanToken)).decimals())), "RP0 empty: initial mint rate");
    }

    function test_RP1_afterDeposit_getRateMatchesPreviewScaling() public {
        _wrapExactIn(user, 100 ether);
        uint256 rate = rp.getRate();
        assertGt(rate, 0, "RP1 rate > 0");
        uint256 supply = IERC20(se).totalSupply();
        uint256 quote = seIn.previewExchangeIn(IERC20(se), supply, IERC20(address(loanToken)));
        uint256 scale = 10 ** (18 + uint256(IERC20Metadata(se).decimals()) - loanToken.decimals());
        assertEq(rate, Math.mulDiv(quote, scale, supply, Math.Rounding.Ceil), "RP1 whole-book rate");
    }

    function test_RP2_afterInterestWarp_getRateRisesWithConvertToAssets() public {
        _wrapExactIn(user, 1_000 ether);
        uint256 rateBefore = rp.getRate();
        uint256 convBefore = se4626.convertToAssets(1 ether);
        _borrowFromMarket(2_000 ether, 500 ether);
        vm.warp(block.timestamp + 365 days);
        uint256 rateAfter = rp.getRate();
        uint256 convAfter = se4626.convertToAssets(1 ether);
        assertGt(convAfter, convBefore, "RP2 convertToAssets rises");
        assertGt(rateAfter, rateBefore, "RP2 getRate rises");
    }

    function test_RP3_providerSourceUnmodified_quotesThisVaultNav() public {
        _wrapExactIn(user, 50 ether);
        uint256 rate = rp.getRate();
        uint256 supply = IERC20(se).totalSupply();
        uint256 preview = seIn.previewExchangeIn(IERC20(se), supply, IERC20(address(loanToken)));
        uint256 scale = 10 ** (18 + uint256(IERC20Metadata(se).decimals()) - loanToken.decimals());
        assertGt(rate, 0);
        assertEq(rate, Math.mulDiv(preview, scale, supply, Math.Rounding.Ceil), "RP3 whole-book NAV");
    }

    /// @notice A one-unit share supply still has a whole-book rate.
    function test_fullSupplyRateIncludesSingleNativeShare() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setSupply(1, 18);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 3);
        IRateProvider provider = _deployFixtureProvider(fx);
        _expectFixtureQuote(fx, 1);
        assertEq(provider.getRate(), 3e18);
    }

    /// @notice The final per-share division rounds once after valuing the full book.
    function test_fullSupplyRateRoundsOnlyAfterValuation() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setSupply(3e18, 18);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 10);
        IRateProvider provider = _deployFixtureProvider(fx);
        _expectFixtureQuote(fx, 3e18);
        assertEq(provider.getRate(), 4);
    }

    function _deployFixtureProvider(ApexD48QuoteReplyFixture fx)
        internal
        returns (IRateProvider)
    {
        IFacet rpFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        IStandardExchangeRateProviderDFPkg rpPkg =
            create3Factory.deployStandardExchangeRateProviderDFPkg(rpFacet, diamondPackageFactory);
        return rpPkg.deployRateProvider(
            IStandardExchange(address(fx)), IERC20(address(0)), IERC20(address(loanToken))
        );
    }

    function test_APEX_D48_fullSupplyRevertReturnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setFailAbove(5e17);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 5e17);
        assertEq(_deployFixtureProvider(fx).getRate(), 0, "unavailable whole-book rate");
    }

    function test_APEX_D48_customRevert_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.RevertCustom, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_revertString_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.RevertString, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_panic_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Panic, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_emptyRevert_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.EmptyRevert, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_okEmpty_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.OkEmpty, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_okShort_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.OkShort, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_okOverlong_returnsZero() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.OkOverlong, 1e18);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_ok32_zeroThenScaleUp() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 0);
        assertEq(_deployFixtureProvider(fx).getRate(), 0);
    }

    function test_APEX_D48_quoteRate_nonemptyState_usesQuoteAssets() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 2e18);
        IRateProvider rpFx = _deployFixtureProvider(fx);
        uint256 quoted = IStandardExchangeRateQuote(address(rpFx)).quoteRate(
            address(fx), address(loanToken), hex"01"
        );
        assertEq(quoted, 2e18);
    }

    function test_emptyGetRate_ignoresQuoteStateFailure() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setQuoteStateReverts(true);
        fx.setSupply(0, 18);
        IRateProvider provider = _deployFixtureProvider(fx);
        uint256 live = provider.getRate();
        (bool ok, bytes memory data) = address(provider).staticcall{gas: 120_000}(
            abi.encodeCall(IRateProvider.getRate, ())
        );
        assertTrue(ok, "empty rate does not spend its budget on quoteState");
        assertEq(abi.decode(data, (uint256)), live, "low budget returns the same live rate");
    }

    function test_failedCallerSnapshot_isNotReportedAsLiveRate() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 2e18);
        fx.setSnapshotSupplyReverts(true);
        IRateProvider provider = _deployFixtureProvider(fx);
        uint256 live = provider.getRate();
        vm.expectRevert(ApexD48QuoteReplyFixture.QuoteBoom.selector);
        IStandardExchangeRateQuote(address(provider)).quoteRate(address(fx), address(loanToken), hex"01");
        assertEq(provider.getRate(), live, "failed snapshot is not replaced with the live rate");
    }
}
