// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    UniswapV3StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol";

abstract contract UniswapV3StandardExchangeOutBase is UniswapV3StandardExchangeCommon, ReentrancyLockModifiers {
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
            uint256 reserveOut = tokenOut == _token0() ? reserve0 : reserve1;
            if (reserveOut == 0) return 0;
            sharesRequired = (desiredAmountOut * totalShares + reserveOut - 1) / reserveOut;
            return sharesRequired > totalShares ? totalShares : sharesRequired;
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

        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            uint256 amountOut = _quoteZapOutAmount(tokenOut, mid, totalShares);
            if (amountOut >= desiredAmountOut) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return _bufferedWithdrawalShares(high, totalShares);
    }

    function _bufferedWithdrawalShares(uint256 shares, uint256 supply) private pure returns (uint256) {
        if (shares >= supply) return supply;
        uint256 buffer = Math.max(shares / 100, 1);
        return buffer > supply - shares ? supply : shares + buffer;
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
