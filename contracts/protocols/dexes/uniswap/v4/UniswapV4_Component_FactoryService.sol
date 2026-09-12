// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangePositionImportFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportFacet.sol";
import {UniswapV4StandardExchangeOutQueryFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryFacet.sol";
import {UniswapV4StandardExchangeOutMultiQueryFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol";
import {UniswapV4StandardExchangeOutMultiFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiFacet.sol";
import {UniswapV4StandardExchangeOutFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol";
import {UniswapV4StandardExchangeOutExecutionDelegate} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol";
import {UniswapV4StandardExchangeLiquidReserveFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveFacet.sol";
import {UniswapV4StandardExchangeInQueryFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol";
import {UniswapV4StandardExchangeInMultiQueryFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryFacet.sol";
import {UniswapV4StandardExchangeInMultiFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiFacet.sol";
import {UniswapV4StandardExchangeInFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol";
import {UniswapV4StandardExchangeInExecutionDelegate} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol";
import {UniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";

library UniswapV4_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4StandardExchangeInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInFacet.sol:UniswapV4StandardExchangeInFacet"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInFacet.sol:UniswapV4StandardExchangeInFacet"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInFacet");
    }

    function deployUniswapV4StandardExchangeInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInExecutionDelegate.sol:UniswapV4StandardExchangeInExecutionDelegate"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInExecutionDelegate")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInExecutionDelegate.sol:UniswapV4StandardExchangeInExecutionDelegate"), bytes("")
            )
        );
        vm.label(instance, "UniswapV4StandardExchangeInExecutionDelegate");
    }

    function deployUniswapV4StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInQueryFacet.sol:UniswapV4StandardExchangeInQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInQueryFacet.sol:UniswapV4StandardExchangeInQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInQueryFacet");
    }

    function deployUniswapV4StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangePositionImportFacet.sol:UniswapV4StandardExchangePositionImportFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangePositionImportFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangePositionImportFacet.sol:UniswapV4StandardExchangePositionImportFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangePositionImportFacet");
    }

    function deployUniswapV4StandardExchangeOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutExecutionDelegate.sol:UniswapV4StandardExchangeOutExecutionDelegate"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutExecutionDelegate")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutExecutionDelegate.sol:UniswapV4StandardExchangeOutExecutionDelegate"), bytes("")
            )
        );
        vm.label(instance, "UniswapV4StandardExchangeOutExecutionDelegate");
    }

    function deployUniswapV4StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4StandardExchangeOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutFacet.sol:UniswapV4StandardExchangeOutFacet"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutFacet.sol:UniswapV4StandardExchangeOutFacet"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutFacet");
    }

    function deployUniswapV4StandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutQueryFacet.sol:UniswapV4StandardExchangeOutQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutQueryFacet.sol:UniswapV4StandardExchangeOutQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutQueryFacet");
    }

    function deployUniswapV4StandardExchangeLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeLiquidReserveFacet.sol:UniswapV4StandardExchangeLiquidReserveFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeLiquidReserveFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeLiquidReserveFacet.sol:UniswapV4StandardExchangeLiquidReserveFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeLiquidReserveFacet");
    }

    function deployUniswapV4StandardExchangeInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiFacet.sol:UniswapV4StandardExchangeInMultiFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInMultiFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiFacet.sol:UniswapV4StandardExchangeInMultiFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInMultiFacet");
    }

    function deployUniswapV4StandardExchangeInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiQueryFacet.sol:UniswapV4StandardExchangeInMultiQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInMultiQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiQueryFacet.sol:UniswapV4StandardExchangeInMultiQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInMultiQueryFacet");
    }

    function deployUniswapV4StandardExchangeOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiFacet.sol:UniswapV4StandardExchangeOutMultiFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutMultiFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiFacet.sol:UniswapV4StandardExchangeOutMultiFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutMultiFacet");
    }

    function deployUniswapV4StandardExchangeOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiQueryFacet.sol:UniswapV4StandardExchangeOutMultiQueryFacet"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutMultiQueryFacet")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiQueryFacet.sol:UniswapV4StandardExchangeOutMultiQueryFacet"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutMultiQueryFacet");
    }

    function attachUniswapV4StandardExchangeMultiFacets(
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV4StandardExchangeInMultiFacet,
        IFacet uniswapV4StandardExchangeInMultiQueryFacet,
        IFacet uniswapV4StandardExchangeOutMultiFacet,
        IFacet uniswapV4StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory) {
        pkgInit.uniswapV4StandardExchangeInMultiFacet = uniswapV4StandardExchangeInMultiFacet;
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet = uniswapV4StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = uniswapV4StandardExchangeOutMultiFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet = uniswapV4StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkg instance) {
        instance = IUniswapV4StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV4StandardExchangeDFPkg.sol:UniswapV4StandardExchangeDFPkg"),
                    abi.encode(pkgInit),
                    ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeDFPkg")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeDFPkg.sol:UniswapV4StandardExchangeDFPkg"), abi.encode(pkgInit)
            )
                )
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeDFPkg");
    }

    /// @dev Packed PkgInit core. A 15-arg `buildArgs` is stack-too-deep without via_ir
    ///      when this library compiles as a small incremental unit.
    struct Univ4SePkgInitCore {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet uniswapV4StandardExchangeInFacet;
        IFacet uniswapV4StandardExchangeInQueryFacet;
        IFacet uniswapV4StandardExchangePositionImportFacet;
        IFacet uniswapV4StandardExchangeOutFacet;
        IFacet uniswapV4StandardExchangeOutQueryFacet;
        IFacet uniswapV4StandardExchangeLiquidReserveFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IPoolManager poolManager;
        IWETH weth;
    }

    function buildArgsUniswapV4StandardExchangePkgInit(Univ4SePkgInitCore memory a)
        internal
        pure
        returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit)
    {
        pkgInit.erc20Facet = a.erc20Facet;
        pkgInit.erc5267Facet = a.erc5267Facet;
        pkgInit.erc2612Facet = a.erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = a.multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = a.multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = a.uniswapV4StandardExchangeInFacet;
        pkgInit.uniswapV4StandardExchangeInQueryFacet = a.uniswapV4StandardExchangeInQueryFacet;
        pkgInit.uniswapV4StandardExchangePositionImportFacet = a.uniswapV4StandardExchangePositionImportFacet;
        pkgInit.uniswapV4StandardExchangeOutFacet = a.uniswapV4StandardExchangeOutFacet;
        pkgInit.uniswapV4StandardExchangeOutQueryFacet = a.uniswapV4StandardExchangeOutQueryFacet;
        pkgInit.uniswapV4StandardExchangeLiquidReserveFacet = a.uniswapV4StandardExchangeLiquidReserveFacet;
        pkgInit.vaultFeeOracleQuery = a.vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = a.vaultRegistryDeployment;
        pkgInit.permit2 = a.permit2;
        pkgInit.poolManager = a.poolManager;
        pkgInit.weth = a.weth;
        // positionManager defaults to address(0). twapOracle via attachTwapOracle.
    }

    function attachTwapOracle(
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit,
        IUniswapV4MultiPoolTwapOracle twapOracle
    ) internal pure returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory) {
        pkgInit.twapOracle = twapOracle;
        return pkgInit;
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
