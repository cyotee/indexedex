// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SlipstreamUtils} from "@crane/contracts/utils/math/SlipstreamUtils.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";
import {SlipstreamStandardExchangeCommon} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol";

/**
 * @title SlipstreamStandardExchangeInTarget - Exchange in operations for Slipstream vaults.
 * @author cyotee doge <doge.cyotee>
 * @notice Handles deposit and swap operations for Slipstream concentrated liquidity positions.
 */
contract SlipstreamStandardExchangeInTarget is SlipstreamStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeIn {
    using BetterSafeERC20 for IERC20;

    /* ------------------------- Custom Errors ------------------------- */
    
    error SlipstreamExchangeIn_DeadlineExceeded();
    error SlipstreamExchangeIn_InsufficientOutput();
    error SlipstreamExchangeIn_ZeroDeposit();
    error SlipstreamExchangeIn_SlippageExceeded();

    /* ------------------------- IStandardExchangeIn ------------------------ */

    /// @notice Preview the amount of tokens/shares received for an exchange in operation
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        override
        returns (uint256 amountOut)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Passthrough swap: token0 <-> token1
        if ((address(tokenIn) == token0 && address(tokenOut) == token1) ||
            (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwap(address(tokenIn), address(tokenOut), amountIn);
        }

        // ZapIn deposit: token0/token1 -> vault shares (Route 3)
        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            return _previewZapInDeposit(tokenIn, amountIn);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    /// @notice Execute a swap or deposit
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    )
        external
        override
        lock
        returns (uint256 amountOut)
    {
        if (deadline < block.timestamp) revert SlipstreamExchangeIn_DeadlineExceeded();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Passthrough swap: token0 <-> token1
        if ((address(tokenIn) == token0 && address(tokenOut) == token1) ||
            (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut = _swap(address(tokenIn), address(tokenOut), actualIn, minAmountOut, recipient);
            return amountOut;
        }

        // ZapIn deposit: token0/token1 -> vault shares (Route 3)
        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut = _executeZapInDeposit(tokenIn, actualIn, minAmountOut, recipient);
            return amountOut;
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    /* -------------------------------------------------------------------------- */
    /*                           ZapIn Deposit Logic (Route 3)                      */
    /* -------------------------------------------------------------------------- */

    /// @notice Preview zap-in deposit - convert token input to expected vault shares
    /// @dev Uses actual pool.mint() amounts for share calculation
    function _previewZapInDeposit(IERC20 tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 sharesOut)
    {
        if (amountIn == 0) revert SlipstreamExchangeIn_ZeroDeposit();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        bool zeroForOne = address(tokenIn) == token0;

        // Get current vault reserves (position value + uncollected fees)
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        uint256 totalShares = IERC20(address(this)).totalSupply();

        // Convert input token to both sides via swap
        (uint256 amount0, uint256 amount1) = _quoteZapInConversion(zeroForOne, amountIn);

        // If no existing shares, this is initial deposit
        if (totalShares == 0 || !SlipstreamVaultRepo._isPositionCreated()) {
            // Initial deposit: shares = total deposited (normalized)
            sharesOut = amount0 + amount1;
        } else {
            // Calculate shares using ConstProdUtils._depositQuote
            sharesOut = ConstProdUtils._depositQuote(
                amount0,
                amount1,
                totalShares,
                reserve0,
                reserve1
            );
        }
    }

    /// @notice Execute zap-in deposit - deposit tokens and receive vault shares
    /// @dev Collects fees, creates position on first deposit, then adds liquidity via pool.mint()
    function _executeZapInDeposit(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minSharesOut,
        address recipient
    ) internal returns (uint256 sharesOut) {
        if (amountIn == 0) revert SlipstreamExchangeIn_ZeroDeposit();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        bool zeroForOne = address(tokenIn) == token0;

        // Collect fees from position before deposit
        _collectFees();

        // Snapshot shares before deposit
        uint256 totalSharesBefore = IERC20(address(this)).totalSupply();

        // Get zap conversion quote (swap input token to both sides)
        (uint256 amount0, uint256 amount1) = _quoteZapInConversion(zeroForOne, amountIn);

        // Ensure vault has tokens for deposit
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(zeroForOne ? pool.token1() : token0).safeTransferFrom(msg.sender, address(this), amount1);

        // Approve pool to pull tokens
        IERC20(token0).forceApprove(address(pool), amount0);
        IERC20(pool.token1()).forceApprove(address(pool), amount1);

        // Create position on first deposit, or add to existing
        if (!SlipstreamVaultRepo._isPositionCreated()) {
            // First deposit - create position
            (int24 newTickLower, int24 newTickUpper) = _getPositionTicksForDeposit();
            SlipstreamVaultRepo._createPositionIfNeeded(newTickLower, newTickUpper);
        }

        // Get position ticks
        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks();

        // Add liquidity to pool - use maxUint128 since we want to deposit all approved amounts
        // The actual amounts used will be returned
        uint128 liquidity = _getLiquidityForAmounts(amount0, amount1, tickLower, tickUpper);
        
        // Call pool.mint to add liquidity - this will pull exact amounts needed
        (uint256 amount0Used, uint256 amount1Used) = _mintLiquidity(
            address(this),
            tickLower,
            tickUpper,
            liquidity
        );

        // Update position liquidity in repo
        (uint128 currentLiquidity, , , , ) = pool.positions(SlipstreamVaultRepo._getOwnPositionKey());
        SlipstreamVaultRepo._updatePositionLiquidity(currentLiquidity);

        // Calculate shares based on actual amounts used from mint
        sharesOut = _calculateSharesForDeposit(amount0Used, amount1Used, totalSharesBefore);

        // Enforce slippage protection
        if (sharesOut < minSharesOut) revert SlipstreamExchangeIn_SlippageExceeded();

        // Mint shares to recipient
        ERC20Repo._mint(recipient, sharesOut);
    }

    /// @notice Calculate shares for a deposit
    /// @dev Handles both initial deposit and subsequent deposits
    function _calculateSharesForDeposit(
        uint256 amount0Used,
        uint256 amount1Used,
        uint256 totalSharesBefore
    ) internal view returns (uint256 sharesOut) {
        if (totalSharesBefore == 0) {
            // Initial deposit: shares = actual amounts deposited (normalized)
            sharesOut = amount0Used + amount1Used;
        } else {
            // Include uncollected fees in reserves for proper share calculation
            (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
            sharesOut = ConstProdUtils._depositQuote(
                amount0Used,
                amount1Used,
                totalSharesBefore,
                reserve0,
                reserve1
            );
        }
    }

    /// @notice Collect fees from the vault's position
    function _collectFees() internal {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks();
        bytes32 positionKey = SlipstreamVaultRepo._getOwnPositionKey();
        
        // Check if position has fees owed
        (, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(positionKey);
        
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            pool.collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );
        }
    }

    /// @notice Get position ticks based on current price and width multiplier
    function _getPositionTicksForDeposit() internal view returns (int24 tickLower, int24 tickUpper) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        (, int24 currentTick, , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();
        uint24 widthMultiplier = SlipstreamVaultRepo._widthMultiplier();
        
        int24 halfWidth = int24(uint24(widthMultiplier)) * tickSpacing / 2;
        tickLower = currentTick - halfWidth;
        tickUpper = currentTick + halfWidth;
    }

    /// @notice Calculate liquidity for given amounts
    function _getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint128 liquidity) {
        // Use sqrtPrice and tick range to calculate liquidity
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
        
        liquidity = SlipstreamUtils._quoteLiquidityForAmounts(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            amount0,
            amount1
        );
    }

    /// @notice Call pool.mint to add liquidity
    function _mintLiquidity(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal returns (uint256 amount0Used, uint256 amount1Used) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        
        // Approve pool for max to handle rounding
        address token0 = pool.token0();
        address token1 = pool.token1();
        
        uint256 bal0Before = IERC20(token0).balanceOf(address(this));
        uint256 bal1Before = IERC20(token1).balanceOf(address(this));
        
        // Call mint - this will pull exact amounts needed
        pool.mint(recipient, tickLower, tickUpper, liquidity, bytes(""));
        
        amount0Used = bal0Before - IERC20(token0).balanceOf(address(this));
        amount1Used = bal1Before - IERC20(token1).balanceOf(address(this));
    }

    /// @notice Quote zap-in conversion - convert single token to both pool tokens
    /// @dev Uses a 50/50 split for simplicity
    function _quoteZapInConversion(bool zeroForOne, uint256 amountIn)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        // For simplicity, assume 50/50 split after swap
        amount0 = zeroForOne ? amountIn : amountIn / 2;
        amount1 = zeroForOne ? amountIn / 2 : amountIn;
    }

    /// @notice Securely transfer tokens into the vault
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            require(
                tokenIn.balanceOf(address(this)) >= amountIn,
                "SlipstreamExchangeIn: insufficient pretransferred balance"
            );
            return amountIn;
        }

        uint256 balBefore = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        actualIn = tokenIn.balanceOf(address(this)) - balBefore;
    }
}
