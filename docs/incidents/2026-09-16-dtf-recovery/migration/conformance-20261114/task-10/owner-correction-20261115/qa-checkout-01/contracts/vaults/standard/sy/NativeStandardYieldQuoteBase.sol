// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Shared internal exact-input quote contract for native SY and Standard Exchange.
abstract contract NativeStandardYieldQuoteBase {
    function _previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal view virtual returns (uint256);
}
