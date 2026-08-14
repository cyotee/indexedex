// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    UniswapV4StandardExchangeInExecutionDelegate
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol";
import {
    UniswapV4StandardExchangeInFacet
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol";
import {
    UniswapV4StandardExchangeInQueryFacet
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol";
import {
    UniswapV4StandardExchangePositionImportFacet
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportFacet.sol";
import {
    UniswapV4StandardExchangeOutExecutionDelegate
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol";
import {
    UniswapV4StandardExchangeOutFacet
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol";
import {
    UniswapV4StandardExchangeOutQueryFacet
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryFacet.sol";
import {
    UniswapV4StandardExchangeLiquidReserveFacet
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveFacet.sol";
import {
    IUniswapV4StandardExchangeDFPkg,
    UniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";

library UniswapV4_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4StandardExchangeInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(type(UniswapV4StandardExchangeInFacet).creationCode, abi.encode(executionDelegate)),
            abi.encode(type(UniswapV4StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeInFacet).name);
    }

    function deployUniswapV4StandardExchangeInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            type(UniswapV4StandardExchangeInExecutionDelegate).creationCode,
            abi.encode(type(UniswapV4StandardExchangeInExecutionDelegate).name)._hash()
        );
        vm.label(instance, type(UniswapV4StandardExchangeInExecutionDelegate).name);
    }

    function deployUniswapV4StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeInQueryFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeInQueryFacet).name);
    }

    function deployUniswapV4StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangePositionImportFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangePositionImportFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangePositionImportFacet).name);
    }

    function deployUniswapV4StandardExchangeOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            type(UniswapV4StandardExchangeOutExecutionDelegate).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOutExecutionDelegate).name)._hash()
        );
        vm.label(instance, type(UniswapV4StandardExchangeOutExecutionDelegate).name);
    }

    function deployUniswapV4StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4StandardExchangeOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(type(UniswapV4StandardExchangeOutFacet).creationCode, abi.encode(executionDelegate)),
            abi.encode(type(UniswapV4StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeOutFacet).name);
    }

    function deployUniswapV4StandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOutQueryFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOutQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeOutQueryFacet).name);
    }

    function deployUniswapV4StandardExchangeLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeLiquidReserveFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeLiquidReserveFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeLiquidReserveFacet).name);
    }

    function deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkg instance) {
        instance = IUniswapV4StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV4StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV4StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeDFPkg).name);
    }

    function buildArgsUniswapV4StandardExchangePkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet multiAssetBasicVaultFacet,
        IFacet multiAssetStandardVaultFacet,
        IFacet uniswapV4StandardExchangeInFacet,
        IFacet uniswapV4StandardExchangeInQueryFacet,
        IFacet uniswapV4StandardExchangePositionImportFacet,
        IFacet uniswapV4StandardExchangeOutFacet,
        IFacet uniswapV4StandardExchangeOutQueryFacet,
        IFacet uniswapV4StandardExchangeLiquidReserveFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IPoolManager poolManager
    ) internal pure returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit) {
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = uniswapV4StandardExchangeInFacet;
        pkgInit.uniswapV4StandardExchangeInQueryFacet = uniswapV4StandardExchangeInQueryFacet;
        pkgInit.uniswapV4StandardExchangePositionImportFacet = uniswapV4StandardExchangePositionImportFacet;
        pkgInit.uniswapV4StandardExchangeOutFacet = uniswapV4StandardExchangeOutFacet;
        pkgInit.uniswapV4StandardExchangeOutQueryFacet = uniswapV4StandardExchangeOutQueryFacet;
        pkgInit.uniswapV4StandardExchangeLiquidReserveFacet = uniswapV4StandardExchangeLiquidReserveFacet;
        pkgInit.vaultFeeOracleQuery = vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = vaultRegistryDeployment;
        pkgInit.permit2 = permit2;
        pkgInit.poolManager = poolManager;
        // positionManager defaults to address(0) — import disabled until bound.
    }

    function buildArgsUniswapV4StandardExchangePkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet multiAssetBasicVaultFacet,
        IFacet multiAssetStandardVaultFacet,
        IFacet uniswapV4StandardExchangeInFacet,
        IFacet uniswapV4StandardExchangeInQueryFacet,
        IFacet uniswapV4StandardExchangePositionImportFacet,
        IFacet uniswapV4StandardExchangeOutFacet,
        IFacet uniswapV4StandardExchangeOutQueryFacet,
        IFacet uniswapV4StandardExchangeLiquidReserveFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IPoolManager poolManager,
        IPositionManager positionManager
    ) internal pure returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit) {
        pkgInit = buildArgsUniswapV4StandardExchangePkgInit(
            erc20Facet,
            erc5267Facet,
            erc2612Facet,
            multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet,
            uniswapV4StandardExchangeInFacet,
            uniswapV4StandardExchangeInQueryFacet,
            uniswapV4StandardExchangePositionImportFacet,
            uniswapV4StandardExchangeOutFacet,
            uniswapV4StandardExchangeOutQueryFacet,
            uniswapV4StandardExchangeLiquidReserveFacet,
            vaultFeeOracleQuery,
            vaultRegistryDeployment,
            permit2,
            poolManager
        );
        pkgInit.positionManager = positionManager;
    }

    function deployUniswapV4StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkg instance) {
        return deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
