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
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

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

        // 5. Initialize to match the buffer pool's effective reserves, then equalize fees.
        _initReferencePool();
        _equalizeFees();
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

    /* --------------------------- Index / reserve reads --------------------------- */

    /// @dev Returns (ttaIndex, sharesIndex) for any 2-token pool by matching the TTA address.
    function _poolTokenIndices(address pool) internal view returns (uint256 ttaIdx, uint256 sharesIdx) {
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(pool);
        if (address(tokens[0]) == address(tta)) {
            (ttaIdx, sharesIdx) = (0, 1);
        } else {
            (ttaIdx, sharesIdx) = (1, 0);
        }
    }

    /// @dev Buffer pool's EFFECTIVE curve reserves: virtualTTA on the TTA side and the
    ///      rate-scaled live shares balance on the shares side (the values its onSwap math sees).
    function bufferEffectiveReserves() public view returns (uint256 ttaReserve, uint256 sharesReserve) {
        (, uint256 sharesIdx) = _poolTokenIndices(bufferPool);
        uint256[] memory live = vault.getCurrentLiveBalances(bufferPool);
        ttaReserve = IStandardExchangeBufferPool(bufferPool).virtualTTA();
        sharesReserve = live[sharesIdx];
    }

    /// @dev Reference pool live (rate-scaled, 18-dec) reserves, reindexed to (tta, shares).
    function referenceReserves() public view returns (uint256 ttaReserve, uint256 sharesReserve) {
        (uint256 ttaIdx, uint256 sharesIdx) = _poolTokenIndices(referencePool);
        uint256[] memory live = vault.getCurrentLiveBalances(referencePool);
        ttaReserve = live[ttaIdx];
        sharesReserve = live[sharesIdx];
    }

    /* ----------------------------- Matched init ----------------------------- */

    /// @dev Reference pool RAW init amounts that reproduce the buffer pool's effective reserves:
    ///      raw TTA = virtualTTA (STANDARD => raw == live); raw shares = buffer pool RAW shares
    ///      (WITH_RATE, same provider => identical scaled live balance).
    function _referenceInitAmounts() internal view returns (uint256 rawTTA, uint256 rawShares) {
        (, uint256 bufSharesIdx) = _poolTokenIndices(bufferPool);
        (,, uint256[] memory bufRaw,) = bv3Vault.getPoolTokenInfo(bufferPool);
        rawTTA = IStandardExchangeBufferPool(bufferPool).virtualTTA();
        rawShares = bufRaw[bufSharesIdx];
    }

    function _initReferencePool() internal virtual {
        (uint256 rawTTA, uint256 rawShares) = _referenceInitAmounts();

        // Acquire tokens for alice: DAI for the TTA side, SE shares for the shares side.
        mintTTA(alice, rawTTA);
        // Acquire comfortably more shares than needed (identical conditions to the buffer seed),
        // then initialize with the exact target amount.
        uint256 sharesAcquired = mintShares(alice, INITIAL_SHARES_RAW * 3);
        require(sharesAcquired >= rawShares, "ref init: insufficient shares acquired");

        (uint256 ttaIdx, uint256 sharesIdx) = _poolTokenIndices(referencePool);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(referencePool);
        uint256[] memory amounts = new uint256[](2);
        amounts[ttaIdx] = rawTTA;
        amounts[sharesIdx] = rawShares;

        vm.startPrank(alice);
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.initialize(referencePool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    /* ----------------------------- Swap helpers ----------------------------- */

    /// @dev EXACT_IN single-token swap through the BV3 RouterMock against the REFERENCE pool.
    function swapReferenceExactIn(
        address user,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        vm.startPrank(user);
        amountOut = router.swapSingleTokenExactIn(
            referencePool,
            tokenIn,
            tokenOut,
            amountIn,
            0,               // minAmountOut
            block.timestamp, // deadline
            false,           // wethIsEth
            bytes("")        // userData
        );
        vm.stopPrank();
    }

    // Public getters so behavior libraries can read the internal-constant tolerances.
    function ABS_TOL_() public pure returns (uint256) { return ABS_TOL; }
    function REL_TOL_() public pure returns (uint256) { return REL_TOL; }

    /// @dev Force both pools to the same static swap fee so swap outputs compare on the curve alone.
    ///      The mock's manualSetStaticSwapFeePercentage still validates against each pool's swap-fee
    ///      bounds (min == 1e12), so 0 is rejected; the shared minimum is used on BOTH pools instead.
    uint256 internal constant EQUALIZED_SWAP_FEE = 1e12; // 0.0001% — the shared min bound

    function _equalizeFees() internal virtual {
        vault.manualSetStaticSwapFeePercentage(bufferPool, EQUALIZED_SWAP_FEE);
        vault.manualSetStaticSwapFeePercentage(referencePool, EQUALIZED_SWAP_FEE);
    }
}
