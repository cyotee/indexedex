// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface IUniswapV2StandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        // IFacet erc4626BasicVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        // IFacet erc4626StandardVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet uniswapV2StandardExchangeInFacet;
        IFacet uniswapV2StandardExchangeOutFacet;
        IFacet uniswapV2StandardExchangeQueryFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IUniswapV2Factory uniswapV2Factory;
        IUniswapV2Router uniswapV2Router;
    }

    struct PkgArgs {
        IUniswapV2Pair reserveAsset;
    }

    struct DeployWithPoolResult {
        bool pairExists;
        uint256 proportionalA;
        uint256 proportionalB;
        uint256 expectedLP;
    }

    struct DeployWithPoolParams {
        IERC20 tokenA;
        uint256 tokenAAmount;
        IERC20 tokenB;
        uint256 tokenBAmount;
        address recipient;
    }

    error NotCalledByRegistry(address caller);

    error PairCreationFailed();

    error RecipientRequiredForDeposit();

    function deployVault(IUniswapV2Pair pool) external returns (address vault);

    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        external
        returns (address vault);

    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        external
        view
        returns (DeployWithPoolResult memory result);
}
