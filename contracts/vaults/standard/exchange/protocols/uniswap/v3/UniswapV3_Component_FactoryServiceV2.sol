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

import {IUniswapV3StandardExchangeDFPkgV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3StandardExchangeDFPkgV2.sol";

library UniswapV3_Component_FactoryServiceV2 {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV3StandardExchangeInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInExecutionDelegateV2.sol:UniswapV3StandardExchangeInExecutionDelegateV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInExecutionDelegateV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInExecutionDelegateV2.sol:UniswapV3StandardExchangeInExecutionDelegateV2"), bytes("")
            )
        );
        vm.label(instance, "UniswapV3StandardExchangeInExecutionDelegateV2");
    }

    function deployUniswapV3StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3StandardExchangeInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInFacetV2.sol:UniswapV3StandardExchangeInFacetV2"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInFacetV2.sol:UniswapV3StandardExchangeInFacetV2"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInFacetV2");
    }

    function deployUniswapV3StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInQueryFacetV2.sol:UniswapV3StandardExchangeInQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInQueryFacetV2.sol:UniswapV3StandardExchangeInQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInQueryFacetV2");
    }

    function deployUniswapV3StandardExchangeOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutExecutionDelegateV2.sol:UniswapV3StandardExchangeOutExecutionDelegateV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutExecutionDelegateV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutExecutionDelegateV2.sol:UniswapV3StandardExchangeOutExecutionDelegateV2"), bytes("")
            )
        );
        vm.label(instance, "UniswapV3StandardExchangeOutExecutionDelegateV2");
    }

    function deployUniswapV3StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3StandardExchangeOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutFacetV2.sol:UniswapV3StandardExchangeOutFacetV2"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutFacetV2.sol:UniswapV3StandardExchangeOutFacetV2"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutFacetV2");
    }

    function deployUniswapV3StandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutQueryFacetV2.sol:UniswapV3StandardExchangeOutQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutQueryFacetV2.sol:UniswapV3StandardExchangeOutQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutQueryFacetV2");
    }

    function deployUniswapV3StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangePositionImportFacetV2.sol:UniswapV3StandardExchangePositionImportFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangePositionImportFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangePositionImportFacetV2.sol:UniswapV3StandardExchangePositionImportFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangePositionImportFacetV2");
    }

    function deployUniswapV3StandardExchangeLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeLiquidReserveFacetV2.sol:UniswapV3StandardExchangeLiquidReserveFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeLiquidReserveFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeLiquidReserveFacetV2.sol:UniswapV3StandardExchangeLiquidReserveFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeLiquidReserveFacetV2");
    }

    function deployUniswapV3StandardExchangeInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiFacetV2.sol:UniswapV3StandardExchangeInMultiFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInMultiFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiFacetV2.sol:UniswapV3StandardExchangeInMultiFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInMultiFacetV2");
    }

    function deployUniswapV3StandardExchangeInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiQueryFacetV2.sol:UniswapV3StandardExchangeInMultiQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeInMultiQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeInMultiQueryFacetV2.sol:UniswapV3StandardExchangeInMultiQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeInMultiQueryFacetV2");
    }

    function deployUniswapV3StandardExchangeOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiFacetV2.sol:UniswapV3StandardExchangeOutMultiFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutMultiFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiFacetV2.sol:UniswapV3StandardExchangeOutMultiFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutMultiFacetV2");
    }

    function deployUniswapV3StandardExchangeOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiQueryFacetV2.sol:UniswapV3StandardExchangeOutMultiQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeOutMultiQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeOutMultiQueryFacetV2.sol:UniswapV3StandardExchangeOutMultiQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeOutMultiQueryFacetV2");
    }

    function attachUniswapV3StandardExchangeMultiFacets(
        IUniswapV3StandardExchangeDFPkgV2.PkgInit memory pkgInit,
        IFacet uniswapV3StandardExchangeInMultiFacet,
        IFacet uniswapV3StandardExchangeInMultiQueryFacet,
        IFacet uniswapV3StandardExchangeOutMultiFacet,
        IFacet uniswapV3StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV3StandardExchangeDFPkgV2.PkgInit memory) {
        pkgInit.uniswapV3StandardExchangeInMultiFacet = uniswapV3StandardExchangeInMultiFacet;
        pkgInit.uniswapV3StandardExchangeInMultiQueryFacet = uniswapV3StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiFacet = uniswapV3StandardExchangeOutMultiFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiQueryFacet = uniswapV3StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV3StandardExchangeDFPkgV2.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkgV2 instance) {
        instance = IUniswapV3StandardExchangeDFPkgV2(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV3StandardExchangeDFPkgV2.sol:UniswapV3StandardExchangeDFPkgV2"),
                    abi.encode(pkgInit),
                    ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV3StandardExchangeDFPkgV2")),
                ArtifactCreationCode.creationCode("UniswapV3StandardExchangeDFPkgV2.sol:UniswapV3StandardExchangeDFPkgV2"), abi.encode(pkgInit)
            )
                )
            )
        );
        vm.label(address(instance), "UniswapV3StandardExchangeDFPkgV2");
    }

    function deployUniswapV3StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV3StandardExchangeDFPkgV2.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkgV2 instance) {
        return deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
