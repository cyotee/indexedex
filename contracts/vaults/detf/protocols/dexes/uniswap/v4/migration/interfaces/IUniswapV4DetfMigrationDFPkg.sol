// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4DetfMigrationRewardTokenDFPkg} from
    "../sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";

/// @notice Distinct registered parent package; all deployment schemas remain interface-owned.
interface IUniswapV4DetfMigrationDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /// @dev baseInit reuses the exact existing dependency schema. Its productFacets order is
    /// exchange, bond, maintenance, claim/wiring, query. Select Migration policy implementations
    /// wherever required, plus the genuine Migration bond/receipt/SY packages, never placeholders.
    /// migrationFacet supplies retained donation/query selectors; allocationFacet supplies only
    /// the five removable administration selectors. Each selector has exactly one owning facet.
    struct PkgInit {
        IUniswapV4DetfDFPkg.PkgInit baseInit;
        IFacet ownableFacet;
        IFacet migrationFacet;
        IFacet allocationFacet;
        IFacet recoveryFacet;
        IFacet claimVaultAllocationFacet;
        IUniswapV4DetfMigrationRewardTokenDFPkg rewardTokenPkg;
    }

    /// @dev Canonical encoding and salt include every field, clearing only baseArgs.hook in the
    /// salt copy for hook prediction. owner must be nonzero; buffer keeps actual Crane semantics.
    /// weth/originalDtf are nonzero distinct deployment bindings, not prices or mutable routes.
    /// Snapshot Source.subject and Source.feeOracle come from the proxy and installed package.
    /// RT name/symbol are derived from baseArgs metadata; its decimals and gon quantum are fixed.
    struct PkgArgs {
        IUniswapV4Detf.PkgArgs baseArgs;
        address owner;
        uint256 ownershipBufferPeriod;
        address weth;
        address originalDtf;
    }

    error InvalidMigrationPackageArguments();
    error InvalidMigrationChild(address child);

    /// @notice Registry-mediated once-only initialization and atomic child completion.
    /// @dev Wire bond, receipt, then RT, then both SYs. Validate reciprocal fixed identities;
    /// remove the factory's temporary post-deploy hook before returning a completed instance.
    function deployVault(PkgArgs memory args_) external returns (address vault_);
}
