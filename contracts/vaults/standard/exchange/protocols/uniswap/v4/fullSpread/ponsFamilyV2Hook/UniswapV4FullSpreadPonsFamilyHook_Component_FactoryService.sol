// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
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

import {IUniswapV4FullSpreadPonsFamilyHookDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";

library UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4FullSpreadPonsFamilyHookInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4FullSpreadPonsFamilyHookInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookInFacet.sol:UniswapV4FullSpreadPonsFamilyHookInFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookInFacet")._hash()
        );
        _requireDelegate(address(instance), "UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()", executionDelegate);
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookInFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookInExecutionDelegate.sol:UniswapV4FullSpreadPonsFamilyHookInExecutionDelegate"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookInExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV4FullSpreadPonsFamilyHookInExecutionDelegate");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookInQueryFacet.sol:UniswapV4FullSpreadPonsFamilyHookInQueryFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookInQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookInQueryFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookPositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookPositionImportFacet.sol:UniswapV4FullSpreadPonsFamilyHookPositionImportFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookPositionImportFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookPositionImportFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol:UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookOutFacet.sol:UniswapV4FullSpreadPonsFamilyHookOutFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookOutFacet")._hash()
        );
        _requireDelegate(address(instance), "UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE()", executionDelegate);
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookOutFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookOutQueryFacet.sol:UniswapV4FullSpreadPonsFamilyHookOutQueryFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookOutQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookOutQueryFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet.sol:UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookInMultiFacet.sol:UniswapV4FullSpreadPonsFamilyHookInMultiFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookInMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookInMultiFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet.sol:UniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookOutMultiFacet.sol:UniswapV4FullSpreadPonsFamilyHookOutMultiFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookOutMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookOutMultiFacet");
    }

    function deployUniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet.sol:UniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet"),
            abi.encode("UniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet");
    }

    function attachUniswapV4FullSpreadPonsFamilyHookMultiFacets(
        IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV4StandardExchangeInMultiFacet,
        IFacet uniswapV4StandardExchangeInMultiQueryFacet,
        IFacet uniswapV4StandardExchangeOutMultiFacet,
        IFacet uniswapV4StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory) {
        pkgInit.uniswapV4StandardExchangeInMultiFacet = uniswapV4StandardExchangeInMultiFacet;
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet = uniswapV4StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = uniswapV4StandardExchangeOutMultiFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet = uniswapV4StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV4FullSpreadPonsFamilyHookDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4FullSpreadPonsFamilyHookDFPkg instance) {
        instance = IUniswapV4FullSpreadPonsFamilyHookDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV4FullSpreadPonsFamilyHookDFPkg.sol:UniswapV4FullSpreadPonsFamilyHookDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("UniswapV4FullSpreadPonsFamilyHookDFPkg")._hash()
                )
            )
        );
        if (instance.bindingHash() != keccak256(abi.encode(pkgInit))) revert InvalidComponentBinding();
        vm.label(address(instance), "UniswapV4FullSpreadPonsFamilyHookDFPkg");
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

    function buildArgsUniswapV4FullSpreadPonsFamilyHookPkgInit(Univ4SePkgInitCore memory a)
        internal
        pure
        returns (IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory pkgInit)
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
        pkgInit.expectedHook = ROBINHOOD_MAIN.PONS_V2_MEME_HOOK;
        // positionManager defaults to address(0). twapOracle via attachTwapOracle.
    }

    function attachTwapOracle(
        IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory pkgInit,
        IUniswapV4MultiPoolTwapOracle twapOracle
    ) internal pure returns (IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory) {
        pkgInit.twapOracle = twapOracle;
        return pkgInit;
    }

    function deployUniswapV4FullSpreadPonsFamilyHookDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4FullSpreadPonsFamilyHookDFPkg instance) {
        return deployUniswapV4FullSpreadPonsFamilyHookDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }

    error InvalidComponentBinding();

    function _requireDelegate(address instance, string memory getter, address expected) private view {
        (bool ok, bytes memory result) = instance.staticcall(abi.encodeWithSignature(getter));
        if (!ok || result.length != 32 || abi.decode(result, (address)) != expected || expected.code.length == 0)
            revert InvalidComponentBinding();
    }
}
