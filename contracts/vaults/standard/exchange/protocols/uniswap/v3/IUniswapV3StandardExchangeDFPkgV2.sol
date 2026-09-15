// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface IUniswapV3StandardExchangeDFPkgV2 is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error InvalidPoolFactory(address poolFactory, address expectedFactory);

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet uniswapV3StandardExchangeInFacet;
        IFacet uniswapV3StandardExchangeInQueryFacet;
        IFacet uniswapV3StandardExchangeOutFacet;
        IFacet uniswapV3StandardExchangeOutQueryFacet;
        IFacet uniswapV3StandardExchangePositionImportFacet;
        IFacet uniswapV3StandardExchangeLiquidReserveFacet;
        IFacet uniswapV3StandardExchangeInMultiFacet;
        IFacet uniswapV3StandardExchangeInMultiQueryFacet;
        IFacet uniswapV3StandardExchangeOutMultiFacet;
        IFacet uniswapV3StandardExchangeOutMultiQueryFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IUniswapV3Factory uniswapV3Factory;
    }

    struct PkgArgs {
        IUniswapV3Pool pool;
    }

    function deployVault(IUniswapV3Pool pool) external returns (address vault);
}
