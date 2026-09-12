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
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

import {IStandardExchangeBufferPoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol";

/**
 * @title StandardExchangeBufferPool_FactoryService
 * @notice Factory service for deploying Standard Exchange Buffer Pool components via CREATE3.
 * @dev Provides deterministic deployment of facets and packages.
 */
library StandardExchangeBufferPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBufferPoolFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("StandardExchangeBufferPoolFacet.sol:StandardExchangeBufferPoolFacet"),
            abi.encode("StandardExchangeBufferPoolFacet")._hash()
        );
        vm.label(address(instance), "StandardExchangeBufferPoolFacet");
    }

    function deployPoolLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("StandardExchangeBufferPoolLiquidityFacet.sol:StandardExchangeBufferPoolLiquidityFacet"),
            abi.encode("StandardExchangeBufferPoolLiquidityFacet")._hash()
        );
        vm.label(address(instance), "StandardExchangeBufferPoolLiquidityFacet");
    }

    function deployHookFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("StandardExchangeHookFacet.sol:StandardExchangeHookFacet"),
            abi.encode("StandardExchangeHookFacet")._hash()
        );
        vm.label(address(instance), "StandardExchangeHookFacet");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Package Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBufferPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IStandardExchangeBufferPoolPkg.PkgInit memory pkgInit
    ) internal returns (IStandardExchangeBufferPoolPkg instance) {
        instance = IStandardExchangeBufferPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("StandardExchangeBufferPoolStandardVaultPkg.sol:StandardExchangeBufferPoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("StandardExchangeBufferPoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "StandardExchangeBufferPoolStandardVaultPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Identity helper: returns the caller-assembled PkgInit unchanged.
     * @dev Callers should build the PkgInit struct locally (field-by-field) to avoid
     *      stack-too-deep errors, then pass it here if they want to go through a
     *      FactoryService call-site for labelling / tracing.
     */
    function buildBufferPoolPkgInit(
        IStandardExchangeBufferPoolPkg.PkgInit memory pkgInit
    ) internal pure returns (IStandardExchangeBufferPoolPkg.PkgInit memory) {
        return pkgInit;
    }
}
