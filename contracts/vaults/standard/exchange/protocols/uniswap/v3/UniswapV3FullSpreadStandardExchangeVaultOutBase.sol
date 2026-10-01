// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeConstantProduct} from "../StandardExchangeConstantProduct.sol";

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV3FullSpreadStandardExchangeVaultRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultCommon
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

abstract contract UniswapV3FullSpreadStandardExchangeVaultOutBase is UniswapV3FullSpreadStandardExchangeVaultCommon, ReentrancyLockModifiers {
    struct ZapOutState {
        uint256 totalShares;
        address token0;
        address token1;
        uint256 outBalanceBefore;
        uint256 amount0;
        uint256 amount1;
        uint256 actualOut;
    }

    error UniswapV3ExchangeOut_DeadlineExceeded();
    error UniswapV3ExchangeOut_InsufficientOutput();
    error UniswapV3ExchangeOut_ZeroShares();
    error UniswapV3ExchangeOut_SlippageExceeded();
    error UniswapV3ExchangeOut_InsufficientInput();

    /// @notice Minimal single-token input to mint exactly `sharesOut` (D64 exact-out mint).
    /// @dev Inverts the single-token deposit branch against the same owed-inclusive reserve
    /// basis the deposit preview and `exchangeRate` use, so preview and execution agree to
    /// the wei. Reverts `InsufficientBacking` when no closed form exists (empty book, or the
    /// deposited side reserve is zero), leaving that route unsupported per the owner ruling.
    function _amountInForZapMint(address tokenIn, uint256 sharesOut) internal view returns (uint256) {
        return _amountInForZapMint(tokenIn, sharesOut, 0);
    }

    /// @dev Bounded prepaid input (including the part to refund) is not pre-deposit backing.
    function _amountInForZapMint(address tokenIn, uint256 sharesOut, uint256 prepaidCredit)
        internal view returns (uint256)
    {
        uint256 supply = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
        return tokenIn == _token0()
            ? StandardExchangeConstantProduct._amountInForShares(reserve0 - prepaidCredit, reserve1, sharesOut, supply)
            : StandardExchangeConstantProduct._amountInForShares(reserve1 - prepaidCredit, reserve0, sharesOut, supply);
    }

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

        if (!canOpenBoundPoolOps()) {
            (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
            return tokenOut == _token0()
                ? StandardExchangeConstantProduct._sharesForSingleExit(reserve0, reserve1, desiredAmountOut, totalShares)
                : StandardExchangeConstantProduct._sharesForSingleExit(reserve1, reserve0, desiredAmountOut, totalShares);
        }

        // A one-asset sleeve has a linear withdrawal quote and needs no pool search.
        if (_getPositionLiquidityFromPool() == 0) {
            (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
            bool token0 = tokenOut == _token0();
            if ((token0 ? free1 : free0) == 0) {
                uint256 reserve = token0 ? free0 : free1;
                if (desiredAmountOut >= reserve) return totalShares;
                return _bufferedWithdrawalShares(
                    Math.mulDiv(desiredAmountOut, totalShares, reserve, Math.Rounding.Ceil), totalShares
                );
            }
        }

        uint256 low = 1;
        uint256 high = totalShares;
        uint256 below;
        uint256 above = _quoteZapOutAmount(tokenOut, high, totalShares);
        if (above < desiredAmountOut) return totalShares;
        uint256 probes;

        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            // Interpolate within forward-verified bounds before falling back to
            // bisection. Both paths retain the minimum sufficient share amount.
            if (above > below && probes < 8) {
                mid = low - 1 + Math.mulDiv(desiredAmountOut - below, high - low + 1, above - below);
                mid = Math.max(low, Math.min(mid, high - 1));
                ++probes;
            }
            uint256 amountOut = _quoteZapOutAmount(tokenOut, mid, totalShares);
            if (amountOut >= desiredAmountOut) {
                high = mid;
                above = amountOut;
            } else {
                low = mid + 1;
                below = amountOut;
            }
        }

        return _bufferedWithdrawalShares(high, totalShares);
    }

    /// @dev Exact-out share quote clamp. The former 1% pad (`shares + max(shares / 100, 1)`) was removed under
    ///      APEX D55 (2026-09-21): the forward quote is wei-exact against execution, execution pays exactly the
    ///      requested amount, and any zap-out surplus stays in the vault, so the minimal sufficient share count
    ///      is the exact quote. A quote at or above the supply is the whole supply.
    function _bufferedWithdrawalShares(uint256 shares, uint256 supply) private pure returns (uint256) {
        return shares >= supply ? supply : shares;
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
