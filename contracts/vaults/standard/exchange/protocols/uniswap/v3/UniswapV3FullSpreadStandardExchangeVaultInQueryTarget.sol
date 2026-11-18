// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";

abstract contract UniswapV3FullSpreadStandardExchangeVaultInQueryTarget is IStandardExchangeStateQuote {
    function quoteExchangeState() external view returns (bytes memory) {
        return Planner.capture();
    }

    function quoteExchangeIn(bytes calldata state_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        external view returns (bytes memory next_, uint256 amountOut_, uint256 amountRefunded_)
    {
        return Planner.quote(state_, address(tokenIn_), amountIn_, address(tokenOut_));
    }

    function quoteExchangeSupply(bytes calldata state_) external view returns (uint256) {
        return Planner.projectedSupply(state_);
    }

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        external view returns (uint256 amountOut_, uint256 refunded_)
    {
        Planner.Plan memory plan_ = Planner.planIn(address(tokenIn_), amountIn_, address(tokenOut_));
        return (plan_.failed ? 0 : plan_.amountOut, plan_.amountRefunded);
    }
}
