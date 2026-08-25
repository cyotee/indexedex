// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";

/// @title Phase_05_Stage_03_UniswapV4StandardExchangePkg
/// @notice Uni V4 SE DFPkg + In/Out/Query/PositionImport/LiquidReserve/Multi facets.
/// @dev `PkgInit.twapOracle` is the canonical instance from Phase 05 Stage 02.
/// @dev Facet and package CREATE3 salts include `wethWrap`. Name-only salts on 4663 still
///      hold pre-wrap bytecode; FORCE=1 if JSON `uniV4SePkg` already has code.
library Phase_05_Stage_03_UniswapV4StandardExchangePkg {
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    function execute(LaunchState storage s) internal {
        require(address(s.twapOracle) != address(0) && address(s.twapOracle).code.length > 0, "Phase 05-03: twapOracle");
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = s.erc20Facet;
        pkgInit.erc5267Facet = s.erc5267Facet;
        pkgInit.erc2612Facet = s.erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = s.create3Factory.deployUniswapV4StandardExchangeInFacet();
        pkgInit.uniswapV4StandardExchangeInQueryFacet = s.create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        pkgInit.uniswapV4StandardExchangePositionImportFacet =
            s.create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        pkgInit.uniswapV4StandardExchangeOutFacet = s.create3Factory.deployUniswapV4StandardExchangeOutFacet();
        pkgInit.uniswapV4StandardExchangeOutQueryFacet = s.create3Factory.deployUniswapV4StandardExchangeOutQueryFacet();
        pkgInit.uniswapV4StandardExchangeLiquidReserveFacet =
            s.create3Factory.deployUniswapV4StandardExchangeLiquidReserveFacet();
        pkgInit.uniswapV4StandardExchangeInMultiFacet = s.create3Factory.deployUniswapV4StandardExchangeInMultiFacet();
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet =
            s.create3Factory.deployUniswapV4StandardExchangeInMultiQueryFacet();
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = s.create3Factory.deployUniswapV4StandardExchangeOutMultiFacet();
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet =
            s.create3Factory.deployUniswapV4StandardExchangeOutMultiQueryFacet();
        pkgInit.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(s.indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(s.indexedexManager));
        pkgInit.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        pkgInit.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        pkgInit.positionManager = IPositionManager(RobinhoodCanonicalLib.positionManagerV4());
        pkgInit.twapOracle = s.twapOracle;
        pkgInit.weth = IWETH(RobinhoodCanonicalLib.weth());
        s.uniV4SePkg = s.indexedexManager.deployUniswapV4StandardExchangeDFPkg(pkgInit);
    }
}
