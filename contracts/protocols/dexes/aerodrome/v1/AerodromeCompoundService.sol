// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IRouter as IAerodromeRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {AerodromeService} from "@crane/contracts/protocols/dexes/aerodrome/v1/services/AerodromeService.sol";

/**
 * @title AerodromeCompoundService
 * @notice Library for compounding Aerodrome V1 pool fees into LP tokens.
 * @dev Handles:
 *      1. Claiming fees from the pool
 *      2. Proportional deposit of claimed tokens as LP
 *      3. ZapIn of excess token (if any)
 *      4. Protocol fee extraction from compounded LP
 */
library AerodromeCompoundService {
    using BetterSafeERC20 for IERC20;

    /// @notice Emitted when fees are claimed from the pool
    event FeesClaimed(address indexed pool, uint256 amount0, uint256 amount1);

    /// @notice Emitted when fees are compounded into LP
    event FeesCompounded(
        address indexed pool, uint256 lpMinted, uint256 protocolFeeLp, uint256 excessToken0, uint256 excessToken1
    );

    /// @notice Parameters for the compound operation
    struct CompoundParams {
        IAerodromeRouter router;
        IPoolFactory factory;
        IPool pool;
        address token0;
        address token1;
        bool isStable;
        uint256 dustThreshold;
        uint256 deadline;
    }

    /// @notice Result of the compound operation
    struct CompoundResult {
        uint256 claimed0;
        uint256 claimed1;
        uint256 lpMinted;
        uint256 excessToken0;
        uint256 excessToken1;
    }

    // Aerodrome fee denominator
    uint256 constant AERO_FEE_DENOM = 10000;

    /**
     * @notice Claims fees from pool and compounds them into LP tokens.
     * @param params The compound parameters
     * @return result The compound result containing claimed amounts and LP minted
     */
    function _compoundFees(CompoundParams memory params) internal returns (CompoundResult memory result) {
        // Step 1: Claim fees from pool
        (result.claimed0, result.claimed1) = params.pool.claimFees();

        // Early return if no fees to compound
        if (result.claimed0 == 0 && result.claimed1 == 0) {
            return result;
        }

        emit FeesClaimed(address(params.pool), result.claimed0, result.claimed1);

        // Step 2: Get current pool reserves and calculate proportional amounts
        (uint256 reserve0, uint256 reserve1,) = params.pool.getReserves();

        // Calculate maximum proportional deposit
        (uint256 proportional0, uint256 proportional1, uint256 excess0, uint256 excess1) =
            _calculateProportionalAmounts(result.claimed0, result.claimed1, reserve0, reserve1);

        // Step 3: Deposit proportional amounts if we have both tokens
        if (proportional0 > 0 && proportional1 > 0) {
            result.lpMinted = _depositProportional(
                params.router,
                params.factory,
                params.pool,
                params.token0,
                params.token1,
                proportional0,
                proportional1,
                params.isStable,
                params.deadline
            );
        }

        // Step 4: ZapIn excess token if above dust threshold
        if (excess0 > params.dustThreshold) {
            uint256 lpFromZap = _zapInExcess(
                params.router,
                params.factory,
                params.pool,
                IERC20(params.token0),
                IERC20(params.token1),
                excess0,
                params.isStable,
                params.deadline
            );
            result.lpMinted += lpFromZap;
            result.excessToken0 = 0;
        } else {
            result.excessToken0 = excess0;
        }

        if (excess1 > params.dustThreshold) {
            uint256 lpFromZap = _zapInExcess(
                params.router,
                params.factory,
                params.pool,
                IERC20(params.token1),
                IERC20(params.token0),
                excess1,
                params.isStable,
                params.deadline
            );
            result.lpMinted += lpFromZap;
            result.excessToken1 = 0;
        } else {
            result.excessToken1 = excess1;
        }

        emit FeesCompounded(
            address(params.pool),
            result.lpMinted,
            0, // Protocol fee calculated by caller
            result.excessToken0,
            result.excessToken1
        );

        return result;
    }

    /**
     * @notice Calculate proportional deposit amounts from claimed fees
     * @param claimed0 Amount of token0 claimed
     * @param claimed1 Amount of token1 claimed
     * @param reserve0 Pool reserve of token0
     * @param reserve1 Pool reserve of token1
     * @return proportional0 Amount of token0 for proportional deposit
     * @return proportional1 Amount of token1 for proportional deposit
     * @return excess0 Excess token0 after proportional calculation
     * @return excess1 Excess token1 after proportional calculation
     */
    function _calculateProportionalAmounts(uint256 claimed0, uint256 claimed1, uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint256 proportional0, uint256 proportional1, uint256 excess0, uint256 excess1)
    {
        if (claimed0 == 0 || claimed1 == 0) {
            // If we only have one token, it all becomes excess for zap
            return (0, 0, claimed0, claimed1);
        }

        (proportional0, proportional1) = _proportionalDeposit(reserve0, reserve1, claimed0, claimed1);
        excess0 = claimed0 - proportional0;
        excess1 = claimed1 - proportional1;
    }

    /**
     * @dev Core proportional deposit calculation. Given reserves and desired amounts,
     *      returns the maximum proportional amounts that never exceed the provided limits.
     *      Used by _calculateProportionalAmounts to unify math with other Aerodrome modules.
     */
    function _proportionalDeposit(uint256 reserveA, uint256 reserveB, uint256 amountA, uint256 amountB)
        private
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

    /**
     * @notice Deposit proportional amounts of both tokens as LP
     * @param router Aerodrome router
     * @param factory Aerodrome pool factory
     * @param pool The LP pool
     * @param token0 Address of token0
     * @param token1 Address of token1
     * @param amount0 Amount of token0 to deposit
     * @param amount1 Amount of token1 to deposit
     * @param isStable Whether the pool is stable
     * @param deadline Transaction deadline
     * @return lpMinted Amount of LP tokens minted
     */
    function _depositProportional(
        IAerodromeRouter router,
        IPoolFactory factory,
        IPool pool,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        bool isStable,
        uint256 deadline
    ) internal returns (uint256 lpMinted) {
        factory;
        pool;

        // Approve router to spend tokens
        IERC20(token0).approve(address(router), amount0);
        IERC20(token1).approve(address(router), amount1);

        // Add liquidity
        (,, lpMinted) = router.addLiquidity(
            token0,
            token1,
            isStable,
            amount0,
            amount1,
            0, // amountAMin - accept any output
            0, // amountBMin - accept any output
            address(this),
            deadline
        );
    }

    /**
     * @notice ZapIn excess token by swapping half and depositing as LP
     * @param router Aerodrome router
     * @param factory Aerodrome pool factory
     * @param pool The LP pool
     * @param tokenIn The excess token to zap in
     * @param tokenOut The opposing token
     * @param amountIn Amount of excess token
     * @param isStable Whether the pool is stable
     * @param deadline Transaction deadline
     * @return lpMinted Amount of LP tokens minted
     */
    function _zapInExcess(
        IAerodromeRouter router,
        IPoolFactory factory,
        IPool pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        bool isStable,
        uint256 deadline
    ) internal returns (uint256 lpMinted) {
        isStable;

        // Use AerodromeService for zap logic
        AerodromeService.SwapDepositVolatileParams memory params = AerodromeService.SwapDepositVolatileParams({
            router: router,
            factory: factory,
            pool: pool,
            token0: address(tokenIn) < address(tokenOut) ? tokenIn : tokenOut,
            tokenIn: tokenIn,
            opposingToken: tokenOut,
            amountIn: amountIn,
            recipient: address(this),
            deadline: deadline
        });

        lpMinted = AerodromeService._swapDepositVolatile(params);
    }

    /**
     * @notice Preview the LP that would be minted from compounding current claimable fees
     * @param pool The Aerodrome pool
     * @param vault The vault address to check claimable fees for
     * @param swapFeePercent The pool's swap fee percentage
     * @return lpEquivalent Estimated LP tokens from compounding
     */
    function _previewCompoundLP(IPool pool, address vault, uint256 swapFeePercent)
        internal
        view
        returns (uint256 lpEquivalent)
    {
        uint256 claimable0 = pool.claimable0(vault);
        uint256 claimable1 = pool.claimable1(vault);

        if (claimable0 == 0 && claimable1 == 0) {
            return 0;
        }

        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 lpTotalSupply = IERC20(address(pool)).totalSupply();

        return _calculateLPFromFees(claimable0, claimable1, reserve0, reserve1, lpTotalSupply, swapFeePercent);
    }

    /**
     * @notice Calculate LP equivalent from fee amounts (same logic as existing _calculateLPFromPoolFees)
     * @dev This is a pure function for preview calculations
     */
    function _calculateLPFromFees(
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

        // Calculate equivalent token1 for claimable0
        uint256 equiv1 = ConstProdUtils._equivLiquidity(claimable0, reserve0, reserve1);
        uint256 equiv0;
        uint256 remainder0;
        uint256 remainder1;

        if (equiv1 > claimable1) {
            // More token0 than needed proportionally
            equiv0 = ConstProdUtils._equivLiquidity(claimable1, reserve1, reserve0);
            equiv1 = claimable1;
            remainder0 = claimable0 - equiv0;
        } else {
            // More token1 than needed proportionally
            equiv0 = claimable0;
            remainder1 = claimable1 - equiv1;
        }

        // LP from proportional deposit
        uint256 lpFromEquiv = ConstProdUtils._depositQuote(equiv0, equiv1, lpTotalSupply, reserve0, reserve1);

        // LP from zapping remainder (uses swap which has fees)
        uint256 lpFromRemainder;
        if (remainder0 > 0) {
            // This approximates the zap: swap half, then deposit
            // The actual zap is more complex, but this gives a good estimate
            uint256 swapAmount = remainder0 / 2;
            uint256 swapOut = _getAmountOutWithFee(swapAmount, reserve0, reserve1, swapFeePercent);
            // After swap, reserves change
            uint256 newReserve0 = reserve0 + swapAmount;
            uint256 newReserve1 = reserve1 - swapOut;
            lpFromRemainder = ConstProdUtils._depositQuote(
                remainder0 - swapAmount, swapOut, lpTotalSupply + lpFromEquiv, newReserve0, newReserve1
            );
        } else if (remainder1 > 0) {
            uint256 swapAmount = remainder1 / 2;
            uint256 swapOut = _getAmountOutWithFee(swapAmount, reserve1, reserve0, swapFeePercent);
            uint256 newReserve1 = reserve1 + swapAmount;
            uint256 newReserve0 = reserve0 - swapOut;
            lpFromRemainder = ConstProdUtils._depositQuote(
                swapOut, remainder1 - swapAmount, lpTotalSupply + lpFromEquiv, newReserve0, newReserve1
            );
        }

        return lpFromEquiv + lpFromRemainder;
    }

    /**
     * @notice Calculate amount out for a swap with fee
     * @param amountIn Input amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @param feePercent Fee percentage (out of 10000)
     * @return amountOut Output amount after fee
     */
    function _getAmountOutWithFee(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 feePercent)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * (AERO_FEE_DENOM - feePercent);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * AERO_FEE_DENOM + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
