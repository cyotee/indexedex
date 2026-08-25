// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
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
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";

contract TestBase_UniswapV4StandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    uint256 internal constant DEFAULT_V4_LIQUID_RESERVE_PCT = 0.2e18;

    PoolManager internal poolManager;
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
    IUniswapV4StandardExchangeDFPkg internal uniswapV4StandardExchangeDFPkg;
    IFacet internal twapOracleFacet;
    IUniswapV4MultiPoolTwapOracleDFPkg internal twapOraclePkg;
    IUniswapV4MultiPoolTwapOracle internal twapOracle;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        if (address(weth) == address(0)) {
            weth = IWETH(address(new WETH9()));
        }
        poolManager = new PoolManager(address(this));
        twapOracleFacet = create3Factory.deployUniswapV4MultiPoolTwapOracleFacet();
        twapOraclePkg =
            create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(twapOracleFacet, diamondPackageFactory);
        twapOracle = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)})
        );
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();
        uniswapV4StandardExchangeOutQueryFacet = create3Factory.deployUniswapV4StandardExchangeOutQueryFacet();
        uniswapV4StandardExchangeLiquidReserveFacet = create3Factory.deployUniswapV4StandardExchangeLiquidReserveFacet();
        uniswapV4StandardExchangeInMultiFacet = create3Factory.deployUniswapV4StandardExchangeInMultiFacet();
        uniswapV4StandardExchangeInMultiQueryFacet = create3Factory.deployUniswapV4StandardExchangeInMultiQueryFacet();
        uniswapV4StandardExchangeOutMultiFacet = create3Factory.deployUniswapV4StandardExchangeOutMultiFacet();
        uniswapV4StandardExchangeOutMultiQueryFacet = create3Factory.deployUniswapV4StandardExchangeOutMultiQueryFacet();

        vm.startPrank(owner);
        // Type default 20% for V4 liquid-reserve fee type id (D5–D8 / H4).
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultLiquidReservePercentageOfTypeId(
                type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, DEFAULT_V4_LIQUID_RESERVE_PCT
            );

        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit =
            UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(_univ4SePkgInitCore());
        pkgInit = UniswapV4_Component_FactoryService.attachTwapOracle(pkgInit, twapOracle);
        pkgInit = UniswapV4_Component_FactoryService.attachUniswapV4StandardExchangeMultiFacets(
            pkgInit,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        uniswapV4StandardExchangeDFPkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(pkgInit);
        vm.stopPrank();
    }

    function _univ4SePkgInitCore()
        internal
        view
        returns (UniswapV4_Component_FactoryService.Univ4SePkgInitCore memory a)
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
