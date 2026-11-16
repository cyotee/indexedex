// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
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
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate")._hash()
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
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultInFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultInQueryFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultOutFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.sol:UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet.sol:UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInMultiFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInMultiFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultInMultiFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet");
    }

    function deployUniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet"),
            abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet");
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
                    abi.encode("UniswapV3FullSpreadStandardExchangeVaultDFPkg")._hash()
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
