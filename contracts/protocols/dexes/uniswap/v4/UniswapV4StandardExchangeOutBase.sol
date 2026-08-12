// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {
    UniswapV4StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";

/// @dev Shared Out types/helpers for Query + Execute Targets (Option 1b — siblings of Common).
abstract contract UniswapV4StandardExchangeOutBase is
    UniswapV4StandardExchangeCommon,
    ReentrancyLockModifiers
{
    error ExchangeOutNotAvailable();

    struct ZapOutState {
        uint256 totalShares;
        address token0;
        address token1;
        uint256 balance0Before;
        uint256 balance1Before;
        uint256 amount0;
        uint256 amount1;
        uint256 actualOut;
    }

    error UniswapV4ExchangeOut_DeadlineExceeded();
    error UniswapV4ExchangeOut_SlippageExceeded();
    error UniswapV4ExchangeOut_InsufficientInput();

    function _previewZapOutWithdrawal(address tokenOut, uint256 desiredAmountOut)
        internal
        view
        returns (uint256 sharesRequired)
    {
        if (desiredAmountOut == 0) {
            return 0;
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0) {
            return 0;
        }

        // Blocked: sleeve cover only — shares from total reserve of tokenOut.
        if (!canOpenPoolManagerUnlock()) {
            (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
            uint256 reserveOut = tokenOut == _token0() ? reserve0 : reserve1;
            if (reserveOut == 0) return 0;
            // ceil(desired * totalShares / reserveOut)
            sharesRequired = (desiredAmountOut * totalShares + reserveOut - 1) / reserveOut;
            return sharesRequired > totalShares ? totalShares : sharesRequired;
        }

        if (!UniswapV4PositionRepo._isPositionCreated() && !UniswapV4PositionRepo._isImportedPosition()) {
            (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
            uint256 reserveOut = tokenOut == _token0() ? reserve0 : reserve1;
            if (reserveOut == 0) return 0;
            sharesRequired = (desiredAmountOut * totalShares + reserveOut - 1) / reserveOut;
            return sharesRequired > totalShares ? totalShares : sharesRequired;
        }

        uint256 low = 1;
        uint256 high = totalShares;

        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            uint256 amountOut = _quoteZapOutAmount(tokenOut, mid, totalShares);

            if (amountOut >= desiredAmountOut) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if (high < totalShares) {
            uint256 buffer = high / 100;
            if (buffer == 0) {
                buffer = 1;
            }
            uint256 buffered = high + buffer;
            return buffered > totalShares ? totalShares : buffered;
        }
        return high;
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        (uint256 free0, uint256 free1) = _freeBalances();
        amount0 += (free0 * sharesBurned) / totalShares;
        amount1 += (free1 * sharesBurned) / totalShares;
        if (tokenOut == _token0()) {
            return amount0 + (amount1 > 0 ? _quoteSwapIn(amount1, false) : 0);
        }
        return amount1 + (amount0 > 0 ? _quoteSwapIn(amount0, true) : 0);
    }
}
