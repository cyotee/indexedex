// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";

contract TestBase_UniswapV4StandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    uint256 internal constant DEFAULT_V4_LIQUID_RESERVE_PCT = 0.2e18;

    PoolManager internal poolManager;
    IFacet internal uniswapV4StandardExchangeInFacet;
    IFacet internal uniswapV4StandardExchangeInQueryFacet;
    IFacet internal uniswapV4StandardExchangePositionImportFacet;
    IFacet internal uniswapV4StandardExchangeOutFacet;
    IFacet internal uniswapV4StandardExchangeOutQueryFacet;
    IFacet internal uniswapV4StandardExchangeLiquidReserveFacet;
    IUniswapV4StandardExchangeDFPkg internal uniswapV4StandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        poolManager = new PoolManager(address(this));
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();
        uniswapV4StandardExchangeOutQueryFacet = create3Factory.deployUniswapV4StandardExchangeOutQueryFacet();
        uniswapV4StandardExchangeLiquidReserveFacet = create3Factory.deployUniswapV4StandardExchangeLiquidReserveFacet();

        vm.startPrank(owner);
        // Type default 20% for V4 liquid-reserve fee type id (D5–D8 / H4).
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultLiquidReservePercentageOfTypeId(
                type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, DEFAULT_V4_LIQUID_RESERVE_PCT
            );

        uniswapV4StandardExchangeDFPkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV4StandardExchangePkgInit(
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
                indexedexManager,
                indexedexManager,
                permit2,
                poolManager
            )
        );
        vm.stopPrank();
    }
}
