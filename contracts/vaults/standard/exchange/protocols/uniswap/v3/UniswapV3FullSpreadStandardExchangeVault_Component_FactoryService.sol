// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";

library UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.v4Accounting.v1")._hash()
        );
        vm.label(instance, "UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultInFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.v4Accounting.v2")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultInQueryFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        // Compatibility entrypoint: exact-out now executes directly on its facet.
        instance = address(deployUniswapV3FullSpreadStandardExchangeVaultOutFacet(create3Factory));
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultOutFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.sol:UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        return deployUniswapV3FullSpreadStandardExchangeVaultReserveFacet(create3Factory);
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultReserveFacet.sol:UniswapV3FullSpreadStandardExchangeVaultReserveFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultReserveFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultReserveFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        return deployUniswapV3FullSpreadStandardExchangeVaultBundleFacet(create3Factory);
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultBundleFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultBundleFacet.sol:UniswapV3FullSpreadStandardExchangeVaultBundleFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultBundleFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultBundleFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        return deployUniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet(create3Factory);
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        return deployUniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet(create3Factory);
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet.sol:UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet.v4Accounting.v1")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        // Both bundle previews share one facet; this legacy slot is not cut.
        return deployUniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet(create3Factory);
    }

    function attachUniswapV3FullSpreadStandardExchangeVaultMultiFacets(
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV3StandardExchangeInMultiFacet,
        IFacet uniswapV3StandardExchangeInMultiQueryFacet,
        IFacet uniswapV3StandardExchangeOutMultiFacet,
        IFacet uniswapV3StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory) {
        pkgInit.uniswapV3StandardExchangeInMultiFacet = uniswapV3StandardExchangeInMultiFacet;
        pkgInit.uniswapV3StandardExchangeInMultiQueryFacet = uniswapV3StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiFacet = uniswapV3StandardExchangeOutMultiFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiQueryFacet = uniswapV3StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3FullSpreadStandardExchangeVaultDFPkg instance) {
        instance = IUniswapV3FullSpreadStandardExchangeVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV3FullSpreadStandardExchangeVaultDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("UniswapV3FullSpreadStandardExchangeVaultDFPkg.v4Accounting.v2")._hash()
                )
            )
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultDFPkg");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3FullSpreadStandardExchangeVaultDFPkg instance) {
        return deployUniswapV3FullSpreadStandardExchangeVaultDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
