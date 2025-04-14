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

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";
import {SlipstreamStandardExchangeCommon} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol";

/**
 * @title SlipstreamStandardExchangeOutTarget - Exchange out operations for Slipstream vaults.
 * @author cyotee doge <doge.cyotee>
 * @notice Handles withdrawal and swap operations for Slipstream concentrated liquidity positions.
 */
contract SlipstreamStandardExchangeOutTarget is SlipstreamStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using BetterSafeERC20 for IERC20;

    /* ------------------------- Custom Errors ------------------------- */
    
    error SlipstreamExchangeOut_DeadlineExceeded();
    error SlipstreamExchangeOut_InsufficientOutput();
    error SlipstreamExchangeOut_ZeroShares();
    error SlipstreamExchangeOut_SlippageExceeded();

    /* ------------------------- IStandardExchangeOut ------------------------ */

    /// @notice Preview the amount of tokens required for a desired output
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        override
        returns (uint256 amountIn)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Passthrough swap: token0 <-> token1
        if ((address(tokenIn) == token0 && address(tokenOut) == token1) ||
            (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwapOut(address(tokenIn), address(tokenOut), amountOut);
        }

        // ZapOut withdrawal: vault shares -> token0/token1 (Route 4)
        if (address(tokenIn) == address(this) && 
            (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutWithdrawal(tokenOut, amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    /// @notice Execute a swap or withdrawal
    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    )
        external
        override
        lock
        returns (uint256 amountIn)
    {
        if (deadline < block.timestamp) revert SlipstreamExchangeOut_DeadlineExceeded();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Passthrough swap: token0 <-> token1
        if ((address(tokenIn) == token0 && address(tokenOut) == token1) ||
            (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            amountIn = _quoteSwapOut(address(tokenIn), address(tokenOut), amountOut);
            if (amountIn > maxAmountIn) revert SlipstreamExchangeOut_InsufficientOutput();

            _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            _swap(address(tokenIn), address(tokenOut), amountIn, amountOut, recipient);
            _refundExcess(tokenIn, maxAmountIn, amountIn, pretransferred, msg.sender);

            return amountIn;
        }

        // ZapOut withdrawal: vault shares -> token0/token1 (Route 4)
        if (address(tokenIn) == address(this) && 
            (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            // For zap out, tokenIn is the vault shares (this), amountOut is desired token output
            // maxAmountIn represents the max shares to burn
            amountIn = _executeZapOutWithdrawal(tokenOut, maxAmountIn, amountOut, recipient);
            return amountIn;
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    /* -------------------------------------------------------------------------- */
    /*                           ZapOut Withdrawal Logic (Route 4)                      */
    /* -------------------------------------------------------------------------- */

    /// @notice Preview zap-out withdrawal - convert desired token output to required shares
    /// @dev Uses ConstProdUtils._withdrawQuote for entitlement calculation
    function _previewZapOutWithdrawal(IERC20 tokenOut, uint256 desiredAmountOut)
        internal
        view
        returns (uint256 sharesRequired)
    {
        if (desiredAmountOut == 0) revert SlipstreamExchangeOut_ZeroShares();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        bool zeroForOne = address(tokenOut) == token0;
        
        // Get total vault reserves and total shares
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        uint256 totalShares = IERC20(address(this)).totalSupply();
        
        if (totalShares == 0) revert SlipstreamExchangeOut_ZeroShares();
        
        // Calculate shares required using proportional conversion
        uint256 outputReserve = zeroForOne ? reserve0 : reserve1;
        sharesRequired = (desiredAmountOut * totalShares) / outputReserve;
        
        // Add small buffer for slippage
        sharesRequired = sharesRequired * 10001 / 10000;
    }

    /// @notice Execute zap-out withdrawal - burn shares, return tokens via pool.burn()
    /// @dev Burns liquidity from pool, collects fees, swaps if needed
    function _executeZapOutWithdrawal(
        IERC20 tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 sharesBurned) {
        // Collect fees first
        _collectFees();
        
        // Get position and liquidity info
        (int24 tickLower, int24 tickUpper, uint128 currentLiquidity) = _getPositionLiquidityInfo();
        
        // Calculate proportional liquidity to burn based on shares
        uint256 totalShares = IERC20(address(this)).totalSupply();
        uint128 liquidityToBurn = uint128((maxSharesToBurn * currentLiquidity) / totalShares);
        
        // Ensure minimum liquidity burn
        if (liquidityToBurn == 0) revert SlipstreamExchangeOut_ZeroShares();
        
        // Burn, collect, and get amounts
        (uint256 amount0, uint256 amount1) = _burnAndCollect(tickLower, tickUpper, liquidityToBurn);
        
        // Calculate shares burned (proportional to liquidity removed)
        sharesBurned = uint256((liquidityToBurn * totalShares) / currentLiquidity);
        
        // Process withdrawal and handle swap
        _processWithdrawal(tokenOut, amount0, amount1, sharesBurned, minAmountOut, recipient);
    }

    /// @notice Get position ticks and current liquidity
    function _getPositionLiquidityInfo() internal view returns (int24 tickLower, int24 tickUpper, uint128 liquidity) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        bytes32 positionKey = SlipstreamVaultRepo._getOwnPositionKey();
        
        (tickLower, tickUpper) = SlipstreamVaultRepo._getPositionTicks();
        (liquidity, , , , ) = pool.positions(positionKey);
        
        if (liquidity == 0) revert SlipstreamExchangeOut_ZeroShares();
    }

    /// @notice Process withdrawal after burn
    function _processWithdrawal(
        IERC20 tokenOut,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesBurned,
        uint256 minAmountOut,
        address recipient
    ) internal {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        bool zeroForOne = address(tokenOut) == token0;
        
        // Calculate actual output based on which token user wants
        uint256 amountOut = zeroForOne ? amount0 : amount1;
        
        // Enforce minimum output
        if (amountOut < minAmountOut) revert SlipstreamExchangeOut_SlippageExceeded();
        
        // Handle swap if needed
        _handleZapOutSwap(zeroForOne, amount0, amount1, token0);
        
        // Update position liquidity in repo
        _updatePositionLiquidityInRepo();
        
        // Burn shares from sender
        ERC20Repo._burn(msg.sender, sharesBurned);
        
        // Transfer output tokens to recipient
        IERC20(address(tokenOut)).safeTransfer(recipient, amountOut);
    }

    /// @notice Update position liquidity in repo
    function _updatePositionLiquidityInRepo() internal {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        bytes32 positionKey = SlipstreamVaultRepo._getOwnPositionKey();
        (uint128 newLiquidity, , , , ) = pool.positions(positionKey);
        SlipstreamVaultRepo._updatePositionLiquidity(newLiquidity);
    }

    /// @notice Handle swap for zap-out if needed
    function _handleZapOutSwap(bool zeroForOne, uint256 amount0, uint256 amount1, address token0) internal {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        
        if (zeroForOne && amount1 > 0) {
            // Received token1 but want token0 - swap
            IERC20(pool.token1()).forceApprove(address(pool), amount1);
            _swap(pool.token1(), token0, amount1, 0, address(this));
        } else if (!zeroForOne && amount0 > 0) {
            // Received token0 but want token1 - swap
            IERC20(token0).forceApprove(address(pool), amount0);
            _swap(token0, pool.token1(), amount0, 0, address(this));
        }
    }

    /// @notice Burn liquidity and collect from pool
    function _burnAndCollect(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityToBurn
    ) internal returns (uint256 amount0, uint256 amount1) {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();
        
        // Snapshot balances before burn
        uint256 bal0Before = IERC20(token0).balanceOf(address(this));
        uint256 bal1Before = IERC20(token1).balanceOf(address(this));
        
        // Burn liquidity from pool
        pool.burn(tickLower, tickUpper, liquidityToBurn);
        
        // Collect fees owed
        pool.collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
        
        // Get amounts returned from burn + fees
        amount0 = IERC20(token0).balanceOf(address(this)) - bal0Before;
        amount1 = IERC20(token1).balanceOf(address(this)) - bal1Before;
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

    /// @notice Quote a swap for exact output (reverse quote)
    function _quoteSwapOut(address tokenIn, address /*tokenOut*/, uint256 amountOut)
        internal
        view
        override
        returns (uint256 amountIn)
    {
        SlipstreamPositionState memory state = _loadPositionState();
        bool zeroForOne = tokenIn == state.token0;

        amountIn = SlipstreamUtils._quoteExactOutputSingle(
            amountOut,
            state.sqrtPriceX96,
            state.liquidity,
            state.fee + state.unstakedFee,
            zeroForOne
        );
    }

    /// @notice Securely transfer tokens into the vault
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            require(
                tokenIn.balanceOf(address(this)) >= amountIn,
                "SlipstreamExchangeOut: insufficient pretransferred balance"
            );
            return amountIn;
        }

        uint256 balBefore = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        actualIn = tokenIn.balanceOf(address(this)) - balBefore;
    }

    /// @notice Refund excess tokens
    function _refundExcess(
        IERC20 token,
        uint256 maxAmount,
        uint256 usedAmount,
        bool pretransferred,
        address recipient
    ) internal {
        if (pretransferred && maxAmount > usedAmount) {
            uint256 refund = maxAmount - usedAmount;
            token.safeTransfer(recipient, refund);
        }
    }
}
