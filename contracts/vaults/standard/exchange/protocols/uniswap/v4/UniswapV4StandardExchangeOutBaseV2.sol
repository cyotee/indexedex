// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeConstantProduct} from "../StandardExchangeConstantProduct.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {UniswapV4PositionRepoV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4PositionRepoV2.sol";
import {
    UniswapV4StandardExchangeCommonV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeCommonV2.sol";

/// @dev Shared Out types/helpers for Query + Execute Targets (Option 1b — siblings of Common).
abstract contract UniswapV4StandardExchangeOutBaseV2 is
    UniswapV4StandardExchangeCommonV2,
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
            return tokenOut == _token0()
                ? StandardExchangeConstantProduct._sharesForSingleExit(reserve0, reserve1, desiredAmountOut, totalShares)
                : StandardExchangeConstantProduct._sharesForSingleExit(reserve1, reserve0, desiredAmountOut, totalShares);
        }

        if (_supportsInventoryQuote()) {
            return _inventorySharesIn(_inventorySnapshot(tokenOut, address(this)), desiredAmountOut);
        }

        // Retain the original quote for hooked, imported and multi-position pools.
        // A one-asset sleeve has a linear withdrawal quote and needs no pool search.
        if (_currentLiquidity() == 0) {
            (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
            bool token0 = tokenOut == _token0();
            if ((token0 ? free1 : free0) == 0) {
                uint256 reserve = token0 ? free0 : free1;
                if (desiredAmountOut >= reserve) return totalShares;
                return _bufferedInventoryShares(
                    Math.mulDiv(desiredAmountOut, totalShares, reserve, Math.Rounding.Ceil), totalShares
                );
            }
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

        return _bufferedInventoryShares(high, totalShares);
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
        amount0 += (free0 * sharesBurned) / totalShares;
        amount1 += (free1 * sharesBurned) / totalShares;
        if (tokenOut == _token0()) {
            return amount0 + (amount1 > 0 ? _quoteSwapAfterWithdrawal(amount1, false, sharesBurned, totalShares) : 0);
        }
        return amount1 + (amount0 > 0 ? _quoteSwapAfterWithdrawal(amount0, true, sharesBurned, totalShares) : 0);
    }
}
