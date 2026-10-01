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

import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";

library UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet")._hash()
        );
        _requireDelegate(address(instance), "UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()", executionDelegate);
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate")._hash()
        );
        vm.label(instance, "UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet"), abi.encode(executionDelegate)),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet")._hash()
        );
        _requireDelegate(address(instance), "UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE()", executionDelegate);
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet");
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet"),
            abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet");
    }

    function attachUniswapV4FullSpreadHooklessStandardExchangeVaultMultiFacets(
        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV4StandardExchangeInMultiFacet,
        IFacet uniswapV4StandardExchangeInMultiQueryFacet,
        IFacet uniswapV4StandardExchangeOutMultiFacet,
        IFacet uniswapV4StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory) {
        pkgInit.uniswapV4StandardExchangeInMultiFacet = uniswapV4StandardExchangeInMultiFacet;
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet = uniswapV4StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = uniswapV4StandardExchangeOutMultiFacet;
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet = uniswapV4StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg instance) {
        instance = IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg")._hash()
                )
            )
        );
        if (instance.bindingHash() != keccak256(abi.encode(pkgInit))) revert InvalidComponentBinding();
        vm.label(address(instance), "UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg");
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

    function buildArgsUniswapV4FullSpreadHooklessStandardExchangeVaultPkgInit(Univ4SePkgInitCore memory a)
        internal
        pure
        returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit)
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
        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit,
        IUniswapV4MultiPoolTwapOracle twapOracle
    ) internal pure returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory) {
        pkgInit.twapOracle = twapOracle;
        return pkgInit;
    }

    function deployUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg instance) {
        return deployUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkgFromVaultRegistry(
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
