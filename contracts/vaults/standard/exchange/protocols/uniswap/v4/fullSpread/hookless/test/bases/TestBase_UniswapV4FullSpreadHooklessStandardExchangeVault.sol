// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4TwapOracleFactoryService
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol";
import {
    IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";

abstract contract TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault is TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService for IFacet;
    using UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService for IIndexedexManagerProxy;
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    uint256 internal constant DEFAULT_V4_LIQUID_RESERVE_PCT = 0.2e18;

    IPoolManager internal poolManager;
    IWETH internal weth;
    IFacet internal uniswapV4StandardExchangeInFacet;
    IFacet internal uniswapV4StandardExchangeInQueryFacet;
    IFacet internal uniswapV4StandardExchangePositionImportFacet;
    IFacet internal uniswapV4StandardExchangeOutFacet;
    IFacet internal uniswapV4StandardExchangeOutQueryFacet;
    IFacet internal uniswapV4StandardExchangeLiquidReserveFacet;
    IFacet internal uniswapV4StandardExchangeInMultiFacet;
    IFacet internal uniswapV4StandardExchangeInMultiQueryFacet;
    IFacet internal uniswapV4StandardExchangeOutMultiFacet;
    IFacet internal uniswapV4StandardExchangeOutMultiQueryFacet;
    IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg internal uniswapV4StandardExchangeDFPkg;
    IFacet internal twapOracleFacet;
    IUniswapV4MultiPoolTwapOracleDFPkg internal twapOraclePkg;
    IUniswapV4MultiPoolTwapOracle internal twapOracle;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        if (address(weth) == address(0)) {
            weth = IWETH(address(new WETH9()));
        }
        poolManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_PoolManager")
        ));
        twapOracleFacet = create3Factory.deployUniswapV4MultiPoolTwapOracleFacet();
        twapOraclePkg =
            create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(twapOracleFacet, diamondPackageFactory);
        twapOracle = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)})
        );
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet();
        uniswapV4StandardExchangeOutQueryFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet();
        uniswapV4StandardExchangeLiquidReserveFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet();
        uniswapV4StandardExchangeInMultiFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet();
        uniswapV4StandardExchangeInMultiQueryFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet();
        uniswapV4StandardExchangeOutMultiFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet();
        uniswapV4StandardExchangeOutMultiQueryFacet = create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet();

        IPositionManager importManager = _positionManagerForTests();
        vm.startPrank(owner);
        // Type default 20% for V4 liquid-reserve fee type id (D5–D8 / H4).
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultLiquidReservePercentageOfTypeId(
                type(IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve).interfaceId, DEFAULT_V4_LIQUID_RESERVE_PCT
            );

        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit =
            UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.buildArgsUniswapV4FullSpreadHooklessStandardExchangeVaultPkgInit(_univ4SePkgInitCore());
        pkgInit = UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.attachTwapOracle(pkgInit, twapOracle);
        pkgInit.positionManager = importManager;
        pkgInit = UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.attachUniswapV4FullSpreadHooklessStandardExchangeVaultMultiFacets(
            pkgInit,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        uniswapV4StandardExchangeDFPkg = indexedexManager.deployUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(pkgInit);
        vm.stopPrank();
    }

    function _univ4SePkgInitCore()
        internal
        view
        returns (UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.Univ4SePkgInitCore memory a)
    {
        a.erc20Facet = erc20Facet;
        a.erc5267Facet = erc5267Facet;
        a.erc2612Facet = erc2612Facet;
        a.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        a.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        a.uniswapV4StandardExchangeInFacet = uniswapV4StandardExchangeInFacet;
        a.uniswapV4StandardExchangeInQueryFacet = uniswapV4StandardExchangeInQueryFacet;
        a.uniswapV4StandardExchangePositionImportFacet = uniswapV4StandardExchangePositionImportFacet;
        a.uniswapV4StandardExchangeOutFacet = uniswapV4StandardExchangeOutFacet;
        a.uniswapV4StandardExchangeOutQueryFacet = uniswapV4StandardExchangeOutQueryFacet;
        a.uniswapV4StandardExchangeLiquidReserveFacet = uniswapV4StandardExchangeLiquidReserveFacet;
        a.vaultFeeOracleQuery = indexedexManager;
        a.vaultRegistryDeployment = indexedexManager;
        a.permit2 = permit2;
        a.poolManager = poolManager;
        a.weth = weth;
    }

    function _positionManagerForTests() internal virtual returns (IPositionManager) {
        return IPositionManager(address(0));
    }
}

// FactoryService loads these artifacts by name in focused build graphs.
