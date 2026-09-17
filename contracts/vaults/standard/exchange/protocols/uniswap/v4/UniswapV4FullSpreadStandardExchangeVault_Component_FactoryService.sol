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

import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";

library UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4FullSpreadStandardExchangeVaultInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultInFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultInFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol:UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInQueryFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultInQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultInQueryFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultPositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet.sol:UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultOutFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet.sol:UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInMultiFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInMultiFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultInMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultInMultiFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet"),
            abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet");
    }

    function attachUniswapV4FullSpreadStandardExchangeVaultMultiFacets(
        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV4StandardExchangeInMultiFacet,
        IFacet uniswapV4StandardExchangeInMultiQueryFacet,
        IFacet uniswapV4StandardExchangeOutMultiFacet,
        IFacet uniswapV4StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory) {
        pkgInit.uniswapV4StandardExchangeInMultiFacet = uniswapV4StandardExchangeInMultiFacet;
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet = uniswapV4StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = uniswapV4StandardExchangeOutMultiFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet = uniswapV4StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg instance) {
        instance = IUniswapV4FullSpreadStandardExchangeVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("UniswapV4FullSpreadStandardExchangeVaultDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "UniswapV4FullSpreadStandardExchangeVaultDFPkg");
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

    function buildArgsUniswapV4FullSpreadStandardExchangeVaultPkgInit(Univ4SePkgInitCore memory a)
        internal
        pure
        returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit)
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
        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit,
        IUniswapV4MultiPoolTwapOracle twapOracle
    ) internal pure returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory) {
        pkgInit.twapOracle = twapOracle;
        return pkgInit;
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4FullSpreadStandardExchangeVaultDFPkg instance) {
        return deployUniswapV4FullSpreadStandardExchangeVaultDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
