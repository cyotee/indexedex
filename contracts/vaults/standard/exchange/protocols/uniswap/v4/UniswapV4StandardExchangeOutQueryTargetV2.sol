// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    UniswapV4StandardExchangeOutBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutBaseV2.sol";

/// @notice Preview-only exchangeOut surface (Option 1b).
abstract contract UniswapV4StandardExchangeOutQueryTargetV2 is UniswapV4StandardExchangeOutBaseV2 {
    function quoteState(address asset, address holder) external view returns (bytes memory state, uint256 holderAssets) {
        InventoryQuote memory q = _inventorySnapshot(asset, holder);
        state = abi.encode(q);
        holderAssets = _inventoryAssets(q, q.shares);
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            if (!canOpenPoolManagerUnlock()) {
                revert UniswapV4Exchange_PoolManagerInteractionBlocked();
            }
            return _quoteSwapOut(amountOut, address(tokenIn) == token0);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutWithdrawal(address(tokenOut), amountOut);
        }

        revert ExchangeOutNotAvailable();
    }
}
