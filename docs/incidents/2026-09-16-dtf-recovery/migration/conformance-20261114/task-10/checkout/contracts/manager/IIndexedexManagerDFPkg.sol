// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

interface IIndexedexManagerDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet diamondCutFacet;
        IFacet multiStepOwnableFacet;
        IFacet vaultFeeQueryFacet;
        IFacet vaultFeeManagerFacet;
        IFacet operableFacet;
        IFacet vaultRegistryDeploymentFacet;
        IFacet vaultRegistryVaultManagerFacet;
        IFacet vaultRegistryVaultPackageManagerFacet;
        IFacet vaultRegistryVaultPackageQueryFacet;
        IFacet vaultRegistryVaultQueryFacet;
        IFacet vaultRegistryDisableQueryFacet;
        IFacet vaultRegistryDisableManagerFacet;
    }

    struct PkgArgs {
        address owner;
        IFeeCollectorProxy feeTo;
        ICreate3FactoryProxy create3Factory;
        IDiamondPackageCallBackFactory diamondPackageFactory;
    }
}
