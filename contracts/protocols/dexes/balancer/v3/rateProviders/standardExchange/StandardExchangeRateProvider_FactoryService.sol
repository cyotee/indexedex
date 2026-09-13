// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

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

import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";

import {IWrappedStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/IWrappedStandardExchangeRateProviderDFPkg.sol";

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
        bytes memory code_ = ArtifactCreationCode.creationCode("StandardExchangeRateProviderFacet.sol:StandardExchangeRateProviderFacet");
        instance = create3Factory.deployFacet(
            code_, ArtifactCreationCode.releaseSalt(abi.encode("StandardExchangeRateProviderFacet")._hash(), code_, bytes(""))
        );
        vm.label(address(instance), "StandardExchangeRateProviderFacet");
    }

    function deployWrappedStandardExchangeRateProviderFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code_ = ArtifactCreationCode.creationCode("WrappedStandardExchangeRateProviderFacet.sol:WrappedStandardExchangeRateProviderFacet");
        instance = create3Factory.deployFacet(
            code_, ArtifactCreationCode.releaseSalt(abi.encode("WrappedStandardExchangeRateProviderFacet")._hash(), code_, bytes(""))
        );
        vm.label(address(instance), "WrappedStandardExchangeRateProviderFacet");
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

        bytes memory code_ = ArtifactCreationCode.creationCode("StandardExchangeRateProviderDFPkg.sol:StandardExchangeRateProviderDFPkg");
        bytes memory args_ = abi.encode(pkgInit);

        instance = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    code_, args_,
                    ArtifactCreationCode.releaseSalt(abi.encode("StandardExchangeRateProviderDFPkg")._hash(), code_, args_)
                )
            )
        );
        vm.label(address(instance), "StandardExchangeRateProviderDFPkg");
    }

    function deployWrappedStandardExchangeRateProviderDFPkg(
        ICreate3FactoryProxy create3Factory,
        IFacet rateProviderFacet,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal returns (IWrappedStandardExchangeRateProviderDFPkg instance) {
        IWrappedStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit =
            IWrappedStandardExchangeRateProviderDFPkg.PkgInit({
                rateProviderFacet: rateProviderFacet,
                diamondFactory: diamondFactory
            });

        bytes memory code_ = ArtifactCreationCode.creationCode("WrappedStandardExchangeRateProviderDFPkg.sol:WrappedStandardExchangeRateProviderDFPkg");
        bytes memory args_ = abi.encode(pkgInit);

        instance = IWrappedStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    code_, args_,
                    ArtifactCreationCode.releaseSalt(abi.encode("WrappedStandardExchangeRateProviderDFPkg")._hash(), code_, args_)
                )
            )
        );
        vm.label(address(instance), "WrappedStandardExchangeRateProviderDFPkg");
    }
}
