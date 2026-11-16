// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICamelotV2Router} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotV2Router.sol";
import {ICamelotFactory} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotFactory.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface ICamelotV2StandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);

    error PoolMustNotBeStable(ICamelotPair pool);

    error ZeroAmountForNonZeroRecipient();

    error InsufficientLiquidity();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet erc4626Facet;
        // IFacet erc4626BasicVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        // IFacet erc4626StandardVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet camelotV2StandardExchangeInFacet;
        IFacet camelotV2StandardExchangeOutFacet;
        IFacet camelotV2StandardExchangeQueryFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        ICamelotFactory camelotV2Factory;
        ICamelotV2Router camelotV2Router;
    }

    struct PkgArgs {
        ICamelotPair reserveAsset;
    }

    struct PreviewDeployVaultResult {
        bool pairExists;
        uint256 proportionalA;
        uint256 proportionalB;
        /// @dev Upper-bound estimate; actual LP minted will be slightly less due to Camelot's `_mintFee()`.
        uint256 expectedLP;
    }

    event PairCreated(address indexed tokenA, address indexed tokenB, address pair);

    event VaultDeployedWithDeposit(
        address indexed vault, address indexed pair, address indexed recipient, uint256 lpAmount, uint256 vaultShares
    );

    function deployVault(ICamelotPair pool) external returns (address vault);

    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        external
        returns (address vault);

    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        external
        view
        returns (PreviewDeployVaultResult memory result);
}
