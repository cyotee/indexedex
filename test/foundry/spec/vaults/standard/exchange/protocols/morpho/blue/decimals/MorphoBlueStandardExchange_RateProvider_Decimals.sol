// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    StandardExchangeRateProvider_FactoryService
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice RP0–RP3 on a non-18 loan token. Quote sample is min(1e18, totalSupply).
abstract contract MorphoBlueStandardExchange_RateProvider_Decimals is
    TestBase_MorphoBlueStandardExchange_Decimals
{
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    IRateProvider internal rp;

    function setUp() public virtual override {
        super.setUp();
        IFacet rpFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        IStandardExchangeRateProviderDFPkg rpPkg = create3Factory.deployStandardExchangeRateProviderDFPkg(
            rpFacet, diamondPackageFactory
        );
        rp = rpPkg.deployRateProvider(
            IStandardExchange(se), IERC20(address(0)), IERC20(address(loanToken))
        );
    }

    function _quoteShares() internal view returns (uint256) {
        uint256 supply = IERC20(se).totalSupply();
        if (supply == 0) return 0;
        return supply < 1 ether ? supply : 1 ether;
    }

    function test_RP0_emptySe_getRateZero() public view {
        assertEq(rp.getRate(), 0, "RP0 empty");
    }

    function _rateFromPreview(uint256 sample, uint256 quote) internal view returns (uint256) {
        uint256 wad = (quote * 1 ether) / sample;
        uint8 d = _loanDecimals();
        if (d < 18) return wad * (10 ** (18 - d));
        if (d > 18) return wad / (10 ** (d - 18));
        return wad;
    }

    function test_RP1_afterDeposit_getRateMatchesPreviewScaling() public {
        _wrapExactIn(user, _u(100));
        uint256 rate = rp.getRate();
        assertGt(rate, 0, "RP1 rate > 0");
        uint256 sample = _quoteShares();
        uint256 quote = seIn.previewExchangeIn(IERC20(se), sample, IERC20(address(loanToken)));
        assertApproxEqAbs(rate, _rateFromPreview(sample, quote), 1, "RP1 getRate vs scaled preview");
    }

    function test_RP2_afterInterestWarp_getRateRisesWithConvertToAssets() public {
        _wrapExactIn(user, _u(1_000));
        uint256 rateBefore = rp.getRate();
        uint256 sample = _quoteShares();
        uint256 convBefore = se4626.convertToAssets(sample);
        _borrowFromMarket(2_000 ether, _u(500));
        vm.warp(block.timestamp + 365 days);
        uint256 rateAfter = rp.getRate();
        uint256 convAfter = se4626.convertToAssets(sample);
        assertGt(convAfter, convBefore, "RP2 convertToAssets rises");
        assertGt(rateAfter, rateBefore, "RP2 getRate rises");
    }

    function test_RP3_providerSourceUnmodified_quotesThisVaultNav() public {
        _wrapExactIn(user, _u(50));
        uint256 rate = rp.getRate();
        uint256 sample = _quoteShares();
        uint256 preview = seIn.previewExchangeIn(IERC20(se), sample, IERC20(address(loanToken)));
        assertGt(rate, 0);
        assertApproxEqAbs(rate, _rateFromPreview(sample, preview), 1, "RP3 vault preview/NAV");
    }
}
