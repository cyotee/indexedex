// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4DetfTarget} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";

/// @notice Exchange entrypoints for the universal DETF diamond.
abstract contract UniswapV4DetfExchangeTarget is UniswapV4DetfTarget {
    /// @notice Executes an exact-input mint, burn, or DETF-to-claim route on the diamond.
    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) external returns (uint256 amountOut_) {
        return _entryExchangeIn(tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
    }

}
