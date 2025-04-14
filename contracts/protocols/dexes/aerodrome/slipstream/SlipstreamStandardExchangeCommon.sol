// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SlipstreamUtils} from "@crane/contracts/utils/math/SlipstreamUtils.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo, SlipstreamVaultRepo as VaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";

/**
 * @title SlipstreamStandardExchangeCommon - Shared utilities for Slipstream vault operations.
 * @author cyotee doge <doge.cyotee>
 * @notice Contains common logic for Slipstream concentrated liquidity position management.
 */
contract SlipstreamStandardExchangeCommon {
    using BetterSafeERC20 for IERC20;

    // Type aliases for clarity
    type Position is bytes32;

    /* -------------------------------------------------------------------------- */
    /*                                Data Structures                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Slipstream position state for quotes and calculations
    struct SlipstreamPositionState {
        ICLPool pool;
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 fee;
        uint24 unstakedFee;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Position Management                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Load the current pool state
    function _loadPoolState() internal view returns (
        address token0,
        address token1,
        uint160 sqrtPriceX96,
        int24 tick,
        uint24 fee,
        uint24 unstakedFee
    ) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        token0 = pool.token0();
        token1 = pool.token1();
        (sqrtPriceX96, tick, , , , ) = pool.slot0();
        fee = pool.fee();
        unstakedFee = pool.unstakedFee();
    }

    /// @notice Load the single position state
    function _loadPositionState() internal view returns (SlipstreamPositionState memory state) {
        (state.token0, state.token1, state.sqrtPriceX96, state.tick, state.fee, state.unstakedFee) = _loadPoolState();
        state.pool = SlipstreamPoolAwareRepo._slipstreamPool();
        
        // Get position from vault repo (single position, no index)
        SlipstreamVaultRepo.Position memory pos = SlipstreamVaultRepo._getPosition();
        state.tickLower = pos.tickLower;
        state.tickUpper = pos.tickUpper;
        state.liquidity = pos.liquidity;
    }

    /// @notice Calculate total vault reserves from the single position
    /// @dev Gets reserves from the position's actual liquidity in the pool
    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        if (!SlipstreamVaultRepo._isPositionCreated()) return (0, 0);
        
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        (, , uint160 sqrtPriceX96, , , ) = pool.slot0();
        
        // Get actual liquidity from pool
        bytes32 positionKey = SlipstreamVaultRepo._getOwnPositionKey();
        (uint128 liquidity, , , , ) = pool.positions(positionKey);
        
        if (liquidity > 0) {
            (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks();
            (reserve0, reserve1) = SlipstreamUtils._quoteAmountsForLiquidity(
                sqrtPriceX96,
                tickLower,
                tickUpper,
                liquidity
            );
        }
    }

    /// @notice Get position key for the vault's single position
    function _getPositionKey() internal view returns (bytes32) {
        return SlipstreamVaultRepo._getOwnPositionKey();
    }

    /// @notice Get the current liquidity of the position from the pool
    function _getPositionLiquidityFromPool() internal view returns (uint128) {
        bytes32 key = _getPositionKey();
        (uint128 liquidity, , , , ) = ICLPool(SlipstreamPoolAwareRepo._slipstreamPool()).positions(key);
        return liquidity;
    }

    /// @notice Check if position is in-range (double-sided)
    function _isPositionInRange() internal view returns (bool) {
        if (!SlipstreamVaultRepo._isPositionCreated()) return false;
        (, , , int24 currentTick, , ) = _loadPoolState();
        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks();
        return currentTick >= tickLower && currentTick < tickUpper;
    }

    /// @notice Get the strategy configuration
    function _getStrategyConfig() internal view returns (SlipstreamVaultRepo.StrategyConfig memory) {
        return SlipstreamVaultRepo._strategy();
    }

    /* -------------------------------------------------------------------------- */
    /*                           Value Calculation                                 */
    /* -------------------------------------------------------------------------- */

    /// @notice Calculate the value of the position in terms of token0 and token1
    function _calculatePositionValue() internal view returns (uint256 valueToken0, uint256 valueToken1) {
        if (!SlipstreamVaultRepo._isPositionCreated()) return (0, 0);
        
        SlipstreamPositionState memory state = _loadPositionState();
        if (state.liquidity == 0) {
            return (0, 0);
        }

        (valueToken0, valueToken1) = SlipstreamUtils._quoteAmountsForLiquidity(
            state.sqrtPriceX96,
            state.tickLower,
            state.tickUpper,
            state.liquidity
        );
    }

    /// @notice Calculate total value of all positions (alias for _totalVaultReserves)
    function _calculateTotalValue() internal view returns (uint256 valueToken0, uint256 valueToken1) {
        return _totalVaultReserves();
    }

    /* -------------------------------------------------------------------------- */
    /*                                Swap Helpers                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Quote a swap (preview) - simplified implementation
    /// @dev Uses pool liquidity for quote; actual implementation would use vault positions
    function _quoteSwap(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        (, , uint160 sqrtPriceX96, , uint24 fee, uint24 unstakedFee) = _loadPoolState();
        bool zeroForOne = tokenIn < tokenOut;

        // Simplified quote - use max uint128 as liquidity placeholder
        // Actual implementation should use actual pool liquidity
        amountOut = SlipstreamUtils._quoteExactInputSingle(
            amountIn,
            sqrtPriceX96,
            type(uint128).max,
            fee + unstakedFee,
            zeroForOne
        );
    }

    /// @notice Get pool reserves from slot0
    function _getPoolReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        // For CL pools, we need to query observations or use other methods
        // This is a placeholder - actual implementation may need to use different approach
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
        
        // Estimate reserves based on virtual liquidity
        // In reality, CL pools don't have simple reserve concept
        // This is simplified for now
        reserve0 = 0;
        reserve1 = 0;
    }

    /// @notice Estimate pool liquidity from reserves (approximation)
    function _estimatePoolLiquidity(uint256 reserve0, uint256 reserve1, uint160 /*sqrtPriceX96*/) internal pure returns (uint128) {
        if (reserve0 == 0 || reserve1 == 0) return 0;
        // Simplified estimation
        return uint128(reserve0); // Placeholder
    }

    /// @notice Quote a swap for exact output (reverse quote)
    function _quoteSwapOut(address tokenIn, address /*tokenOut*/, uint256 amountOut)
        internal
        view
        virtual
        returns (uint256 amountIn)
    {
        (address token0, , uint160 sqrtPriceX96, , uint24 fee, uint24 unstakedFee) = _loadPoolState();
        bool zeroForOne = tokenIn == token0;

        amountIn = SlipstreamUtils._quoteExactOutputSingle(
            amountOut,
            sqrtPriceX96,
            1e18, // Placeholder liquidity
            fee + unstakedFee,
            zeroForOne
        );
    }

    /// @notice Execute a swap on the pool
    function _swap(
        address tokenIn,
        address /*tokenOut*/,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        bool zeroForOne = tokenIn == pool.token0();

        (int256 amount0, int256 amount1) = pool.swap(
            recipient,
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            bytes("")
        );

        amountOut = zeroForOne ? uint256(-amount1) : uint256(-amount0);
        require(amountOut >= minAmountOut, "SlipstreamCommon: insufficient output");
    }
}
