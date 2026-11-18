// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV3FullSpreadStandardExchangeVaultInBase} from "./UniswapV3FullSpreadStandardExchangeVaultInBase.sol";

/// @notice CREATE3 code-size split; all economics remain in the shared planner.
contract UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate is UniswapV3FullSpreadStandardExchangeVaultInBase {
    address private immutable SELF = address(this);
    error DelegateCallRequired();

    function executeExchangeIn(
        address tokenIn_, uint256 amountIn_, address tokenOut_, uint256 minimum_, address recipient_, bool pretransferred_
    ) external returns (uint256 amountOut_, uint256 refunded_) {
        if (address(this) == SELF) revert DelegateCallRequired();
        return _executeExchangeIn(tokenIn_, amountIn_, tokenOut_, minimum_, recipient_, pretransferred_);
    }
}
