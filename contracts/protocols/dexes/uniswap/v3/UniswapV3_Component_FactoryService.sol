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

import {IUniswapV3StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";

library UniswapV3_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV3StandardExchangeInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInExecutionDelegate.sol:UniswapV3StandardExchangeInExecutionDelegate"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInExecutionDelegate")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInExecutionDelegate.sol:UniswapV3StandardExchangeInExecutionDelegate"), bytes("")
            )
        );
        vm.label(instance, "UniswapV3StandardExchangeInExecutionDelegate");
    }

    function deployUniswapV3StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3StandardExchangeInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInFacet.sol:UniswapV3StandardExchangeInFacet"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInFacet.sol:UniswapV3StandardExchangeInFacet"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInFacet");
    }

    function deployUniswapV3StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInQueryFacet.sol:UniswapV3StandardExchangeInQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInQueryFacet.sol:UniswapV3StandardExchangeInQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInQueryFacet");
    }

    function deployUniswapV3StandardExchangeOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutExecutionDelegate.sol:UniswapV3StandardExchangeOutExecutionDelegate"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutExecutionDelegate")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutExecutionDelegate.sol:UniswapV3StandardExchangeOutExecutionDelegate"), bytes("")
            )
        );
        vm.label(instance, "UniswapV3StandardExchangeOutExecutionDelegate");
    }

    function deployUniswapV3StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3StandardExchangeOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutFacet.sol:UniswapV3StandardExchangeOutFacet"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutFacet.sol:UniswapV3StandardExchangeOutFacet"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutFacet");
    }

    function deployUniswapV3StandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutQueryFacet.sol:UniswapV3StandardExchangeOutQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutQueryFacet.sol:UniswapV3StandardExchangeOutQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutQueryFacet");
    }

    function deployUniswapV3StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangePositionImportFacet.sol:UniswapV3StandardExchangePositionImportFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangePositionImportFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangePositionImportFacet.sol:UniswapV3StandardExchangePositionImportFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangePositionImportFacet");
    }

    function deployUniswapV3StandardExchangeLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeLiquidReserveFacet.sol:UniswapV3StandardExchangeLiquidReserveFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeLiquidReserveFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeLiquidReserveFacet.sol:UniswapV3StandardExchangeLiquidReserveFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeLiquidReserveFacet");
    }

    function deployUniswapV3StandardExchangeInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiFacet.sol:UniswapV3StandardExchangeInMultiFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInMultiFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiFacet.sol:UniswapV3StandardExchangeInMultiFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInMultiFacet");
    }

    function deployUniswapV3StandardExchangeInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiQueryFacet.sol:UniswapV3StandardExchangeInMultiQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInMultiQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiQueryFacet.sol:UniswapV3StandardExchangeInMultiQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInMultiQueryFacet");
    }

    function deployUniswapV3StandardExchangeOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiFacet.sol:UniswapV3StandardExchangeOutMultiFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutMultiFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiFacet.sol:UniswapV3StandardExchangeOutMultiFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutMultiFacet");
    }

    function deployUniswapV3StandardExchangeOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiQueryFacet.sol:UniswapV3StandardExchangeOutMultiQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutMultiQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiQueryFacet.sol:UniswapV3StandardExchangeOutMultiQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutMultiQueryFacet");
    }

    function attachUniswapV3StandardExchangeMultiFacets(
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV3StandardExchangeInMultiFacet,
        IFacet uniswapV3StandardExchangeInMultiQueryFacet,
        IFacet uniswapV3StandardExchangeOutMultiFacet,
        IFacet uniswapV3StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV3StandardExchangeDFPkg.PkgInit memory) {
        pkgInit.uniswapV3StandardExchangeInMultiFacet = uniswapV3StandardExchangeInMultiFacet;
        pkgInit.uniswapV3StandardExchangeInMultiQueryFacet = uniswapV3StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiFacet = uniswapV3StandardExchangeOutMultiFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiQueryFacet = uniswapV3StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkg instance) {
        instance = IUniswapV3StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV3StandardExchangeDFPkg.sol:UniswapV3StandardExchangeDFPkg"),
                    abi.encode(pkgInit),
                    ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeDFPkg")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeDFPkg.sol:UniswapV3StandardExchangeDFPkg"), abi.encode(pkgInit)
            )
                )
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeDFPkg");
    }

    function deployUniswapV3StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkg instance) {
        return deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
