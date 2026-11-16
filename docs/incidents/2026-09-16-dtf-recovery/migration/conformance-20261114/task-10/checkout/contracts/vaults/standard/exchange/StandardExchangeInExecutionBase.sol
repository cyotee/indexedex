// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Internal exact-input execution shared by SE and native SY entrypoints.
abstract contract StandardExchangeInExecutionBase {
    function _exchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, uint256 minimum_, address recipient_, bool prepaid_, uint256 deadline_)
        internal virtual returns (uint256);
}
