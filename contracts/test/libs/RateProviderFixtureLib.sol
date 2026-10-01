// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";

/// @title RateProviderFixtureLib
/// @notice Test-side helper for D60: every buffered hook leg needs a rate provider, so fixtures deploy the
///         production `StandardExchangeRateProvider` (one whole SE share quoted into the leg's token) per SE
///         leg. Deploys are CREATE3 / package-factory idempotent, so repeated calls return the same provider.
///         Callers must own or operate the CREATE3 factory (the test contract does; fixtures prank its owner).
library RateProviderFixtureLib {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    function providerFor(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        address se,
        address rateTarget
    ) internal returns (address) {
        if (se == address(0)) return address(0);
        // A self-share leg (the pool token is itself the SE, D41 / F16 wrapper-share inventory) is priced in
        // the wrapper's underlying asset; quoting it against itself is not a route.
        if (se == rateTarget) rateTarget = IERC4626(se).asset();
        IFacet facet = create3Factory.deployStandardExchangeRateProviderFacet();
        IStandardExchangeRateProviderDFPkg pkg =
            create3Factory.deployStandardExchangeRateProviderDFPkg(facet, diamondFactory);
        return address(pkg.deployRateProvider(IStandardExchange(se), IERC20(rateTarget)));
    }

    /// @dev Single-CP / dual buffered leg: a provider for `se` quoted in `pair`; an identity leg
    ///      (`pair == se`, wrapper-share inventory) is priced in its own units and gets none (D60).
    function providerForCp(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        address se,
        address pair
    ) internal returns (address) {
        if (se == address(0) || se == pair) return address(0);
        return providerFor(create3Factory, diamondFactory, se, pair);
    }

    /// @dev One provider per SE leg; address(0) on raw legs.
    function providersFor(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        address[] memory tokens,
        address[] memory ses
    ) internal returns (address[] memory rps) {
        rps = new address[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            rps[i] = providerFor(create3Factory, diamondFactory, ses[i], tokens[i]);
        }
    }

    /// @dev Keeps every provider the caller supplied and derives one only for an SE leg left at address(0).
    function fillMissing(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        address[] memory tokens,
        address[] memory ses,
        address[] memory supplied
    ) internal returns (address[] memory rps) {
        rps = new address[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            rps[i] = (i < supplied.length && supplied[i] != address(0))
                ? supplied[i]
                : providerFor(create3Factory, diamondFactory, ses[i], tokens[i]);
        }
    }

    function fillMissing4(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        address[4] memory tokens,
        address[4] memory ses,
        address[4] memory supplied
    ) internal returns (address[4] memory rps) {
        for (uint256 i; i < 4; ++i) {
            rps[i] = supplied[i] != address(0) ? supplied[i] : providerFor(create3Factory, diamondFactory, ses[i], tokens[i]);
        }
    }

    function providersFor4(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        address[4] memory tokens,
        address[4] memory ses
    ) internal returns (address[4] memory rps) {
        for (uint256 i; i < 4; ++i) {
            rps[i] = providerFor(create3Factory, diamondFactory, ses[i], tokens[i]);
        }
    }
}
