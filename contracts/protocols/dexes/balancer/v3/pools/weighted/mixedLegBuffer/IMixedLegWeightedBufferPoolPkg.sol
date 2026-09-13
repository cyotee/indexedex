// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";

interface IMixedLegWeightedBufferPoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /**
     * @dev Token layout: unpairedCount unpaired tokens + pairCount buffer/share pairs.
     *      Require 2 <= unpairedCount + 2*pairCount <= 8.
     * @dev weights length == tokenCount, in Balancer address-sorted order of the final token list.
     * @dev unpairedRateProviders: address(0) => TokenType.STANDARD; non-zero => WITH_RATE.
     * @dev pairRateProviders: address(0) => deploy default SE rate provider for (vault, bufferToken).
     * @dev Unpaired tokens must not equal any pair buffer or share (Balancer forbids duplicates).
     */
    struct PkgInit {
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet balancerV3VaultAwareFacet;
        IFacet betterBalancerV3PoolTokenFacet;
        IFacet defaultPoolInfoFacet;
        IFacet standardSwapFeePercentageBoundsFacet;
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet;
        IFacet balancerV3AuthenticationFacet;
        IFacet bufferPoolFacet;
        IFacet poolLiquidityFacet;
        IFacet hookFacet;
        IVaultRegistryDeployment vaultRegistry;
        IVaultFeeOracleQuery vaultFeeOracle;
        IVault balancerV3Vault;
        IDiamondPackageCallBackFactory diamondFactory;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
    }

    struct PkgArgs {
        uint8 unpairedCount;
        IERC20[] unpairedTokens;
        IRateProvider[] unpairedRateProviders;
        uint8 pairCount;
        IERC20[] bufferTokens;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] pairRateProviders;
        uint256[] weights;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool);
}
