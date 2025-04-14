// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {AerodromeUtils} from "@crane/contracts/utils/math/AerodromeUtils.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {BaseProtocolDETFPreviewHelpers} from "contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol";
import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {AerodromeDualEmbeddedDETFCommon} from 'contracts/protocols/dexes/aerodrome/v1/vaults/exchange/standard/detf/dual/embedded/AerodromeDualEmbeddedDETFCommon.sol';

/**
 * @title BaseProtocolDETFCommon
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Common functionality for Protocol DETF exchange operations.
 * @dev Contains shared logic for:
 *      - Synthetic price oracle calculation
 *      - Pool state loading
 *      - Token route validation
 *      - Seigniorage mechanics
 */
abstract contract BaseProtocolDETFCommon is AerodromeDualEmbeddedDETFCommon {
    using BetterSafeERC20 for IERC20;
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;
    using FixedPoint for uint256;

    /* ---------------------------------------------------------------------- */
    /*                          Balancer Conversions                           */
    /* ---------------------------------------------------------------------- */

    function _toLiveScaled18(uint256 rawAmount_, TokenInfo memory info_) internal view returns (uint256 scaled18_) {
        // NOTE: This helper is intentionally minimal: vault share tokens in this protocol are assumed 18 decimals.
        // If a rateProvider exists, apply it to convert raw -> liveScaled18.
        // If not, 1:1.
        uint256 rate = FixedPoint.ONE;
        if (address(info_.rateProvider) != address(0)) {
            rate = info_.rateProvider.getRate();
        }

        // vault tokens use 18 decimals so no decimal scaling factor is applied here.
        scaled18_ = rawAmount_.mulDown(rate);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Memory Structures                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Pool reserve data for synthetic price calculation
    struct PoolReserves {
        /// @notice CHIR reserve in CHIR/WETH pool
        uint256 chirInWethPool;
        /// @notice WETH reserve in CHIR/WETH pool
        uint256 wethReserve;
        /// @notice CHIR reserve in RICH/CHIR pool
        uint256 chirInRichPool;
        /// @notice RICH reserve in RICH/CHIR pool
        uint256 richReserve;
        /// @notice Total CHIR supply
        uint256 chirTotalSupply;

        /// @notice CHIR/WETH Aerodrome LP total supply
        uint256 chirWethLpTotalSupply;
        /// @notice CHIR/WETH Aerodrome swap fee percent (1/10000)
        uint256 chirWethFeePercent;

        /// @notice RICH/CHIR Aerodrome LP total supply
        uint256 richChirLpTotalSupply;
        /// @notice RICH/CHIR Aerodrome swap fee percent (1/10000)
        uint256 richChirFeePercent;

        /// @notice Reserve pool weight of CHIR/WETH vault token (WAD)
        uint256 chirWethVaultWeight;
        /// @notice Reserve pool weight of RICH/CHIR vault token (WAD)
        uint256 richChirVaultWeight;
    }

    /// @notice Balancer V3 reserve pool state data
    struct ReservePoolData {
        IVault balV3Vault;
        IWeightedPool reservePool;
        uint256 reservePoolSwapFee;
        uint256 chirWethVaultIndex;
        uint256 chirWethVaultRawBalance;
        uint256 chirWethVaultWeight;
        uint256 richChirVaultIndex;
        uint256 richChirVaultRawBalance;
        uint256 richChirVaultWeight;
        uint256 resPoolTotalSupply;
        uint256[] weightsArray;
    }

    /// @notice Seigniorage calculation outputs
    struct SeigniorageCalc {
        uint256 syntheticPrice;
        uint256 grossSeigniorage;
        uint256 discountMargin;
        uint256 profitMargin;
        uint256 seigniorageTokens;
        uint256 reducedFeePercent;
    }

    struct ChirWethLiquidityQuote {
        address pool;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        bool stable;
    }

    /* ---------------------------------------------------------------------- */
    /*                       Synthetic Price Oracle                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Loads pool reserves for synthetic price calculation.
     * @param layout_ Storage layout reference
     * @param reserves_ Memory struct to populate
     */
    function _loadPoolReserves(BaseProtocolDETFRepo.Storage storage layout_, PoolReserves memory reserves_)
        internal
        view
        virtual
    {
        // Get CHIR/WETH Aerodrome pool reserves
        IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layout_.chirWethVault)).asset()));
        reserves_.chirWethLpTotalSupply = IERC20(address(chirWethPool)).totalSupply();
        reserves_.chirWethFeePercent = _poolSwapFeePercent(address(chirWethPool));
        (uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();
        address token0 = chirWethPool.token0();

        if (token0 == address(this)) {
            reserves_.chirInWethPool = reserve0;
            reserves_.wethReserve = reserve1;
        } else {
            reserves_.chirInWethPool = reserve1;
            reserves_.wethReserve = reserve0;
        }

        // Get RICH/CHIR Aerodrome pool reserves
        IUniswapV2Pair richChirPool = IUniswapV2Pair(address(IERC4626(address(layout_.richChirVault)).asset()));
        reserves_.richChirLpTotalSupply = IERC20(address(richChirPool)).totalSupply();
        reserves_.richChirFeePercent = _poolSwapFeePercent(address(richChirPool));
        (reserve0, reserve1,) = richChirPool.getReserves();
        token0 = richChirPool.token0();

        if (token0 == address(layout_.richToken)) {
            reserves_.richReserve = reserve0;
            reserves_.chirInRichPool = reserve1;
        } else {
            reserves_.richReserve = reserve1;
            reserves_.chirInRichPool = reserve0;
        }

        reserves_.chirTotalSupply = ERC20Repo._totalSupply();

        // Cache reserve pool weights (80/20)
        reserves_.chirWethVaultWeight = layout_.chirWethVaultWeight;
        reserves_.richChirVaultWeight = layout_.richChirVaultWeight;
    }

    /**
     * @notice Calculates the synthetic spot price (RICH per 1 WETH).
        * @dev Prices the DETF-owned reserve-pool position by:
        *      1. Splitting total CHIR supply across the CHIR/WETH and RICH/CHIR pools
        *         proportional to each pool's CHIR reserves.
        *      2. Quoting a synthetic zap-out of the DETF-owned reserve-pool balances into
        *         WETH and RICH via the underlying exchange pools.
        *      3. Combining those synthetic WETH and RICH values with Balancer 80/20
        *         weighted-pool spot-price math.
     *
     *      Interpretation:
     *      - synthetic_price > 1: RICH backing strong vs WETH backing -> allow minting
     *      - synthetic_price < 1: WETH backing strong -> allow redemption
     *
     * @param reserves_ Pool reserves data
     * @return syntheticPrice The synthetic price (1e18 = peg)
     */
    function _calcSyntheticPrice(PoolReserves memory reserves_) internal view returns (uint256 syntheticPrice) {
        // Peg oracle spec (TASK.md):
        // 1) Read raw AMM reserves (already loaded)
        // 2) Split total CHIR supply across pools proportional to CHIR reserves
        // 3) Synthetic zap-out quotes for the DETF-owned reserve-pool position using
        //    AerodromeUtils._quoteWithdrawSwapWithFee
        // 4) Combine those synthetic values with Balancer 80/20 weighted pool math to
        //    get RICH per WETH

        uint256 chirTotalInPools = reserves_.chirInWethPool + reserves_.chirInRichPool;
        // if (chirTotalInPools == 0 || reserves_.chirTotalSupply == 0) {
        //     return ONE_WAD;
        // }

        // CHIR proportional split (mulDivDown)
        // Used to calculate the price using the CHIR FDV.
        uint256 chirSynth_WC =
            BetterMath._mulDivDown(reserves_.chirTotalSupply, reserves_.chirInWethPool, chirTotalInPools);
        uint256 chirSynth_RC =
            BetterMath._mulDivDown(reserves_.chirTotalSupply, reserves_.chirInRichPool, chirTotalInPools);

        // 
        ReservePoolData memory resPoolData;
        // TokenInfo[] memory tokenInfo;
        uint256[] memory currentBalancesRaw;
        (/*tokenInfo*/, currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
        uint256 reservePoolBalance = resPoolData.balV3Vault.balanceOf(address(resPoolData.reservePool), address(this));

        // I have not idea why the compiler couldn't find this in BalancerV38020WeightedPoolMath.
        uint256[] memory ownedReserves = _calcProportionalAmountsOutGivenBptIn(
            // uint256[] memory balances,
            currentBalancesRaw,
            // uint256 totalSupply,
            resPoolData.resPoolTotalSupply,
            // uint256 bptIn
            reservePoolBalance
        );

        uint256 syntheticWethValue = AerodromeUtils._quoteWithdrawSwapWithFee(
            ownedReserves[resPoolData.chirWethVaultIndex],
            reserves_.chirWethLpTotalSupply,
            reserves_.wethReserve,
            chirSynth_WC,
            reserves_.chirWethFeePercent
        );

        uint256 syntheticRichValue = AerodromeUtils._quoteWithdrawSwapWithFee(
            ownedReserves[resPoolData.richChirVaultIndex],
            reserves_.richChirLpTotalSupply,
            reserves_.richReserve,
            chirSynth_RC,
            reserves_.richChirFeePercent
        );

        // If either synthetic value is zero, the pool is extremely imbalanced
        // This should not happen during normal operation - revert rather than return peg
        // to prevent incorrect minting/burning decisions
        if (syntheticWethValue == 0 || syntheticRichValue == 0) {
            revert PoolImbalanced(syntheticWethValue, syntheticRichValue);
        }

        // Combine using weighted pool spot price math.
        // Units: syntheticPrice = RICH per WETH (1e18 = 1.0)
        // if (reserves_.richChirVaultWeight == 0 || reserves_.chirWethVaultWeight == 0) {
        //     return ONE_WAD;
        // }

        syntheticPrice = BalancerV38020WeightedPoolMath.priceFromReserves(
            syntheticRichValue, syntheticWethValue, reserves_.richChirVaultWeight, reserves_.chirWethVaultWeight
        );
    }

    /**
     * @dev Proportional withdrawal: Amounts out given exact BPT in (RemoveLiquidityKind.PROPORTIONAL, no fees).
     * @param balances Current pool balances (scaled).
     * @param totalSupply Current total BPT supply.
     * @param bptIn Exact BPT burned.
     * @return amountsOut Proportional amounts out for each token (exact match to pool's raw calculation, rounded down).
     */
    function _calcProportionalAmountsOutGivenBptIn(
        uint256[] memory balances,
        uint256 totalSupply,
        uint256 bptIn
    )
        internal
        pure
        returns (uint256[] memory amountsOut)
    {
        if (bptIn == 0) return new uint256[](balances.length);
        require(bptIn <= totalSupply, "Exceeds total supply");

        amountsOut = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; ++i) {
            // Direct mulDivDown: (balances[i] * bptIn) / totalSupply floored – matches Balancer's raw calc
            amountsOut[i] = BetterMath._mulDivDown(balances[i], bptIn, totalSupply);
        }
    }

    /**
     * @notice Checks if minting is allowed based on synthetic price.
     * @param layout_ Storage layout reference
     * @param syntheticPrice_ Current synthetic price
     * @return allowed True if synthetic price is below the lower deadband threshold
     */
    function _isMintingAllowed(BaseProtocolDETFRepo.Storage storage layout_, uint256 syntheticPrice_)
        internal
        view
        returns (bool allowed)
    {
        return syntheticPrice_ < layout_.burnThreshold;
    }

    /**
     * @notice Checks if burning/redemption is allowed based on synthetic price.
     * @param layout_ Storage layout reference
     * @param syntheticPrice_ Current synthetic price
     * @return allowed True if synthetic price is above the upper deadband threshold
     */
    function _isBurningAllowed(BaseProtocolDETFRepo.Storage storage layout_, uint256 syntheticPrice_)
        internal
        view
        returns (bool allowed)
    {
        return syntheticPrice_ > layout_.mintThreshold;
    }

    /* ---------------------------------------------------------------------- */
    /*                         Pool State Loading                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Loads reserve pool state and returns Balancer token metadata.
     * @dev Returns raw balances from `IVaultExplorer.getPoolTokenInfo().balancesRaw`.
     *      Callers that need Balancer weighted math inputs must convert raw -> liveScaled18
     *      using `_toLiveScaled18` and (critically) also convert their `amountIn` to liveScaled18.
     */
    function _loadReservePoolDataWithTokenInfo(ReservePoolData memory resPoolData_)
        internal
        view
        returns (TokenInfo[] memory tokenInfo_, uint256[] memory currentBalancesRaw_)
    {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        resPoolData_.balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        resPoolData_.reservePool = IWeightedPool(address(ERC4626Repo._reserveAsset()));
        resPoolData_.reservePoolSwapFee =
            resPoolData_.balV3Vault.getStaticSwapFeePercentage(address(resPoolData_.reservePool));

        // Get raw balances + token metadata from Balancer V3 vault
        (, tokenInfo_, currentBalancesRaw_,) = resPoolData_.balV3Vault.getPoolTokenInfo(address(resPoolData_.reservePool));

        // Cache indices
        resPoolData_.chirWethVaultIndex = layout.chirWethVaultIndex;
        resPoolData_.richChirVaultIndex = layout.richChirVaultIndex;

        // Load balances
        resPoolData_.chirWethVaultRawBalance = currentBalancesRaw_[resPoolData_.chirWethVaultIndex];
        resPoolData_.richChirVaultRawBalance = currentBalancesRaw_[resPoolData_.richChirVaultIndex];

        // Load weights
        resPoolData_.chirWethVaultWeight = layout.chirWethVaultWeight;
        resPoolData_.richChirVaultWeight = layout.richChirVaultWeight;

        // Create weights array for pool math
        resPoolData_.weightsArray = new uint256[](2);
        resPoolData_.weightsArray[resPoolData_.chirWethVaultIndex] = resPoolData_.chirWethVaultWeight;
        resPoolData_.weightsArray[resPoolData_.richChirVaultIndex] = resPoolData_.richChirVaultWeight;

        // Load pool total supply
        resPoolData_.resPoolTotalSupply = resPoolData_.balV3Vault.totalSupply(address(resPoolData_.reservePool));
    }

    /**
     * @notice Loads the current state of the 80/20 reserve pool.
     * @dev IMPORTANT: returns raw balances from `IVaultExplorer.getPoolTokenInfo().balancesRaw`.
     *      Preview math that simulates vault token deposits/withdrawals must operate on raw vault token units.
     *      If rated/live-scaled balances are needed (e.g., for Balancer weighted math), callers must explicitly
     *      convert raw balances to liveScaled18 using the vault rates.
     * @param resPoolData_ Memory struct to populate with pool state
     * @param currentBalancesRaw_ Output array for raw balances
     */
    function _loadReservePoolData(ReservePoolData memory resPoolData_, uint256[] memory currentBalancesRaw_)
        internal
        view
        returns (uint256[] memory)
    {
        (, currentBalancesRaw_) = _loadReservePoolDataWithTokenInfo(resPoolData_);

        return currentBalancesRaw_;
    }

    /* ---------------------------------------------------------------------- */
    /*                   Aerodrome Compound State Simulation                  */
    /* ---------------------------------------------------------------------- */

    uint256 private constant AERO_FEE_DENOM = 10000;
    uint256 private constant COMPOUND_DUST_THRESHOLD = 1000;

    struct AeroCompoundSim {
        uint256 reserve0;
        uint256 reserve1;
        uint256 lpTotalSupply;
        uint256 compoundLP;
        uint256 swapFeePercent;
        address token0;
    }

    /**
     * @notice Previews vault shares accounting for Aerodrome fee compounding.
     * @dev The vault's previewExchangeIn calculates LP from the user's deposit
     *      using pre-compound pool reserves, but execution uses post-compound
     *      reserves (after _claimAndCompoundFees). This function adjusts the
     *      vault's estimate by the ratio of post-compound to pre-compound LP.
     * @param vault_ The Aerodrome vault (IStandardExchange)
     * @param tokenIn_ The token being deposited
     * @param amountIn_ The amount of tokenIn being deposited
     * @return vaultShares_ The expected vault shares after compound adjustment
     */
    function _previewVaultSharesPostCompound(IStandardExchange vault_, IERC20 tokenIn_, uint256 amountIn_)
        internal
        view
        virtual
        returns (uint256 vaultShares_)
    {
        address poolAddress = address(IERC4626(address(vault_)).asset());
        IPool pool = IPool(poolAddress);

        // Stable math requires the pool's token decimal scalars (10 ** decimals)
        (uint256 dec0, uint256 dec1,,,,,) = _poolMetadata(poolAddress);

        // Simulate compound to get post-compound pool state
        AeroCompoundSim memory sim = _buildCompoundSim(vault_);

        // When there is nothing to compound, the vault's native preview matches execution
        // more closely than the Aerodrome-specific simulation path.
        if (sim.compoundLP == 0) {
            return vault_.previewExchangeIn(tokenIn_, amountIn_, IERC20(address(vault_)));
        }

        // Calculate LP from the user's swap-deposit using the *simulated* post-compound reserves.
        // NOTE: pool.getAmountOut() reads the pool's current on-chain reserves, which may differ
        // from `sim` (post-compound). Using on-chain reserves here can make preview optimistic.
        uint256 lpMinted;
        {
            // Calculate optimal sale amount (same formula as router uses)
            bool token0In = address(tokenIn_) == sim.token0;
            uint256 reserveIn = token0In ? sim.reserve0 : sim.reserve1;
            uint256 reserveOut = token0In ? sim.reserve1 : sim.reserve0;
            uint256 saleAmt =
                ConstProdUtils._swapDepositSaleAmt(amountIn_, reserveIn, sim.swapFeePercent, AERO_FEE_DENOM);

            uint256 swapOut;
            if (_poolIsStable(poolAddress)) {
                // Mirror Aerodrome Pool.getAmountOut (stable path) using *simulated* reserves.
                // pool.getAmountOut() reads on-chain reserves, which can diverge from `sim`.
                uint256 amountInAfterFee = saleAmt - ((saleAmt * sim.swapFeePercent) / AERO_FEE_DENOM);
                swapOut = _aerodromeStableAmountOut(amountInAfterFee, token0In, sim.reserve0, sim.reserve1, dec0, dec1);
            } else {
                // Mirror Aerodrome Pool.getAmountOut (volatile path)
                if (saleAmt == 0 || sim.swapFeePercent >= AERO_FEE_DENOM) {
                    swapOut = 0;
                } else {
                    uint256 amountInAfterFee = saleAmt - ((saleAmt * sim.swapFeePercent) / AERO_FEE_DENOM);
                    swapOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
                }
            }
            uint256 remaining = amountIn_ - saleAmt;

            // Calculate LP from balanced deposit using pool's mint formula:
            // liquidity = min((amount0 * totalSupply) / reserve0, (amount1 * totalSupply) / reserve1)
            // Router's _addLiquidity adjusts amounts to be proportional first
            uint256 reserveA;
            uint256 reserveB;
            {
                // After the swap, reserves change. Simulate the post-swap reserves.
                // Swap: sell `saleAmt` of tokenIn for `swapOut` of opposing token
                // Fee is taken from saleAmt and moved to poolFees (not in reserves)
                uint256 feeAmt = (saleAmt * sim.swapFeePercent) / AERO_FEE_DENOM;
                uint256 amountInAfterFee = saleAmt - feeAmt;
                reserveA = reserveIn + amountInAfterFee;
                reserveB = reserveOut - swapOut;
            }

            // Router's _addLiquidity calculates optimal amounts
            uint256 amountA;
            uint256 amountB;
            {
                // quoteLiquidity: amountBOptimal = amountADesired * reserveB / reserveA
                uint256 amountBOptimal = (remaining * reserveB) / reserveA;
                if (amountBOptimal <= swapOut) {
                    amountA = remaining;
                    amountB = amountBOptimal;
                } else {
                    uint256 amountAOptimal = (swapOut * reserveA) / reserveB;
                    amountA = amountAOptimal;
                    amountB = swapOut;
                }
            }

            // Pool's mint(): liquidity = min((amountA * totalSupply) / reserveA, (amountB * totalSupply) / reserveB)
            uint256 ratioA = (amountA * sim.lpTotalSupply) / reserveA;
            uint256 ratioB = (amountB * sim.lpTotalSupply) / reserveB;
            lpMinted = ratioA < ratioB ? ratioA : ratioB;
        }

        // Calculate protocol fee from compound
        uint256 protocolFeeLP;
        if (sim.compoundLP > 0) {
            protocolFeeLP = BetterMath._percentageOfWAD(
                sim.compoundLP, BaseProtocolDETFRepo._feeOracle().usageFeeOfVault(address(vault_))
            );
        }

        // Post-compound vault state for share conversion
        uint256 vaultLpReserve = IERC20(address(pool)).balanceOf(address(vault_)) + (sim.compoundLP - protocolFeeLP);
        uint256 vaultTotalShares = IERC20(address(vault_)).totalSupply();

        // Convert LP to vault shares
        vaultShares_ = BetterMath._convertToSharesDown(lpMinted, vaultLpReserve, vaultTotalShares, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Aerodrome Stable Pool Math                        */
    /* ---------------------------------------------------------------------- */

    /// @dev Mirrors Aerodrome Pool.getAmountOut stable path using provided reserves.
    ///      `dec0_`/`dec1_` are scalars (10 ** decimals) returned by pool.metadata().
    function _aerodromeStableAmountOut(
        uint256 amountInAfterFee_,
        bool token0In_,
        uint256 reserve0_,
        uint256 reserve1_,
        uint256 dec0_,
        uint256 dec1_
    ) internal pure returns (uint256 amountOut_) {
        if (amountInAfterFee_ == 0 || reserve0_ == 0 || reserve1_ == 0) {
            return 0;
        }

        uint256 xy = _aerodromeStableK(reserve0_, reserve1_, dec0_, dec1_);

        // Normalize reserves and amountIn to 1e18
        uint256 norm0 = (reserve0_ * 1e18) / dec0_;
        uint256 norm1 = (reserve1_ * 1e18) / dec1_;

        uint256 reserveA = token0In_ ? norm0 : norm1;
        uint256 reserveB = token0In_ ? norm1 : norm0;
        uint256 amountInNorm = token0In_ ? (amountInAfterFee_ * 1e18) / dec0_ : (amountInAfterFee_ * 1e18) / dec1_;

        uint256 y = reserveB - _aerodromeStableGetY(amountInNorm + reserveA, xy, reserveB);
        amountOut_ = (y * (token0In_ ? dec1_ : dec0_)) / 1e18;
    }

    function _aerodromeStableK(uint256 x_, uint256 y_, uint256 dec0_, uint256 dec1_)
        internal
        pure
        returns (uint256)
    {
        uint256 x = (x_ * 1e18) / dec0_;
        uint256 y = (y_ * 1e18) / dec1_;
        uint256 a = (x * y) / 1e18;
        uint256 b = ((x * x) / 1e18) + ((y * y) / 1e18);
        return (a * b) / 1e18;
    }

    function _aerodromeStableF(uint256 x0_, uint256 y_)
        internal
        pure
        returns (uint256)
    {
        uint256 x0_2 = (x0_ * x0_) / 1e18;
        uint256 y2 = (y_ * y_) / 1e18;
        return (x0_ * y2) / 1e18 + (y_ * x0_2) / 1e18;
    }

    function _aerodromeStableD(uint256 x0_, uint256 y_)
        internal
        pure
        returns (uint256)
    {
        uint256 x0_2 = (x0_ * x0_) / 1e18;
        uint256 y2 = (y_ * y_) / 1e18;
        return (3 * x0_ * y2) / 1e18 + x0_2;
    }

    // Port of Aerodrome Pool._get_y() for stable pools.
    function _aerodromeStableGetY(uint256 x0_, uint256 xy_, uint256 y_) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 yPrev = y_;
            uint256 k = _aerodromeStableF(x0_, y_);
            if (k < xy_) {
                uint256 dy = ((xy_ - k) * 1e18) / _aerodromeStableD(x0_, y_);
                if (dy == 0) {
                    if (k == xy_ || _aerodromeStableF(x0_, y_ + 1) > xy_) {
                        return y_;
                    }
                    dy = 1;
                }
                y_ = y_ + dy;
            } else {
                uint256 dy = ((k - xy_) * 1e18) / _aerodromeStableD(x0_, y_);
                if (dy == 0) {
                    if (k == xy_ || _aerodromeStableF(x0_, y_ - 1) < xy_) {
                        return y_;
                    }
                    dy = 1;
                }
                y_ = y_ - dy;
            }

            if (y_ > yPrev) {
                if (y_ - yPrev <= 1) {
                    return y_;
                }
            } else {
                if (yPrev - y_ <= 1) {
                    return y_;
                }
            }
        }
        revert("!y");
    }

    /**
     * @notice Builds a compound simulation struct for the given vault.
     * @dev Loads pool state and simulates compound in one call.
     */
    function _buildCompoundSim(IStandardExchange vault_) internal view virtual returns (AeroCompoundSim memory sim) {
        address poolAddress = address(IERC4626(address(vault_)).asset());
        IPool pool = IPool(poolAddress);
        (sim.reserve0, sim.reserve1,) = pool.getReserves();
        sim.lpTotalSupply = IERC20(poolAddress).totalSupply();
        sim.swapFeePercent = _poolSwapFeePercent(poolAddress);
        sim.token0 = pool.token0();

        _simulateCompound(pool, address(vault_), sim);
    }

    /**
     * @notice Simulates Aerodrome fee compound to get post-compound pool state.
     * @dev Mirrors _previewCompoundState from AerodromeStandardExchangeCommon.
     *      Uses pool public functions to read claimable fees.
     *      Ignores excess tokens (internal vault storage, typically dust < 1000).
     *      Modifies sim_ in-place with post-compound reserves/supply and sets compoundLP.
     */
    function _simulateCompound(IPool pool_, address vault_, AeroCompoundSim memory sim_) internal view {
        // Calculate claimable fees (mirrors _previewClaimableFees)
        (uint256 claimable0, uint256 claimable1) = _previewClaimableFeesExternal(pool_, vault_);

        // Aerodrome vaults may hold dust/excess tokens in internal storage for the next compound.
        // Those values are included in Aerodrome's own _previewCompoundState logic.
        // If we ignore them here, our simulated post-compound pool state can diverge from
        // the vault's real preview/execution and make ProtocolDETF previews optimistic.
        (uint256 excess0Held, uint256 excess1Held) = _tryHeldExcessTokens(vault_);

        claimable0 += excess0Held;
        claimable1 += excess1Held;

        if (claimable0 == 0 && claimable1 == 0) {
            return;
        }

        // Calculate proportional deposit amounts
        (uint256 proportional0, uint256 proportional1) =
            _proportionalDeposit(sim_.reserve0, sim_.reserve1, claimable0, claimable1);
        uint256 excess0 = claimable0 - proportional0;
        uint256 excess1 = claimable1 - proportional1;

        // Apply proportional deposit
        uint256 lpFromProportional;
        if (proportional0 > 0 && proportional1 > 0) {
            lpFromProportional = ConstProdUtils._depositQuote(
                proportional0, proportional1, sim_.lpTotalSupply, sim_.reserve0, sim_.reserve1
            );
            sim_.reserve0 += proportional0;
            sim_.reserve1 += proportional1;
            sim_.lpTotalSupply += lpFromProportional;
        }

        // Apply single-sided zap for excess
        uint256 lpFromZap;
        if (excess0 > COMPOUND_DUST_THRESHOLD) {
            lpFromZap = _simulateSwapDeposit(sim_, excess0, true, sim_.swapFeePercent);
        } else if (excess1 > COMPOUND_DUST_THRESHOLD) {
            lpFromZap = _simulateSwapDeposit(sim_, excess1, false, sim_.swapFeePercent);
        }

        sim_.compoundLP = lpFromProportional + lpFromZap;
    }

    function _tryHeldExcessTokens(address vault_) private view returns (uint256 excess0Held_, uint256 excess1Held_) {
        // Optional: only Aerodrome Standard Exchange vaults include this selector.
        // Use staticcall so we don't require an interface definition.
        (bool ok, bytes memory data) = vault_.staticcall(abi.encodeWithSignature("heldExcessTokens()"));
        if (!ok || data.length != 64) {
            return (0, 0);
        }
        return abi.decode(data, (uint256, uint256));
    }

    /**
     * @notice Calculates claimable fees for a vault from an Aerodrome pool.
     * @dev Mirrors _previewClaimableFees from AerodromeStandardExchangeCommon
     *      using public pool functions.
     */
    function _previewClaimableFeesExternal(IPool pool_, address lp_)
        internal
        view
        virtual
        returns (uint256 claimable0, uint256 claimable1)
    {
        address poolAddress = address(pool_);
        claimable0 = pool_.claimable0(lp_);
        claimable1 = pool_.claimable1(lp_);

        uint256 supplied = IERC20(poolAddress).balanceOf(lp_);
        if (supplied == 0) {
            return (claimable0, claimable1);
        }

        uint256 index0 = pool_.index0();
        uint256 index1 = pool_.index1();
        uint256 supplyIndex0 = pool_.supplyIndex0(lp_);
        uint256 supplyIndex1 = pool_.supplyIndex1(lp_);

        if (index0 > supplyIndex0) {
            claimable0 += (supplied * (index0 - supplyIndex0)) / 1e18;
        }
        if (index1 > supplyIndex1) {
            claimable1 += (supplied * (index1 - supplyIndex1)) / 1e18;
        }
    }

    function _poolIsStable(address pool_) internal view virtual returns (bool stable_) {
        stable_ = IPool(pool_).stable();
    }

    function _poolSwapFeePercent(address pool_) internal view virtual returns (uint256 feePercent_) {
        feePercent_ = IPoolFactory(IUniswapV2Pair(pool_).factory()).getFee(pool_, _poolIsStable(pool_));
    }

    function _poolMetadata(address pool_)
        internal
        view
        virtual
        returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)
    {
        return IPool(pool_).metadata();
    }

    /**
     * @notice Calculates proportional deposit amounts given reserves and available tokens.
     * @dev Mirrors _proportionalDeposit from AerodromeStandardExchangeCommon.
     */
    function _proportionalDeposit(uint256 reserveA_, uint256 reserveB_, uint256 amountA_, uint256 amountB_)
        internal
        pure
        returns (uint256 depositA, uint256 depositB)
    {
        if (reserveA_ == 0 || reserveB_ == 0) {
            return (amountA_, amountB_);
        }
        uint256 optimalB = ConstProdUtils._equivLiquidity(amountA_, reserveA_, reserveB_);
        if (optimalB <= amountB_) {
            return (amountA_, optimalB);
        } else {
            return ((amountB_ * reserveA_) / reserveB_, amountB_);
        }
    }

    /**
     * @notice Simulate the effect of adding an unbalanced vault token to the reserve pool
     *         and compute the resulting WETH value and redemption rate for a protocol NFT
     * @param layout_ Storage layout pointer (allows accessing vault preview functions)
     * @param resPoolData_ Reserve pool data previously loaded
     * @param currentRatedBalances_ Current rated balances array previously loaded
     * @param vaultIndexToAdd_ Index in rated balances to increase
     * @param vaultSharesAdded_ Amount to add to the rated balance at vaultIndexToAdd_
     * @param bptAdded_ Amount of BPT added to total supply (affects proportional exit)
     * @param newPositionShares_ New protocol NFT position shares after addition
     * @param newTotalShares_ New total shares for RICHIR after addition
     * @return newWethValue_ Total WETH value of the protocol NFT position after simulated add
     * @return newRate_ New redemption rate (WETH per share scaled by 1e18)
     */
    /**
     * @notice External wrapper to simulate the effect of adding an unbalanced vault token to the reserve pool
     *         and compute the resulting WETH value and redemption rate for a protocol NFT.
     * @dev External to avoid stack-too-deep when called from large view functions. Accepts calldata for the
     *      currentRatedBalances to minimize stack usage in the caller.
     */
    /**
     * @notice Compute the proportional exit shares (vault token amounts) for a protocol NFT
     *         after simulating an unbalanced add to the reserve pool.
     * @param currentRatedBalances_ Current rated balances array (calldata)
     * @param chirWethVaultIndex_ Index of CHIR/WETH vault token in pool
     * @param richChirVaultIndex_ Index of RICH/CHIR vault token in pool
     * @param vaultIndexToAdd_ Index to which vaultSharesAdded_ will be added
     * @param vaultSharesAdded_ Amount added to the rated balance at vaultIndexToAdd_
     * @param resPoolTotalSupply_ Current reserve pool total supply
     * @param bptAdded_ Amount of BPT minted by the add (increases total supply)
     * @param newPositionShares_ Protocol NFT position shares after addition
     * @return chirWethVaultSharesOutSim_ Simulated CHIR/WETH vault shares out (proportional)
     * @return richChirVaultSharesOutSim_ Simulated RICH/CHIR vault shares out (proportional)
     * @return simTotalSupply_ Simulated reserve pool total supply after BPT added
     */
    function _computeSimulatedExitShares(
        uint256[] calldata currentRatedBalances_,
        uint256 chirWethVaultIndex_,
        uint256 richChirVaultIndex_,
        uint256 vaultIndexToAdd_,
        uint256 vaultSharesAdded_,
        uint256 resPoolTotalSupply_,
        uint256 bptAdded_,
        uint256 newPositionShares_
    )
        external
        pure
        returns (uint256 chirWethVaultSharesOutSim_, uint256 richChirVaultSharesOutSim_, uint256 simTotalSupply_)
    {
        uint256[] memory simRated = new uint256[](currentRatedBalances_.length);
        for (uint256 i = 0; i < currentRatedBalances_.length; ++i) {
            simRated[i] = currentRatedBalances_[i];
        }
        simRated[vaultIndexToAdd_] = simRated[vaultIndexToAdd_] + vaultSharesAdded_;
        simTotalSupply_ = resPoolTotalSupply_ + bptAdded_;

        chirWethVaultSharesOutSim_ = (simRated[chirWethVaultIndex_] * newPositionShares_) / simTotalSupply_;
        richChirVaultSharesOutSim_ = (simRated[richChirVaultIndex_] * newPositionShares_) / simTotalSupply_;
    }

    struct SwapDepositCalcs {
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 saleAmt;
        uint256 amountInAfterFee;
        uint256 opTokenAmtIn;
        uint256 remaining;
    }

    /**
     * @notice Simulates a single-sided swap-deposit and updates pool state in memory.
     * @dev Mirrors _previewApplySwapDepositWithFee from AerodromeStandardExchangeCommon.
     */
    function _simulateSwapDeposit(AeroCompoundSim memory sim_, uint256 amountIn_, bool token0In_, uint256 feePercent_)
        internal
        pure
        returns (uint256 lpMinted)
    {
        if (amountIn_ == 0 || sim_.lpTotalSupply == 0 || feePercent_ >= AERO_FEE_DENOM) return 0;

        SwapDepositCalcs memory c;
        c.reserveIn = token0In_ ? sim_.reserve0 : sim_.reserve1;
        c.reserveOut = token0In_ ? sim_.reserve1 : sim_.reserve0;
        if (c.reserveIn == 0 || c.reserveOut == 0) return 0;

        c.saleAmt = ConstProdUtils._swapDepositSaleAmt(amountIn_, c.reserveIn, feePercent_, AERO_FEE_DENOM);
        c.amountInAfterFee = c.saleAmt - ((c.saleAmt * feePercent_) / AERO_FEE_DENOM);
        c.opTokenAmtIn = (c.amountInAfterFee * c.reserveOut) / (c.reserveIn + c.amountInAfterFee);
        c.remaining = amountIn_ - c.saleAmt;

        // Update reserves after swap
        c.reserveIn = c.reserveIn + c.amountInAfterFee;
        c.reserveOut = c.reserveOut - c.opTokenAmtIn;

        // Calculate proportional deposit amounts
        uint256 amountBOptimal = (c.remaining * c.reserveOut) / c.reserveIn;
        uint256 amountA;
        uint256 amountB;
        if (amountBOptimal <= c.opTokenAmtIn) {
            amountA = c.remaining;
            amountB = amountBOptimal;
        } else {
            amountA = (c.opTokenAmtIn * c.reserveIn) / c.reserveOut;
            amountB = c.opTokenAmtIn;
        }

        {
            uint256 ratioA = (amountA * sim_.lpTotalSupply) / c.reserveIn;
            uint256 ratioB = (amountB * sim_.lpTotalSupply) / c.reserveOut;
            lpMinted = ratioA < ratioB ? ratioA : ratioB;
        }

        c.reserveIn += amountA;
        c.reserveOut += amountB;
        sim_.lpTotalSupply += lpMinted;

        if (token0In_) {
            sim_.reserve0 = c.reserveIn;
            sim_.reserve1 = c.reserveOut;
        } else {
            sim_.reserve1 = c.reserveIn;
            sim_.reserve0 = c.reserveOut;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      Seigniorage Calculations                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates seigniorage components for a mint operation above peg.
     * @param layout_ Storage layout reference
     * @param calc_ Seigniorage calculation struct to populate
     * @param amountIn_ Amount of WETH deposited
     */
    function _calcSeigniorage(BaseProtocolDETFRepo.Storage storage layout_, SeigniorageCalc memory calc_, uint256 amountIn_)
        internal
        view
    {
        if (calc_.syntheticPrice <= ONE_WAD) {
            return;
        }

        // Gross seigniorage = amount above peg value
        calc_.grossSeigniorage = amountIn_ - (amountIn_ * ONE_WAD / calc_.syntheticPrice);

        // Get reduction percentage from fee oracle
        uint256 reductionPPM = layout_._seigniorageIncentivePercentagePPM();
        calc_.reducedFeePercent = reductionPPM;

        // Discount given to minter as incentive
        calc_.discountMargin = BetterMath._percentageOfWAD(calc_.grossSeigniorage, reductionPPM);

        // Profit captured for NFT holders
        calc_.profitMargin = calc_.grossSeigniorage - calc_.discountMargin;

        if (calc_.profitMargin > 0) {
            calc_.seigniorageTokens = calc_.profitMargin;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                       Amount Calculations                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates amount of CHIR tokens to mint for a given WETH deposit.
     * @param amountIn_ Amount of WETH to deposit
     * @param syntheticPrice_ Current synthetic price
     * @return amountOut_ Amount of CHIR tokens to mint
     */
    function _calcMintAmount(uint256 amountIn_, uint256 syntheticPrice_) internal pure returns (uint256 amountOut_) {
        if (syntheticPrice_ <= ONE_WAD) {
            amountOut_ = amountIn_;
        } else {
            // Above peg: fewer CHIR per WETH
            amountOut_ = (amountIn_ * ONE_WAD) / syntheticPrice_;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                        Token Route Validation                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Checks if the token is WETH.
     * @param layout_ Storage layout reference
     * @param token_ Token to check
     * @return True if token is WETH
     */
    function _isWethToken(BaseProtocolDETFRepo.Storage storage layout_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layout_.wethToken);
    }

    function _isWethToken(IERC20 token_) internal view returns (bool) {
        return _isWethToken(BaseProtocolDETFRepo._layout(), token_);
    }

    /**
     * @notice Checks if the token is RICH.
     * @param layout_ Storage layout reference
     * @param token_ Token to check
     * @return True if token is RICH
     */
    function _isRichToken(BaseProtocolDETFRepo.Storage storage layout_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layout_.richToken);
    }

    function _isRichToken(IERC20 token_) internal view returns (bool) {
        return _isRichToken(BaseProtocolDETFRepo._layout(), token_);
    }

    /**
     * @notice Checks if the target token is CHIR (this contract).
     * @param token_ Token to check
     * @return True if token is this contract
     */
    function _isChirToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(this);
    }

    /**
     * @notice Checks if the token is RICHIR.
     * @param layout_ Storage layout reference
     * @param token_ Token to check
     * @return True if token is RICHIR
     */
    function _isRichirToken(BaseProtocolDETFRepo.Storage storage layout_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layout_.richirToken);
    }

    function _isRichirToken(IERC20 token_) internal view returns (bool) {
        return _isRichirToken(BaseProtocolDETFRepo._layout(), token_);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Reserve Pool State                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Checks if the reserve pool has been initialized.
     * @return True if initialized
     */
    function _isInitialized() internal view returns (bool) {
        return BaseProtocolDETFRepo._isReservePoolInitialized();
    }

    /**
     * @notice Gets the reserve pool address.
     * @return The weighted pool contract
     */
    function _reservePool() internal view returns (IWeightedPool) {
        return IWeightedPool(address(ERC4626Repo._reserveAsset()));
    }

    /* ---------------------------------------------------------------------- */
    /*                          Token Transfer Helpers                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Securely transfers tokens into the vault.
     * @param tokenIn_ Token to transfer
     * @param amount_ Amount to transfer
     * @param pretransferred_ Whether tokens were already transferred
     * @return actualIn_ Actual amount received
     */
    function _secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, bool pretransferred_)
        internal
        returns (uint256 actualIn_)
    {
        if (pretransferred_) {
            require(
                tokenIn_.balanceOf(address(this)) >= amount_, "BaseProtocolDETFCommon: insufficient pretransferred balance"
            );
            return amount_;
        }

        uint256 balBefore = tokenIn_.balanceOf(address(this));

        if (tokenIn_.allowance(msg.sender, address(this)) < amount_) {
            Permit2AwareRepo._permit2().transferFrom(msg.sender, address(this), uint160(amount_), address(tokenIn_));
        } else {
            tokenIn_.safeTransferFrom(msg.sender, address(this), amount_);
        }

        uint256 balAfter = tokenIn_.balanceOf(address(this));
        actualIn_ = balAfter - balBefore;
    }

    /**
     * @notice Burns CHIR tokens from owner or this contract.
     * @param owner_ Token owner
     * @param amount_ Amount to burn
     * @param pretransferred_ Whether tokens were pre-transferred to this contract
     */
    function _secureChirBurn(address owner_, uint256 amount_, bool pretransferred_) internal {
        ERC20Repo._burn(pretransferred_ ? address(this) : owner_, amount_);
    }

    function _loadChirWethLiquidityQuote(BaseProtocolDETFRepo.Storage storage layout_)
        internal
        view
        returns (ChirWethLiquidityQuote memory quote_)
    {
        quote_.pool = address(IERC4626(address(layout_.chirWethVault)).asset());

        IUniswapV2Pair pool = IUniswapV2Pair(quote_.pool);
        quote_.totalSupply = IERC20(quote_.pool).totalSupply();
        (quote_.reserve0, quote_.reserve1,) = pool.getReserves();
        quote_.token0 = pool.token0();
        quote_.token1 = pool.token1();
        quote_.stable = _poolIsStable(quote_.pool);
    }

    function _quoteBalancedChirForWethDeposit(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
        internal
        view
        returns (ChirWethLiquidityQuote memory quote_, uint256 chirAmount_)
    {
        quote_ = _loadChirWethLiquidityQuote(layout_);

        if (wethIn_ == 0 || quote_.reserve0 == 0 || quote_.reserve1 == 0) {
            return (quote_, 0);
        }

        if (quote_.token0 == address(layout_.wethToken)) {
            chirAmount_ = (wethIn_ * quote_.reserve1) / quote_.reserve0;
        } else {
            chirAmount_ = (wethIn_ * quote_.reserve0) / quote_.reserve1;
        }
    }

    function _quoteBalancedChirWethDepositAmounts(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
        internal
        view
        returns (ChirWethLiquidityQuote memory quote_, uint256 chirAmount_, uint256 wethUsed_)
    {
        (quote_, chirAmount_) = _quoteBalancedChirForWethDeposit(layout_, wethIn_);
        if (chirAmount_ == 0) {
            return (quote_, 0, 0);
        }

        if (quote_.token0 == address(layout_.wethToken)) {
            wethUsed_ = (chirAmount_ * quote_.reserve0) / quote_.reserve1;
        } else {
            wethUsed_ = (chirAmount_ * quote_.reserve1) / quote_.reserve0;
        }
    }

    function _previewBalancedChirWethLpOut(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
        internal
        view
        returns (uint256 lpOut_)
    {
        (ChirWethLiquidityQuote memory quote, uint256 chirAmount, uint256 wethUsed) =
            _quoteBalancedChirWethDepositAmounts(layout_, wethIn_);
        if (chirAmount == 0 || wethUsed == 0 || quote.totalSupply == 0) {
            return 0;
        }

        uint256 amount0 = quote.token0 == address(layout_.wethToken) ? wethUsed : chirAmount;
        uint256 amount1 = quote.token0 == address(layout_.wethToken) ? chirAmount : wethUsed;

        uint256 liquidity0 = (amount0 * quote.totalSupply) / quote.reserve0;
        uint256 liquidity1 = (amount1 * quote.totalSupply) / quote.reserve1;
        lpOut_ = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    }

    function _previewBalancedChirWethVaultShares(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
        internal
        view
        returns (uint256 vaultShares_)
    {
        uint256 lpOut = _previewBalancedChirWethLpOut(layout_, wethIn_);
        if (lpOut == 0) {
            return 0;
        }

        ChirWethLiquidityQuote memory quote = _loadChirWethLiquidityQuote(layout_);
        vaultShares_ = _previewVaultSharesPostCompound(layout_.chirWethVault, IERC20(quote.pool), lpOut);
    }
}
