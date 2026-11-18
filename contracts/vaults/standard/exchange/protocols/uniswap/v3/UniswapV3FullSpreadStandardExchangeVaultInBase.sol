// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "./UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice Single-token execution uses the same plan that serves its public preview.
abstract contract UniswapV3FullSpreadStandardExchangeVaultInBase is UniswapV3FullSpreadStandardExchangeVaultCommon {
    using SafeERC20 for IERC20;

    function _executeExchangeIn(
        address tokenIn_, uint256 amountIn_, address tokenOut_, uint256 minimum_, address recipient_, bool pretransferred_
    ) internal returns (uint256 amountOut_, uint256 refund_) {
        address token0_ = _token0();
        address token1_ = _token1();
        bool withdrawal_ = tokenIn_ == address(this);
        uint256 inputIndex_ = tokenIn_ == token0_ ? 0 : 1;
        if (withdrawal_) {
            _requireShares(amountIn_);
        } else if (pretransferred_ && amountIn_ > _unbooked(tokenIn_, inputIndex_)) {
            if (tokenOut_ == address(this) && ERC20Repo._totalSupply() == 0) revert IVault.MinLiquidityNotMet();
            if (minimum_ != 0) revert IStandardExchangeErrors.AmountOutNotMet(minimum_, 0);
            refund_ = _unbooked(tokenIn_, inputIndex_);
            if (refund_ != 0) IERC20(tokenIn_).safeTransfer(msg.sender, refund_);
            return (0, refund_);
        } else {
            _fund(tokenIn_, amountIn_, inputIndex_, pretransferred_);
        }
        Planner.Plan memory plan_ = Planner.planIn(tokenIn_, amountIn_, tokenOut_);
        if (plan_.kind == Planner.Kind.Unsupported) revert IStandardExchangeIn.ExchangeInNotAvailable();
        if (plan_.failed) {
            if (withdrawal_) revert IStandardExchangeErrors.AmountOutNotMet(minimum_, 0);
            if (plan_.kind == Planner.Kind.PassThrough) revert IStandardExchangeIn.ExchangeInNotAvailable();
            revert IVault.MinLiquidityNotMet();
        }
        if (plan_.amountOut < minimum_) {
            revert IStandardExchangeErrors.AmountOutNotMet(minimum_, plan_.amountOut);
        }
        if (plan_.kind == Planner.Kind.OneSidedMint) {
            _add(plan_);
            _mintShares(plan_, recipient_);
            _pay(tokenIn_, inputIndex_, msg.sender, plan_.amountRefunded);
        } else if (plan_.kind == Planner.Kind.PassThrough) {
            if (plan_.amountOut == 0) revert IStandardExchangeIn.ExchangeInNotAvailable();
            (uint256 spent_, uint256 received_) = _swap(plan_.zeroForOne, plan_.swapIn);
            if (spent_ != plan_.swapSpent || received_ != plan_.amountOut) revert IVault.SettlementMismatch();
            _pay(tokenOut_, 1 - inputIndex_, recipient_, received_);
            _pay(tokenIn_, inputIndex_, msg.sender, plan_.amountRefunded);
        } else {
            _remove(plan_);
            _pay(token0_, 0, recipient_, plan_.out0);
            _pay(token1_, 1, recipient_, plan_.out1);
        }
        _close();
        return (plan_.amountOut, plan_.amountRefunded);
    }
}
