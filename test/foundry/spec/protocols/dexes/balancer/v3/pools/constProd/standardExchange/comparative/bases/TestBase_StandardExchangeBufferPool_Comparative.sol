// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IBalancerV3ConstantProductPoolStandardVaultPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {
    BalancerV3ConstantProductPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";

import {
    TestBase_StandardExchangeBufferPool_UniswapV2
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol";

/**
 * @title TestBase_StandardExchangeBufferPool_Comparative
 * @notice Extends the Uniswap V2 buffer-pool fixture with a real Balancer V3 constant-product pool
 *         over the same (TTA, shares) tokens and the same rate provider, for A/B comparison.
 */
abstract contract TestBase_StandardExchangeBufferPool_Comparative is
    TestBase_StandardExchangeBufferPool_UniswapV2
{
    /// @dev Relative tolerance for swap-output comparison (1e18 == 100%); 1e12 == 1e-6.
    uint256 internal constant REL_TOL = 1e12;
    /// @dev Absolute tolerance (wei) for swap-output comparison.
    uint256 internal constant ABS_TOL = 1e3;

    IFacet internal balancerV3ConstProdPoolFacet;
    IBalancerV3ConstantProductPoolStandardVaultPkg internal refPoolPkg;
    address public referencePool;

    function setUp() public virtual override {
        super.setUp();
        _deployReferencePool();
    }

    /* ----------------------------- Reference pool ----------------------------- */

    function _deployReferencePool() internal virtual {
        // 1. Deploy the constant-product pool facet (shared facets already deployed by parent).
        balancerV3ConstProdPoolFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(create3Factory);

        // 2. Build PkgInit reusing parent's shared facets + same vault/factory/registry.
        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.balancerV3ConstProdPoolFacet = balancerV3ConstProdPoolFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = bv3Vault;
        pkgInit.diamondFactory = diamondPackageFactory;

        // 3. Deploy the package via the vault registry (owner-gated, mirrors buffer pool pkg deploy).
        vm.startPrank(owner);
        refPoolPkg = BalancerV3ConstantProductPool_FactoryService
            .deployBalancerV3ConstantProductPoolStandardVaultPkg(
                IVaultRegistryDeployment(address(indexedexManager)),
                pkgInit
            );
        vm.stopPrank();
        vm.label(address(refPoolPkg), "RefConstProdPkg");

        // 4. Deploy the reference pool over (TTA, shares) with the same rate provider on shares.
        referencePool = refPoolPkg.deployVault(_buildReferenceTokenConfigs(), address(0));
        vm.label(referencePool, "ReferenceConstProdPool");
        approveForPool(IERC20(referencePool));
    }

    function _buildReferenceTokenConfigs() internal view returns (TokenConfig[] memory tc) {
        tc = new TokenConfig[](2);
        (uint256 ttaIdx, uint256 sharesIdx) = address(tta) < address(shares) ? (0, 1) : (1, 0);
        tc[ttaIdx] = TokenConfig({
            token: tta,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tc[sharesIdx] = TokenConfig({
            token: shares,
            tokenType: TokenType.WITH_RATE,
            rateProvider: seRateProvider,
            paysYieldFees: false
        });
    }
}
