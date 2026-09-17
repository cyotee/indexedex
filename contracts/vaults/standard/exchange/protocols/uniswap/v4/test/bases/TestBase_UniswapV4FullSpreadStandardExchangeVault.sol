// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {
    UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol";
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
    IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol";

abstract contract TestBase_UniswapV4FullSpreadStandardExchangeVault is TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for IFacet;
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for IIndexedexManagerProxy;
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
    IUniswapV4FullSpreadStandardExchangeVaultDFPkg internal uniswapV4StandardExchangeDFPkg;
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
            keccak256("TestBase_UniswapV4FullSpreadStandardExchangeVault_PoolManager")
        ));
        twapOracleFacet = create3Factory.deployUniswapV4MultiPoolTwapOracleFacet();
        twapOraclePkg =
            create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(twapOracleFacet, diamondPackageFactory);
        twapOracle = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)})
        );
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultPositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutFacet();
        uniswapV4StandardExchangeOutQueryFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutQueryFacet();
        uniswapV4StandardExchangeLiquidReserveFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet();
        uniswapV4StandardExchangeInMultiFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInMultiFacet();
        uniswapV4StandardExchangeInMultiQueryFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet();
        uniswapV4StandardExchangeOutMultiFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutMultiFacet();
        uniswapV4StandardExchangeOutMultiQueryFacet = create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet();

        vm.startPrank(owner);
        // Type default 20% for V4 liquid-reserve fee type id (D5–D8 / H4).
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultLiquidReservePercentageOfTypeId(
                type(IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve).interfaceId, DEFAULT_V4_LIQUID_RESERVE_PCT
            );

        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit =
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.buildArgsUniswapV4FullSpreadStandardExchangeVaultPkgInit(_univ4SePkgInitCore());
        pkgInit = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.attachTwapOracle(pkgInit, twapOracle);
        pkgInit = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.attachUniswapV4FullSpreadStandardExchangeVaultMultiFacets(
            pkgInit,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        uniswapV4StandardExchangeDFPkg = indexedexManager.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(pkgInit);
        vm.stopPrank();
    }

    function _univ4SePkgInitCore()
        internal
        view
        returns (UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.Univ4SePkgInitCore memory a)
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
}

// FactoryService loads these artifacts by name in focused build graphs.
