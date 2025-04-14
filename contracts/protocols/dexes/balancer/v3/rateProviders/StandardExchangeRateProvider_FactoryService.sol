// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderFacet.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";

/**
 * @title StandardExchangeRateProvider_FactoryService
 * @notice Factory service for deploying StandardExchangeRateProvider components via CREATE3.
 * @dev Provides deterministic deployment of facets and packages.
 */
library StandardExchangeRateProvider_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployStandardExchangeRateProviderFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(StandardExchangeRateProviderFacet).creationCode,
            abi.encode(type(StandardExchangeRateProviderFacet).name)._hash()
        );
        vm.label(address(instance), type(StandardExchangeRateProviderFacet).name);
    }

    /* ---------------------------------------------------------------------- */
    /*                            Package Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployStandardExchangeRateProviderDFPkg(
        ICreate3FactoryProxy create3Factory,
        IFacet rateProviderFacet,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal returns (IStandardExchangeRateProviderDFPkg instance) {
        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit =
            IStandardExchangeRateProviderDFPkg.PkgInit({
                rateProviderFacet: rateProviderFacet, diamondFactory: diamondFactory
            });

        instance = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(StandardExchangeRateProviderDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(StandardExchangeRateProviderDFPkg).name);
    }
}
