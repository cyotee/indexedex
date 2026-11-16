// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";

/// @title IMultiVaultWeightedDetfDFPkg
interface IMultiVaultWeightedDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error UnregisteredVault(address vault);
    error InvalidVaultShare(uint256 index, address vault, address vaultShare);
    error InvalidPackageArguments();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet bondingFacet;
        IFacet infoFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVault balancerV3Vault;
        IWeightedPoolFactory weightedPoolFactory;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDETFSYDFPkg syPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Per-instance args. Arrays must share length N in [1,7].
    /// @dev `vaultShares[i]` must be the registered SE share of `vaults[i]` (the vault diamond ERC-20).
    /// @dev `address(0)` does **not** alias to `vaults[i]`. Hostile or missing share reverts.
    /// @dev `rateProviders`/`rateAssets` zero = unrated leg.
    /// @dev `weightDetf + sum(vaultWeights) == 1e18`; each weight > 0. Zero weightDetf not allowed.
    /// @dev Every instance has mandatory price gates and uncapped fixed eight-hour expansion.
    struct PkgArgs {
        string name;
        string symbol;
        IStandardExchangeProxy[] vaults;
        IERC20[] vaultShares;
        IRateProvider[] rateProviders;
        IERC20[] rateAssets;
        uint256 weightDetf;
        uint256[] vaultWeights;
        uint256 mintThreshold; // 0 → 1.05e18
        uint256 burnThreshold; // 0 → 0.95e18
        uint256 expansionClosureRatePerSecond; // 0 → default
        address creator; // D26; 0 → feeTo owns id 2 (D21)
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        string reserveName;
        string reserveSymbol;
    }

    function deployVault(PkgArgs memory args) external returns (address vault);
}
