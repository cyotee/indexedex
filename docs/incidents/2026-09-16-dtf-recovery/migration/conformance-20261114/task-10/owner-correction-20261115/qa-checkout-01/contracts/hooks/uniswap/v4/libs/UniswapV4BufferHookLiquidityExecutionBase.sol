// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Route} from "./UniswapV4BufferHookLiquidityRouteLib.sol";

/// @notice Internal LP exact-input routing shared by SE and native SY entrypoints.
abstract contract UniswapV4BufferHookLiquidityExecutionBase is StandardExchangeInExecutionBase {
    function _exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool prepaid_, uint256 deadline_)
        internal override returns (uint256 received_)
    {
        address edge_ = _liquidityExecutionEdge(in_, out_);
        if (amount_ == 0) revert Route.ZeroLiquidityAmount();
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        }
        if (address(in_) == address(out_)) revert Route.InvalidLiquidityRoute();
        if (address(out_) == address(this)) {
            received_ = _joinLiquidityExactIn(address(in_), amount_, receiver_, minimum_, deadline_, edge_);
        } else if (address(in_) == address(this)) {
            received_ = _exitLiquidityExactIn(address(out_), amount_, receiver_, minimum_, deadline_, edge_);
        } else {
            revert Route.InvalidLiquidityRoute();
        }
        if (received_ < minimum_) revert Route.LiquidityMinimumNotMet(minimum_, received_);
    }

    function _liquidityExecutionEdge(IERC20, IERC20) internal view virtual returns (address) { return address(0); }
    function _joinLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address edge_)
        internal virtual returns (uint256);
    function _exitLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address edge_)
        internal virtual returns (uint256);
}
