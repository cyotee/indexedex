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
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {IUniswapV4StandardExchangeDFPkgV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4StandardExchangeDFPkgV2.sol";

library UniswapV4_Component_FactoryServiceV2 {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4StandardExchangeInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInFacetV2.sol:UniswapV4StandardExchangeInFacetV2"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInFacetV2.sol:UniswapV4StandardExchangeInFacetV2"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInFacetV2");
    }

    function deployUniswapV4StandardExchangeInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInExecutionDelegateV2.sol:UniswapV4StandardExchangeInExecutionDelegateV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInExecutionDelegateV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInExecutionDelegateV2.sol:UniswapV4StandardExchangeInExecutionDelegateV2"), bytes("")
            )
        );
        vm.label(instance, "UniswapV4StandardExchangeInExecutionDelegateV2");
    }

    function deployUniswapV4StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInQueryFacetV2.sol:UniswapV4StandardExchangeInQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInQueryFacetV2.sol:UniswapV4StandardExchangeInQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInQueryFacetV2");
    }

    function deployUniswapV4StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangePositionImportFacetV2.sol:UniswapV4StandardExchangePositionImportFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangePositionImportFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangePositionImportFacetV2.sol:UniswapV4StandardExchangePositionImportFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangePositionImportFacetV2");
    }

    function deployUniswapV4StandardExchangeOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutExecutionDelegateV2.sol:UniswapV4StandardExchangeOutExecutionDelegateV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutExecutionDelegateV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutExecutionDelegateV2.sol:UniswapV4StandardExchangeOutExecutionDelegateV2"), bytes("")
            )
        );
        vm.label(instance, "UniswapV4StandardExchangeOutExecutionDelegateV2");
    }

    function deployUniswapV4StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4StandardExchangeOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutFacetV2.sol:UniswapV4StandardExchangeOutFacetV2"), abi.encode(executionDelegate)),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutFacetV2.sol:UniswapV4StandardExchangeOutFacetV2"), abi.encode(executionDelegate)
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutFacetV2");
    }

    function deployUniswapV4StandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutQueryFacetV2.sol:UniswapV4StandardExchangeOutQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutQueryFacetV2.sol:UniswapV4StandardExchangeOutQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutQueryFacetV2");
    }

    function deployUniswapV4StandardExchangeLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeLiquidReserveFacetV2.sol:UniswapV4StandardExchangeLiquidReserveFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeLiquidReserveFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeLiquidReserveFacetV2.sol:UniswapV4StandardExchangeLiquidReserveFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeLiquidReserveFacetV2");
    }

    function deployUniswapV4StandardExchangeInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiFacetV2.sol:UniswapV4StandardExchangeInMultiFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInMultiFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiFacetV2.sol:UniswapV4StandardExchangeInMultiFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInMultiFacetV2");
    }

    function deployUniswapV4StandardExchangeInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiQueryFacetV2.sol:UniswapV4StandardExchangeInMultiQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeInMultiQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeInMultiQueryFacetV2.sol:UniswapV4StandardExchangeInMultiQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeInMultiQueryFacetV2");
    }

    function deployUniswapV4StandardExchangeOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiFacetV2.sol:UniswapV4StandardExchangeOutMultiFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutMultiFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiFacetV2.sol:UniswapV4StandardExchangeOutMultiFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutMultiFacetV2");
    }

    function deployUniswapV4StandardExchangeOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiQueryFacetV2.sol:UniswapV4StandardExchangeOutMultiQueryFacetV2"),
            ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeOutMultiQueryFacetV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOutMultiQueryFacetV2.sol:UniswapV4StandardExchangeOutMultiQueryFacetV2"), bytes("")
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeOutMultiQueryFacetV2");
    }

    function attachUniswapV4StandardExchangeMultiFacets(
        IUniswapV4StandardExchangeDFPkgV2.PkgInit memory pkgInit,
        IFacet uniswapV4StandardExchangeInMultiFacet,
        IFacet uniswapV4StandardExchangeInMultiQueryFacet,
        IFacet uniswapV4StandardExchangeOutMultiFacet,
        IFacet uniswapV4StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV4StandardExchangeDFPkgV2.PkgInit memory) {
        pkgInit.uniswapV4StandardExchangeInMultiFacet = uniswapV4StandardExchangeInMultiFacet;
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet = uniswapV4StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = uniswapV4StandardExchangeOutMultiFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet = uniswapV4StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4StandardExchangeDFPkgV2.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkgV2 instance) {
        instance = IUniswapV4StandardExchangeDFPkgV2(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV4StandardExchangeDFPkgV2.sol:UniswapV4StandardExchangeDFPkgV2"),
                    abi.encode(pkgInit),
                    ArtifactCreationCode.releaseSalt(
                keccak256(bytes("UniswapV4StandardExchangeDFPkgV2")),
                ArtifactCreationCode.creationCode("UniswapV4StandardExchangeDFPkgV2.sol:UniswapV4StandardExchangeDFPkgV2"), abi.encode(pkgInit)
            )
                )
            )
        );
        vm.label(address(instance), "UniswapV4StandardExchangeDFPkgV2");
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
        returns (IUniswapV4StandardExchangeDFPkgV2.PkgInit memory pkgInit)
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
        IUniswapV4StandardExchangeDFPkgV2.PkgInit memory pkgInit,
        IUniswapV4MultiPoolTwapOracle twapOracle
    ) internal pure returns (IUniswapV4StandardExchangeDFPkgV2.PkgInit memory) {
        pkgInit.twapOracle = twapOracle;
        return pkgInit;
    }

    function deployUniswapV4StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV4StandardExchangeDFPkgV2.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkgV2 instance) {
        return deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
