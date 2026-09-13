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

interface IMixedBufferMultiVaultStablePoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /**
     * @dev T = unpairedCount + 1 + vaultCount, require U>=1, 1<=N<=3, 3<=T<=5 and vaultCount in 1..3.
     * @dev amplificationParameter: raw amp fixed at deploy. Balancer address-sorted tokens.
     * @dev unpairedRateProviders / vaultShareRateProviders: address(0) => STANDARD; non-zero => WITH_RATE.
     *      Package NEVER auto-deploys default SE rate providers (L17).
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
        IStandardExchangeRateProviderDFPkg rateProviderPkg; // optional; never auto-used on zero args
    }

    struct PkgArgs {
        uint8 unpairedCount;
        IERC20[] unpairedTokens;
        IRateProvider[] unpairedRateProviders;
        IERC20 bufferToken;
        uint8 vaultCount;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] vaultShareRateProviders;
        uint256 amplificationParameter;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool);
}
