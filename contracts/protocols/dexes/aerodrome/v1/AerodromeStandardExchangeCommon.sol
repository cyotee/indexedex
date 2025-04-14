// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter as IAerodromeRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {AerodromeUtils} from "@crane/contracts/utils/math/AerodromeUtils.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    AerodromePoolMetadataRepo
} from "@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromePoolMetadataRepo.sol";
import {
    AerodromeRouterAwareRepo
} from "@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromeRouterAwareRepo.sol";
import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {AerodromeStandardExchangeRepo} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeRepo.sol";
import {IFeeCompounding} from "contracts/interfaces/IFeeCompounding.sol";

// abstract
contract AerodromeStandardExchangeCommon is BasicVaultCommon, IFeeCompounding {
    using BetterSafeERC20 for IERC20;

    /// @notice Default dust threshold in wei - amounts below this are held for next compound
    /// @dev Set to 1000 wei as a reasonable minimum to avoid wasting gas on tiny amounts
    uint256 internal constant DEFAULT_DUST_THRESHOLD = 1000;

    /// @notice Returns token amounts held as dust for the next compound.
    /// @dev These values are included in Aerodrome's previewCompoundState logic.
    function heldExcessTokens() external view returns (uint256 excessToken0, uint256 excessToken1) {
        excessToken0 = AerodromeStandardExchangeRepo._excessToken0();
        excessToken1 = AerodromeStandardExchangeRepo._excessToken1();
    }

    /**
     * @dev Aerodrome vaults may intentionally hold token0/token1 dust from fee compounding.
     *      When `pretransferred == true` we must ensure the caller cannot "pay" using that dust.
     *      We therefore reserve the tracked excess amounts and only allow pretransfer credit
     *      against `balanceOf(this) - reserved`.
     */
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountTokenToDeposit, bool pretransferred)
        internal
        virtual
        override
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            uint256 reserved;
            address tokenAddr = address(tokenIn);

            if (tokenAddr == ConstProdReserveVaultRepo._token0()) {
                reserved = AerodromeStandardExchangeRepo._excessToken0();
            } else if (tokenAddr == ConstProdReserveVaultRepo._token1()) {
                reserved = AerodromeStandardExchangeRepo._excessToken1();
            }

            // Underflow-safe: if reserved > balance, available becomes 0 and will fail the check.
            uint256 bal = tokenIn.balanceOf(address(this));
            uint256 available = bal > reserved ? bal - reserved : 0;
            require(
                available >= amountTokenToDeposit,
                "BasicVaultCommon: insufficient pretransferred balance"
            );
            return amountTokenToDeposit;
        }

        return super._secureTokenTransfer(tokenIn, amountTokenToDeposit, pretransferred);
    }

    struct AerodromeV1IndexSourceReserves {
        IPool pool;
        address token0;
        address token1;
        uint256 knownReserve;
        uint256 opposingReserve;
        uint256 knownfeePercent;
        uint256 opTokenFeePercent;
        uint256 totalSupply;
        // uint256 kLast;
    }

    struct AerodromeV1StrategyVault {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint256 knownTokenLastOwnedSourceReserve;
        uint256 opTokenLastOwnedSourceReserve;
        uint256 feeShares;
    }

    function _loadIndexSourceReserves(AerodromeV1IndexSourceReserves memory indexSource, IERC20 knownToken)
        internal
        view
    {
        // indexSource.pool = ICamelotPair(address(ERC4626Repo._reserveAsset()));
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        indexSource.token0 = ConstProdReserveVaultRepo._token0(constProd);
        indexSource.token1 = ConstProdReserveVaultRepo._token1(constProd);
        indexSource.totalSupply = IERC20(address(indexSource.pool)).totalSupply();
        // indexSource.kLast = indexSource.pool.getK();
        (uint256 reserve0, uint256 reserve1,) = indexSource.pool.getReserves();
        (indexSource.knownReserve, indexSource.opposingReserve) =
            ConstProdUtils._sortReserves(address(knownToken), indexSource.token0, reserve0, reserve1);
        uint256 swapFeePercent = AerodromePoolMetadataRepo._factory()
            .getFee(address(indexSource.pool), AerodromePoolMetadataRepo._isStable());
        indexSource.knownfeePercent = swapFeePercent;
        indexSource.opTokenFeePercent = swapFeePercent;
    }

    function _previewClaimableFees(IPool pool, address lp)
        internal
        view
        returns (uint256 claimable0, uint256 claimable1)
    {
        claimable0 = pool.claimable0(lp);
        claimable1 = pool.claimable1(lp);

        uint256 supplied = IERC20(address(pool)).balanceOf(lp);
        if (supplied == 0) {
            return (claimable0, claimable1);
        }

        uint256 index0 = pool.index0();
        uint256 index1 = pool.index1();
        uint256 supplyIndex0 = pool.supplyIndex0(lp);
        uint256 supplyIndex1 = pool.supplyIndex1(lp);

        if (index0 > supplyIndex0) {
            claimable0 += (supplied * (index0 - supplyIndex0)) / 1e18;
        }
        if (index1 > supplyIndex1) {
            claimable1 += (supplied * (index1 - supplyIndex1)) / 1e18;
        }
    }

    function _loadStrategyVault(AerodromeV1StrategyVault memory vault, IERC20 knownToken) internal view {
        vault.vaultLpReserve = ERC4626Repo._lastTotalAssets();
        vault.vaultTotalShares = ERC20Repo._totalSupply();
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        vault.knownTokenLastOwnedSourceReserve =
            ConstProdReserveVaultRepo._yieldReserveOfToken(constProd, address(knownToken));
        vault.opTokenLastOwnedSourceReserve = ConstProdReserveVaultRepo._yieldReserveOfToken(
            constProd, ConstProdReserveVaultRepo._opposingToken(constProd, address(knownToken))
        );
    }

    /**
     * @dev Core proportional deposit calculation. Given reserves and desired amounts,
     *      returns the maximum proportional amounts that never exceed the provided limits.
     *      Used by both _calculateProportionalAmounts (execution) and _previewCalcCompoundAmounts (read-only).
     */
    function _proportionalDeposit(uint256 reserveA, uint256 reserveB, uint256 amountA, uint256 amountB)
        internal
        pure
        returns (uint256 depositA, uint256 depositB)
    {
        if (reserveA == 0 || reserveB == 0) {
            return (amountA, amountB);
        }

        uint256 optimalB = ConstProdUtils._equivLiquidity(amountA, reserveA, reserveB);
        if (optimalB <= amountB) {
            return (amountA, optimalB);
        } else {
            return ((amountB * reserveA) / reserveB, amountB);
        }
    }

    function _calculateLPFromPoolFees(
        uint256 claimable0,
        uint256 claimable1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 swapFeePercent
    ) internal pure returns (uint256 poolFeeLP) {
        if (claimable0 == 0 && claimable1 == 0) {
            return 0;
        }
        uint256 equiv1 = ConstProdUtils._equivLiquidity(claimable0, reserve0, reserve1);
        uint256 equiv0;
        uint256 remainder0;
        uint256 remainder1;
        if (equiv1 > claimable1) {
            equiv0 = ConstProdUtils._equivLiquidity(claimable1, reserve1, reserve0);
            equiv1 = claimable1;
            remainder0 = claimable0 - equiv0;
        } else {
            equiv0 = claimable0;
            remainder1 = claimable1 - equiv1;
        }
        uint256 lpFromEquiv = ConstProdUtils._depositQuote(
            // uint256 amountADeposit,
            equiv0,
            // uint256 amountBDeposit,
            equiv1,
            // uint256 lpTotalSupply,
            lpTotalSupply,
            // uint256 lpReserveA,
            reserve0,
            // uint256 lpReserveB
            reserve1
        );
        uint256 lpFromRemainder;
        if (remainder0 > 0) {
            lpFromRemainder = AerodromeUtils._quoteSwapDepositWithFee(
                // uint256 amountIn,
                remainder0,
                // uint256 lpTotalSupply,
                lpTotalSupply,
                // uint256 reserveIn,
                reserve0,
                // uint256 reserveOut,
                reserve1,
                // uint256 feePercent
                swapFeePercent
            );
        } else if (remainder1 > 0) {
            lpFromRemainder = AerodromeUtils._quoteSwapDepositWithFee(
                // uint256 amountIn,
                remainder1,
                // uint256 lpTotalSupply,
                lpTotalSupply,
                // uint256 reserveIn,
                reserve1,
                // uint256 reserveOut,
                reserve0,
                // uint256 feePercent
                swapFeePercent
            );
        }
        return lpFromEquiv + lpFromRemainder;
    }

    function _calcVaultFeeLPAmount(
        IPool pool,
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 aeroSwapFeePercent
    ) internal view returns (uint256 vaultFeeShares) {
        (uint256 claimable0, uint256 claimable1) = _previewClaimableFees(pool, address(this));
        vaultFeeShares = _calculateLPFromPoolFees(
            // uint256 claimable0,
            claimable0,
            // uint256 claimable1,
            claimable1,
            // uint256 reserve0,
            reserve0,
            // uint256 reserve1,
            reserve1,
            // uint256 lpTotalSupply,
            lpTotalSupply,
            // uint256 swapFeePercent
            aeroSwapFeePercent
        );
        vaultFeeShares = BetterMath._percentageOfWAD(
            // uint256 total,
            vaultFeeShares,
            // uint256 percentage,
            VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );
    }

    function _calculateSharesMinusFees(uint256 vaultFeeLP, uint256 amountIn)
        internal
        view
        returns (uint256 sharesMinusFees)
    {
        uint256 vaultTotalShares = ERC20Repo._totalSupply();
        ERC4626Repo.Storage storage erc4626Layout = ERC4626Repo._layout();
        uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets(erc4626Layout);
        uint8 decimalOffset = ERC4626Repo._decimalOffset(erc4626Layout);
        vaultFeeLP = BetterMath._convertToSharesDown(vaultFeeLP, vaultLpReserve, vaultTotalShares, decimalOffset);
        vaultTotalShares += vaultFeeLP;
        return BetterMath._convertToSharesDown(amountIn, vaultLpReserve, vaultTotalShares, decimalOffset);
    }

    function _calculateAssetsMinusFees(uint256 vaultFeeLP, uint256 amountIn) internal view returns (uint256 assetsOut) {
        uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets();
        uint256 vaultTotalShares = ERC20Repo._totalSupply();
        uint8 decimalOffset = ERC4626Repo._decimalOffset();
        vaultFeeLP = BetterMath._convertToSharesDown(vaultFeeLP, vaultLpReserve, vaultTotalShares, decimalOffset);
        vaultTotalShares += vaultFeeLP;
        assetsOut = BetterMath._convertToAssetsDown(amountIn, vaultLpReserve, vaultTotalShares, decimalOffset);
    }

    struct VaultFeeParams {
        IPool pool;
        uint256 reserve0;
        uint256 reserve1;
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint8 decimalOffset;
    }

    function _calcAndMintVaultFees(VaultFeeParams memory params) internal returns (uint256 vaultFeeShares) {
        vaultFeeShares = _calcVaultFeeLPAmount(
            // IPool pool,
            params.pool,
            // uint256 reserve0,
            params.reserve0,
            // uint256 reserve1,
            params.reserve1,
            // uint256 lpTotalSupply,
            IERC20(address(params.pool)).totalSupply(),
            // uint256 aeroSwapFeePercent
            AerodromePoolMetadataRepo._factory().getFee(address(params.pool), AerodromePoolMetadataRepo._isStable())
        );
        vaultFeeShares = BetterMath._convertToSharesDown(
            vaultFeeShares, params.vaultLpReserve, params.vaultTotalShares, params.decimalOffset
        );
        ERC20Repo._mint(
            // address account,
            address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
            // uint256 amount,
            vaultFeeShares
        );
        return vaultFeeShares;
    }

    struct AeroReserve {
        IAerodromeRouter router;
        IPool pool;
        IPoolFactory factory;
        uint256 knownReserve;
        uint256 opposingReserve;
        uint256 swapFeePercent;
    }

    struct VaultState {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint8 decimalOffset;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Fee Compounding Logic                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Parameters for the compound operation
    struct CompoundParams {
        IPool pool;
        IAerodromeRouter router;
        IPoolFactory factory;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 lpTotalSupply;
        uint256 swapFeePercent;
        uint256 dustThreshold;
        uint256 deadline;
    }

    /// @notice Result of a compound operation
    struct CompoundResult {
        uint256 totalLPMinted;
        uint256 protocolFeeLP;
        uint256 excessToken0;
        uint256 excessToken1;
    }

    /// @notice Intermediate calculations for compound operation
    struct CompoundCalcs {
        uint256 claimed0;
        uint256 claimed1;
        uint256 total0;
        uint256 total1;
        uint256 proportional0;
        uint256 proportional1;
        uint256 excess0;
        uint256 excess1;
    }

    /// @notice Parameters for zap add liquidity
    struct ZapLiquidityParams {
        IAerodromeRouter router;
        address tokenIn;
        address tokenOut;
        bool isStable;
        uint256 amountIn;
        uint256 amountOut;
        uint256 deadline;
    }

    /**
     * @notice Claims and compounds accumulated pool fees into LP tokens.
     * @dev This function:
     *      1. Claims fees from the pool (token0 and token1)
     *      2. Includes any previously held excess tokens
     *      3. Deposits proportionally to get LP tokens
     *      4. ZapIns any excess token above dust threshold
     *      5. Extracts protocol fee from minted LP
     *      6. Updates vault's LP reserve
     * @param params CompoundParams struct with pool and router references
     * @return result CompoundResult with LP minted and fee amounts
     */
    function _claimAndCompoundFees(CompoundParams memory params) internal returns (CompoundResult memory result) {
        AerodromeStandardExchangeRepo.Storage storage aeroRepo = AerodromeStandardExchangeRepo._layout();
        CompoundCalcs memory calcs;

        // Step 1: Claim fees from pool
        (calcs.claimed0, calcs.claimed1) = params.pool.claimFees();

        // Step 2: Add any held excess tokens from previous compounds
        calcs.total0 = calcs.claimed0 + AerodromeStandardExchangeRepo._clearExcessToken0(aeroRepo);
        calcs.total1 = calcs.claimed1 + AerodromeStandardExchangeRepo._clearExcessToken1(aeroRepo);

        // Emit claim event if any fees were claimed
        if (calcs.claimed0 > 0 || calcs.claimed1 > 0) {
            emit FeesClaimed(calcs.claimed0, calcs.claimed1);
        }

        // Early return if nothing to compound
        if (calcs.total0 == 0 && calcs.total1 == 0) {
            return result;
        }

        // Step 3: Calculate proportional deposit amounts
        _calculateProportionalAmounts(params, calcs);

        // Step 4: Proportional deposit to get LP
        result.totalLPMinted = _addProportionalLiquidity(params, calcs);

        // Step 5: Handle excess token with ZapIn or hold as dust
        (result.totalLPMinted, result.excessToken0, result.excessToken1) =
            _handleExcessTokens(params, calcs, aeroRepo, result.totalLPMinted);

        // Step 6: Extract protocol fee from compounded LP
        if (result.totalLPMinted > 0) {
            uint256 usageFeeWAD = VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this));
            result.protocolFeeLP = BetterMath._percentageOfWAD(result.totalLPMinted, usageFeeWAD);

            // Pay protocol fee in LP tokens (no share supply changes).
            // This keeps vault share accounting stable (e.g., burning X shares reduces totalSupply by X).
            if (result.protocolFeeLP > 0) {
                IERC20(address(params.pool))
                    .transfer(address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()), result.protocolFeeLP);
            }

            // Update vault's LP reserve to the post-fee actual balance.
            ERC4626Repo._setLastTotalAssets(IERC20(address(params.pool)).balanceOf(address(this)));

            emit FeesCompounded(result.totalLPMinted, result.protocolFeeLP, result.excessToken0, result.excessToken1);
        }

        return result;
    }

    /**
     * @notice Calculate proportional deposit amounts
     * @dev Modifies calcs in place with proportional and excess amounts.
     *      Uses shared _proportionalDeposit for core math.
     */
    function _calculateProportionalAmounts(CompoundParams memory params, CompoundCalcs memory calcs) internal pure {
        (calcs.proportional0, calcs.proportional1) =
            _proportionalDeposit(params.reserve0, params.reserve1, calcs.total0, calcs.total1);
        calcs.excess0 = calcs.total0 - calcs.proportional0;
        calcs.excess1 = calcs.total1 - calcs.proportional1;
    }

    /**
     * @notice Add proportional liquidity to get LP tokens
     * @return lpMinted Amount of LP tokens minted
     */
    function _addProportionalLiquidity(CompoundParams memory params, CompoundCalcs memory calcs)
        internal
        returns (uint256 lpMinted)
    {
        if (calcs.proportional0 > 0 && calcs.proportional1 > 0) {
            IERC20(params.token0).approve(address(params.router), calcs.proportional0);
            IERC20(params.token1).approve(address(params.router), calcs.proportional1);

            (,, lpMinted) = params.router
                .addLiquidity(
                    params.token0,
                    params.token1,
                    AerodromePoolMetadataRepo._isStable(),
                    calcs.proportional0,
                    calcs.proportional1,
                    0,
                    0,
                    address(this),
                    params.deadline
                );
        }
    }

    /**
     * @notice Handle excess tokens - zap in or hold as dust
     * @return totalLP Updated total LP minted
     * @return excessToken0 Excess token0 held as dust
     * @return excessToken1 Excess token1 held as dust
     */
    function _handleExcessTokens(
        CompoundParams memory params,
        CompoundCalcs memory calcs,
        AerodromeStandardExchangeRepo.Storage storage aeroRepo,
        uint256 currentLP
    ) internal returns (uint256 totalLP, uint256 excessToken0, uint256 excessToken1) {
        totalLP = currentLP;

        if (calcs.excess0 > params.dustThreshold) {
            totalLP += _zapInExcess(params, params.token0, IERC20(params.token1), calcs.excess0);
        } else if (calcs.excess0 > 0) {
            AerodromeStandardExchangeRepo._setExcessToken0(aeroRepo, calcs.excess0);
            excessToken0 = calcs.excess0;
        }

        if (calcs.excess1 > params.dustThreshold) {
            totalLP += _zapInExcess(params, params.token1, IERC20(params.token0), calcs.excess1);
        } else if (calcs.excess1 > 0) {
            AerodromeStandardExchangeRepo._setExcessToken1(aeroRepo, calcs.excess1);
            excessToken1 = calcs.excess1;
        }
    }

    /**
     * @notice ZapIn excess token into LP
     * @dev Swaps half of excess token for the other token, then adds liquidity
     * @param params Compound parameters
     * @param tokenIn The excess token to zap in
     * @param tokenOut The opposing token
     * @param amountIn Amount of excess token
     * @return lpMinted LP tokens minted from zap
     */
    function _zapInExcess(CompoundParams memory params, address tokenIn, IERC20 tokenOut, uint256 amountIn)
        internal
        returns (uint256 lpMinted)
    {
        // Calculate swap amount using constant product formula
        uint256 saleAmt;
        {
            uint256 reserveIn = tokenIn == params.token0 ? params.reserve0 : params.reserve1;
            saleAmt = ConstProdUtils._swapDepositSaleAmt(
                amountIn,
                reserveIn,
                params.swapFeePercent,
                10000 // Aerodrome fee denominator
            );
        }

        // Perform swap and get swap output
        uint256 swapOut = _executeZapSwap(params, tokenIn, tokenOut, amountIn, saleAmt);

        // Add liquidity with swapped tokens
        lpMinted = _executeZapAddLiquidity(
            ZapLiquidityParams({
                router: params.router,
                tokenIn: tokenIn,
                tokenOut: address(tokenOut),
                isStable: AerodromePoolMetadataRepo._isStable(),
                amountIn: amountIn - saleAmt,
                amountOut: swapOut,
                deadline: params.deadline
            }),
            tokenOut
        );
    }

    function _executeZapSwap(
        CompoundParams memory params,
        address tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 saleAmt
    ) internal returns (uint256 swapOut) {
        IERC20(tokenIn).approve(address(params.router), amountIn);

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: tokenIn,
            to: address(tokenOut),
            stable: AerodromePoolMetadataRepo._isStable(),
            factory: address(params.factory)
        });

        uint256[] memory amountsOut =
            params.router.swapExactTokensForTokens(saleAmt, 0, routes, address(this), params.deadline);
        swapOut = amountsOut[amountsOut.length - 1];
    }

    function _executeZapAddLiquidity(ZapLiquidityParams memory p, IERC20 tokenOut) internal returns (uint256 lpMinted) {
        IERC20(p.tokenIn).approve(address(p.router), p.amountIn);
        tokenOut.approve(address(p.router), p.amountOut);

        (,, lpMinted) = p.router
            .addLiquidity(p.tokenIn, p.tokenOut, p.isStable, p.amountIn, p.amountOut, 0, 0, address(this), p.deadline);
    }

    /**
     * @notice Builds CompoundParams from current pool state
     * @param pool The Aerodrome pool
     * @param deadline Transaction deadline
     * @return params Populated CompoundParams struct
     */
    function _buildCompoundParams(IPool pool, uint256 deadline) internal view returns (CompoundParams memory params) {
        params.pool = pool;
        params.router = AerodromeRouterAwareRepo._aerodromeRouter();
        params.factory = AerodromePoolMetadataRepo._factory();
        params.token0 = ConstProdReserveVaultRepo._token0();
        params.token1 = ConstProdReserveVaultRepo._token1();
        (params.reserve0, params.reserve1,) = pool.getReserves();
        params.lpTotalSupply = IERC20(address(pool)).totalSupply();
        params.swapFeePercent = params.factory.getFee(address(pool), AerodromePoolMetadataRepo._isStable());
        params.dustThreshold = DEFAULT_DUST_THRESHOLD;
        params.deadline = deadline;
    }

    /**
     * @notice Calculates expected LP from pending fee compound (for preview functions)
     * @dev Does NOT modify state - used for previewExchangeIn/Out
     * @param pool The Aerodrome pool
     * @param reserve0 Current reserve0
     * @param reserve1 Current reserve1
     * @param lpTotalSupply Current LP total supply
     * @param swapFeePercent Pool swap fee
     * @return expectedLP Expected LP from compounding pending fees
     */
    function _previewCompoundLP(
        IPool pool,
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 swapFeePercent
    ) internal view returns (uint256 expectedLP) {
        return _previewCompoundState(pool, reserve0, reserve1, lpTotalSupply, swapFeePercent).lpMinted;
    }

    struct PreviewCompoundState {
        uint256 lpMinted;
        uint256 reserve0;
        uint256 reserve1;
        uint256 lpTotalSupply;
    }

    function _previewCompoundState(
        IPool pool,
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 swapFeePercent
    ) internal view returns (PreviewCompoundState memory state) {
        // Default to current pool state (even if there is nothing to compound)
        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.lpTotalSupply = lpTotalSupply;

        // Get claimable amounts (mirrors Pool._updateFor + claimFees)
        (uint256 claimable0, uint256 claimable1) = _previewClaimableFees(pool, address(this));

        // Add held excess tokens
        uint256 total0 = claimable0 + AerodromeStandardExchangeRepo._excessToken0();
        uint256 total1 = claimable1 + AerodromeStandardExchangeRepo._excessToken1();

        if (total0 == 0 && total1 == 0) {
            return state;
        }

        PreviewPoolState memory poolState =
            PreviewPoolState({reserve0: reserve0, reserve1: reserve1, lpTotalSupply: lpTotalSupply});
        PreviewCompoundAmounts memory amounts =
            _previewCalcCompoundAmounts(total0, total1, poolState.reserve0, poolState.reserve1);

        uint256 lpFromProportional = _previewApplyProportionalDeposit(poolState, amounts);
        uint256 lpFromZap = _previewApplyZapSingleSided(poolState, amounts, swapFeePercent);

        state.lpMinted = lpFromProportional + lpFromZap;
        state.reserve0 = poolState.reserve0;
        state.reserve1 = poolState.reserve1;
        state.lpTotalSupply = poolState.lpTotalSupply;
    }

    struct PreviewPoolState {
        uint256 reserve0;
        uint256 reserve1;
        uint256 lpTotalSupply;
    }

    struct PreviewCompoundAmounts {
        uint256 proportional0;
        uint256 proportional1;
        uint256 excess0;
        uint256 excess1;
    }

    function _previewCalcCompoundAmounts(uint256 total0, uint256 total1, uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (PreviewCompoundAmounts memory amounts)
    {
        (amounts.proportional0, amounts.proportional1) = _proportionalDeposit(reserve0, reserve1, total0, total1);
        amounts.excess0 = total0 - amounts.proportional0;
        amounts.excess1 = total1 - amounts.proportional1;
    }

    function _previewApplyProportionalDeposit(PreviewPoolState memory poolState, PreviewCompoundAmounts memory amounts)
        internal
        pure
        returns (uint256 lpFromProportional)
    {
        if (amounts.proportional0 == 0 || amounts.proportional1 == 0) {
            return 0;
        }

        lpFromProportional = ConstProdUtils._depositQuote(
            amounts.proportional0,
            amounts.proportional1,
            poolState.lpTotalSupply,
            poolState.reserve0,
            poolState.reserve1
        );

        poolState.reserve0 += amounts.proportional0;
        poolState.reserve1 += amounts.proportional1;
        poolState.lpTotalSupply += lpFromProportional;
    }

    function _previewApplyZapSingleSided(
        PreviewPoolState memory poolState,
        PreviewCompoundAmounts memory amounts,
        uint256 swapFeePercent
    ) internal pure returns (uint256 lpFromZap) {
        if (amounts.excess0 > DEFAULT_DUST_THRESHOLD) {
            return _previewApplySwapDepositWithFee(poolState, amounts.excess0, true, swapFeePercent);
        }

        if (amounts.excess1 > DEFAULT_DUST_THRESHOLD) {
            return _previewApplySwapDepositWithFee(poolState, amounts.excess1, false, swapFeePercent);
        }
    }

    function _previewApplySwapDepositWithFee(
        PreviewPoolState memory poolState,
        uint256 amountIn,
        bool token0In,
        uint256 feePercent
    ) internal pure returns (uint256 lpMinted) {
        if (amountIn == 0 || poolState.lpTotalSupply == 0 || feePercent >= 10000) return 0;

        PreviewSwapDepositCalcs memory c;
        c.reserveIn = token0In ? poolState.reserve0 : poolState.reserve1;
        c.reserveOut = token0In ? poolState.reserve1 : poolState.reserve0;
        if (c.reserveIn == 0 || c.reserveOut == 0) return 0;

        c.saleAmt = ConstProdUtils._swapDepositSaleAmt(amountIn, c.reserveIn, feePercent, 10000);
        c.amountInAfterFee = c.saleAmt - ((c.saleAmt * feePercent) / 10000);
        c.opTokenAmtIn = (c.amountInAfterFee * c.reserveOut) / (c.reserveIn + c.amountInAfterFee);
        c.remaining = amountIn - c.saleAmt;

        c.newReserveIn = c.reserveIn + c.amountInAfterFee;
        c.newReserveOut = c.reserveOut - c.opTokenAmtIn;

        c.amountBOptimal = (c.remaining * c.newReserveOut) / c.newReserveIn;
        if (c.amountBOptimal <= c.opTokenAmtIn) {
            c.amountA = c.remaining;
            c.amountB = c.amountBOptimal;
        } else {
            c.amountA = (c.opTokenAmtIn * c.newReserveIn) / c.newReserveOut;
            c.amountB = c.opTokenAmtIn;
        }

        c.amountA_ratio = (c.amountA * poolState.lpTotalSupply) / c.newReserveIn;
        c.amountB_ratio = (c.amountB * poolState.lpTotalSupply) / c.newReserveOut;
        lpMinted = c.amountA_ratio < c.amountB_ratio ? c.amountA_ratio : c.amountB_ratio;

        c.newReserveIn += c.amountA;
        c.newReserveOut += c.amountB;
        poolState.lpTotalSupply += lpMinted;

        if (token0In) {
            poolState.reserve0 = c.newReserveIn;
            poolState.reserve1 = c.newReserveOut;
        } else {
            poolState.reserve1 = c.newReserveIn;
            poolState.reserve0 = c.newReserveOut;
        }
    }

    struct PreviewSwapDepositCalcs {
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 saleAmt;
        uint256 amountInAfterFee;
        uint256 opTokenAmtIn;
        uint256 remaining;
        uint256 newReserveIn;
        uint256 newReserveOut;
        uint256 amountBOptimal;
        uint256 amountA;
        uint256 amountB;
        uint256 amountA_ratio;
        uint256 amountB_ratio;
    }

    /**
     * @notice Updated fee calculation that uses active compounding
     * @dev Replaces the old virtual fee accounting with actual compound preview
     * @param pool The Aerodrome pool
     * @param reserve0 Current reserve0
     * @param reserve1 Current reserve1
     * @param lpTotalSupply Current LP total supply
     * @param aeroSwapFeePercent Pool swap fee
     * @return vaultFeeShares Protocol fee shares from compounding
     */
    function _calcVaultFeeLPAmountWithCompound(
        IPool pool,
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 aeroSwapFeePercent
    ) internal view returns (uint256 vaultFeeShares) {
        // Calculate expected LP from compound
        uint256 expectedLP = _previewCompoundLP(pool, reserve0, reserve1, lpTotalSupply, aeroSwapFeePercent);

        // Calculate protocol fee as percentage of expected LP
        vaultFeeShares = BetterMath._percentageOfWAD(
            expectedLP, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                       Preview State Helper (Stack Relief)                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Result of preview state calculation (reduces stack depth)
    struct PreviewState {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint8 decimalOffset;
    }

    /**
     * @notice Calculates post-compound vault state for preview functions
     * @dev Bundles multiple values into a struct to avoid stack too deep
     * @param pool The Aerodrome pool
     * @param reserve0 Current reserve0
     * @param reserve1 Current reserve1
     * @param lpTotalSupply Current LP total supply
     * @param aeroSwapFeePercent Pool swap fee
     * @return state PreviewState with post-compound values
     */
    function _calcPreviewState(
        IPool pool,
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 aeroSwapFeePercent
    ) internal view returns (PreviewState memory state) {
        // Calculate expected LP from pending compound (includes held excess tokens)
        uint256 pendingCompoundLP = _previewCompoundLP(pool, reserve0, reserve1, lpTotalSupply, aeroSwapFeePercent);

        // Calculate protocol fee from compound
        uint256 protocolFeeLP = BetterMath._percentageOfWAD(
            pendingCompoundLP, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );

        // Post-compound vault state: protocol fee is paid out in LP, so vault assets only increase by net compound.
        uint256 baseLpReserve = IERC20(address(pool)).balanceOf(address(this));
        state.vaultLpReserve = baseLpReserve + (pendingCompoundLP - protocolFeeLP);
        state.vaultTotalShares = ERC20Repo._totalSupply();
        state.decimalOffset = ERC4626Repo._decimalOffset();
    }
}
