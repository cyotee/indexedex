// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {ComposedStableCommonDetfRepo as Repo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {IStablePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol";

interface IComposedStableCommonDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error InvalidPackageArguments();
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet composedStableCommonDetfBondingFacet;
        IFacet composedStableCommonDetfExchangeInFacet;
        IFacet composedStableCommonDetfExchangeOutQueryFacet;
        IFacet rebasingDetfTokenPricingFacet;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery feeOracle;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVault balancerV3Vault;
        IWeightedPoolFactory weightedPoolFactory;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDETFSYDFPkg syPkg;
    }
    struct PkgArgs {
        string name;
        string symbol;
        IStablePool stablePool;
        IStablePool commonPool;
        IERC20 rateAsset;
        IStandardExchangeIn stablePoolExitPricer;
        IStandardExchangeIn commonPoolExitPricer;
        uint256[3] reserveWeights; // DETF, stable BPT, common BPT; retain the configured host weights.
        // Whole stable/common BPT per whole purchased DETF, each scaled by 1e18.
        uint256[2] openingDetfPrices;
        // Proportional native seed amounts: DETF (9), stable BPT (18), common BPT (18).
        uint256[3] reserveSeedAmounts;
        uint256 reserveSwapFeePercentage;
        uint256 mintThreshold;
        uint256 burnThreshold;
        uint256 expansionClosureRatePerSecond;
        Repo.RouteConfig[] routes;
        address creator;
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        string reserveName;
        string reserveSymbol;
    }
    function deployVault(PkgArgs memory args) external returns (address);
}
