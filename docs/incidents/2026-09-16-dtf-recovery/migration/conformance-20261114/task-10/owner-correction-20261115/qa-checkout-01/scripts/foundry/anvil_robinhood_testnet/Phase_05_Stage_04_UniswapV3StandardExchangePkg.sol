// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {
    UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";

/// @title Phase_05_Stage_04_UniswapV3StandardExchangePkg
/// @notice Uni V3 FullSpread SE DFPkg. Binds live v3Factory from Phase 01 Stage 04. No SE instances.
library Phase_05_Stage_04_UniswapV3StandardExchangePkg {
    using UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService for IIndexedexManagerProxy;

    function execute(LaunchState storage s) internal {
        require(s.v3Factory != address(0) && s.v3Factory.code.length > 0, "Phase 05-04: v3Factory");
        IFacet inFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInFacet();
        IFacet inQueryFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet();
        IFacet outFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutFacet();
        IFacet outQueryFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet();
        IFacet posImportFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet();
        IFacet liquidReserveFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet();
        IFacet inMultiFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInMultiFacet();
        IFacet inMultiQueryFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet();
        IFacet outMultiFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiFacet();
        IFacet outMultiQueryFacet = s.create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet();
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.uniswapV3StandardExchangeInFacet = inFacet;
        init_.uniswapV3StandardExchangeInQueryFacet = inQueryFacet;
        init_.uniswapV3StandardExchangeOutFacet = outFacet;
        init_.uniswapV3StandardExchangeOutQueryFacet = outQueryFacet;
        init_.uniswapV3StandardExchangePositionImportFacet = posImportFacet;
        init_.uniswapV3StandardExchangeLiquidReserveFacet = liquidReserveFacet;
        init_ = UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.attachUniswapV3FullSpreadStandardExchangeVaultMultiFacets(
            init_, inMultiFacet, inMultiQueryFacet, outMultiFacet, outMultiQueryFacet
        );
        init_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = IVaultRegistryDeployment(address(s.indexedexManager));
        init_.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        init_.uniswapV3Factory = IUniswapV3Factory(s.v3Factory);
        s.uniV3SePkg = address(s.indexedexManager.deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(init_));
    }
}
