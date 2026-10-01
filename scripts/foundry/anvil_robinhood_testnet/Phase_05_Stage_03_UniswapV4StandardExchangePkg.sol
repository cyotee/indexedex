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
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol";

/// @title Phase_05_Stage_03_UniswapV4StandardExchangePkg
/// @notice Hookless V4 SE package for the zero-hook testnet pools.
/// @dev `PkgInit.twapOracle` is the canonical instance from Phase 05 Stage 02.
/// @dev Family-qualified salts do not reuse the legacy package or its facets.
library Phase_05_Stage_03_UniswapV4StandardExchangePkg {
    using UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService for IIndexedexManagerProxy;

    function execute(LaunchState storage s) internal {
        require(address(s.twapOracle) != address(0) && address(s.twapOracle).code.length > 0, "Phase 05-03: twapOracle");
        IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = s.erc20Facet;
        pkgInit.erc5267Facet = s.erc5267Facet;
        pkgInit.erc2612Facet = s.erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInFacet();
        pkgInit.uniswapV4StandardExchangeInQueryFacet = s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet();
        pkgInit.uniswapV4StandardExchangePositionImportFacet =
            s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet();
        pkgInit.uniswapV4StandardExchangeOutFacet = s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet();
        pkgInit.uniswapV4StandardExchangeOutQueryFacet = s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet();
        pkgInit.uniswapV4StandardExchangeLiquidReserveFacet =
            s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet();
        pkgInit.uniswapV4StandardExchangeInMultiFacet = s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet();
        pkgInit.uniswapV4StandardExchangeInMultiQueryFacet =
            s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet();
        pkgInit.uniswapV4StandardExchangeOutMultiFacet = s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet();
        pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet =
            s.create3Factory.deployUniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet();
        pkgInit.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(s.indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(s.indexedexManager));
        pkgInit.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        pkgInit.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        pkgInit.positionManager = IPositionManager(RobinhoodCanonicalLib.positionManagerV4());
        pkgInit.twapOracle = s.twapOracle;
        pkgInit.weth = IWETH(RobinhoodCanonicalLib.weth());
        s.uniV4SePkg = s.indexedexManager.deployUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(pkgInit);
    }
}
