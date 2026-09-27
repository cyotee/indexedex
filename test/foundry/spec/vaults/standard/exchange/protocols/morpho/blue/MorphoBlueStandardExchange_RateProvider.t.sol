// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
 * @notice RP0–RP3: existing StandardExchangeRateProvider DFPkg via diamondPackageFactory. Do not edit provider source.
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

    function test_RP0_emptySe_getRateInitialMint() public view {
        // D60 (2026-09-22): an empty SE publishes its initial mint rate (one whole share per whole target token
        // at first mint, scaled to 18 decimals of the target) instead of 0, so hooks can price a first buffer.
        assertEq(rp.getRate(), 10 ** (36 - uint256(IERC20Metadata(address(loanToken)).decimals())), "RP0 empty: initial mint rate");
    }

    function test_RP1_afterDeposit_getRateMatchesPreviewScaling() public {
        _wrapExactIn(user, 100 ether);
        uint256 rate = rp.getRate();
        assertGt(rate, 0, "RP1 rate > 0");
        uint256 quote = seIn.previewExchangeIn(IERC20(se), 1 ether, IERC20(address(loanToken)));
        assertApproxEqAbs(rate, quote, 1, "RP1 getRate vs previewExchangeIn 1e18 shares");
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
        uint256 preview = seIn.previewExchangeIn(IERC20(se), 1 ether, IERC20(address(loanToken)));
        assertGt(rate, 0);
        assertApproxEqAbs(rate, preview, 1, "RP3 vault preview/NAV");
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

    function test_APEX_D48_halveSearch_recoversWhenLargeQuoteReverts() public {
        ApexD48QuoteReplyFixture fx = new ApexD48QuoteReplyFixture();
        fx.setFailAbove(5e17);
        fx.setReply(ApexD48QuoteReplyFixture.Reply.Ok32, 5e17);
        IRateProvider rpFx = _deployFixtureProvider(fx);
        uint256 rate = rpFx.getRate();
        assertGt(rate, 0, "halved quote recovers");
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
}
