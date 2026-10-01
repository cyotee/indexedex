// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";


import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {StandardExchangeConstantProduct} from "../../../StandardExchangeConstantProduct.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultCommon
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol";

/// @dev Shared Out types/helpers for Query + Execute Targets (Option 1b — siblings of Common).
abstract contract UniswapV4FullSpreadHooklessStandardExchangeVaultOutBase is
    UniswapV4FullSpreadHooklessStandardExchangeVaultCommon,
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

    /// @notice Minimal single-token input to mint exactly `sharesOut` (D64 exact-out mint).
    /// @dev Inverts the single-token deposit branch against the same total-reserve basis the
    /// deposit preview uses, so preview and execution agree. Reverts `InsufficientBacking` when
    /// no closed form exists (empty book, or the deposited-side reserve is zero).
    function _amountInForZapMint(address tokenIn, uint256 sharesOut) internal view returns (uint256) {
        return _amountInForZapMint(tokenIn, sharesOut, 0);
    }

    /// @dev Bounded prepaid input (including the part to refund) is not pre-deposit backing.
    function _amountInForZapMint(address tokenIn, uint256 sharesOut, uint256 prepaidCredit)
        internal view returns (uint256)
    {
        if (sharesOut == 0) return 0;
        if (canOpenPoolManagerUnlock()) revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
        uint256 supply = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        if (supply == 0 || (tokenIn == _token0() ? reserve0 : reserve1) <= prepaidCredit)
            revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
        return tokenIn == _token0()
            ? Inventory._blockedInputForShares(reserve0 - prepaidCredit, reserve1, sharesOut, supply)
            : Inventory._blockedInputForShares(reserve1 - prepaidCredit, reserve0, sharesOut, supply);
    }

    function _previewZapOutWithdrawal(address tokenOut, uint256 desiredAmountOut)
        internal view returns (uint256 sharesRequired)
    {
        (sharesRequired,) = _linearExitPlan(_snapshot(0, 0), tokenOut == _token0(), desiredAmountOut);
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
        amount0 += Math.mulDiv(free0, sharesBurned, totalShares);
        amount1 += Math.mulDiv(free1, sharesBurned, totalShares);
        if (tokenOut == _token0()) {
            return amount0 + (amount1 > 0 ? _quoteSwapAfterWithdrawal(amount1, false, sharesBurned, totalShares) : 0);
        }
        return amount1 + (amount0 > 0 ? _quoteSwapAfterWithdrawal(amount0, true, sharesBurned, totalShares) : 0);
    }
}
