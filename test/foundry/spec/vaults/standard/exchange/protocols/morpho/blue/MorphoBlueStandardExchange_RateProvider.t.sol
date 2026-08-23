// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from
    "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    StandardExchangeRateProvider_FactoryService
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
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

    function test_RP0_emptySe_getRateZero() public view {
        assertEq(rp.getRate(), 0, "RP0 empty");
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
}
