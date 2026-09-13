// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4BufferHookFlexibleLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4BufferHookFlexibleLiquidity.sol";

/// @notice Standard Exchange liquidity routes reuse a buffer hook's installed join/exit selectors.
/// @dev Delegate execution preserves the payer, liquidity-owner restriction and host reentrancy lock.
///      Invoke before entering the swap lock; joins and exits acquire that same host lock themselves.
library UniswapV4BufferHookLiquidityRouteLib {
    error InvalidLiquidityRoute();
    error ZeroLiquidityAmount();
    error LiquidityMinimumNotMet(uint256 minimum, uint256 received);
    error LiquidityMaximumExceeded(uint256 maximum, uint256 required);

    function isLiquidityRoute(IERC20 in_, IERC20 out_) internal view returns (bool) {
        return address(in_) == address(this) || address(out_) == address(this);
    }

    function _isJoin(IERC20 in_, IERC20 out_) private view returns (bool) {
        if (address(in_) == address(out_)) revert InvalidLiquidityRoute();
        if (address(out_) == address(this)) return true;
        if (address(in_) == address(this)) return false;
        revert InvalidLiquidityRoute();
    }

    function previewIn(IERC20 in_, uint256 amount_, IERC20 out_) internal view returns (uint256) {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(address(this));
        return _isJoin(in_, out_)
            ? host_.previewJoinSingleAssetExactIn(address(in_), amount_)
            : host_.previewExitSingleAssetExactBptIn(address(out_), amount_);
    }

    function previewOut(IERC20 in_, IERC20 out_, uint256 amount_) internal view returns (uint256 required_) {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(address(this));
        required_ = _isJoin(in_, out_)
            ? host_.previewJoinSingleAssetExactOut(address(in_), amount_)
            : host_.previewExitSingleAssetExactTokenOut(address(out_), amount_);
        // Some hosts deliberately expose unsupported exact-output quote stubs returning zero.
        if (amount_ != 0 && required_ == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    /// @dev A nonzero pair selects an already installed flexible SE-share route.
    function previewInWithSe(IERC20 in_, uint256 amount_, IERC20 out_, address pair_) internal view returns (uint256) {
        if (pair_ == address(0)) return previewIn(in_, amount_, out_);
        IUniswapV4BufferHookFlexibleLiquidity host_ = IUniswapV4BufferHookFlexibleLiquidity(address(this));
        return _isJoin(in_, out_)
            ? host_.previewJoinSingleAssetExactInFlexible(pair_, amount_, true)
            : host_.previewExitSingleAssetExactBptInFlexible(pair_, amount_, true);
    }

    function exchangeInWithSe(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool prepaid_, uint256 deadline_, address pair_
    ) internal returns (uint256 received_) {
        if (pair_ == address(0)) return exchangeIn(in_, amount_, out_, minimum_, receiver_, prepaid_, deadline_);
        if (amount_ == 0) revert ZeroLiquidityAmount();
        if (prepaid_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        bytes memory call_ = _isJoin(in_, out_)
            ? abi.encodeCall(IUniswapV4BufferHookFlexibleLiquidity.joinSingleAssetExactInFlexible, (pair_, amount_, true, receiver_, minimum_, deadline_))
            : abi.encodeCall(IUniswapV4BufferHookFlexibleLiquidity.exitSingleAssetExactBptInFlexible, (pair_, amount_, true, receiver_, minimum_, deadline_));
        received_ = _delegate(call_);
        if (received_ < minimum_) revert LiquidityMinimumNotMet(minimum_, received_);
    }

    function exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool prepaid_, uint256 deadline_
    ) internal returns (uint256 received_) {
        if (amount_ == 0) revert ZeroLiquidityAmount();
        if (prepaid_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        bytes memory call_ = _isJoin(in_, out_)
            ? abi.encodeCall(IUniswapV4SeBufferHook.joinSingleAssetExactIn, (address(in_), amount_, receiver_, minimum_, deadline_))
            : abi.encodeCall(IUniswapV4SeBufferHook.exitSingleAssetExactBptIn, (address(out_), amount_, receiver_, minimum_, deadline_));
        received_ = _delegate(call_);
        if (received_ < minimum_) revert LiquidityMinimumNotMet(minimum_, received_);
    }

    function exchangeOut(
        IERC20 in_, uint256 maximum_, IERC20 out_, uint256 amount_, address receiver_, bool prepaid_, uint256 deadline_
    ) internal returns (uint256 paid_) {
        if (amount_ == 0) revert ZeroLiquidityAmount();
        uint256 quoted_ = previewOut(in_, out_, amount_);
        if (quoted_ > maximum_) revert LiquidityMaximumExceeded(maximum_, quoted_);
        if (prepaid_) revert ISecurePullErrors.TransferDeltaInsufficient(quoted_, 0);
        bytes memory call_ = _isJoin(in_, out_)
            ? abi.encodeCall(IUniswapV4SeBufferHook.joinSingleAssetExactOut, (address(in_), amount_, receiver_, quoted_, deadline_))
            : abi.encodeCall(IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut, (address(out_), amount_, receiver_, quoted_, deadline_));
        paid_ = _delegate(call_);
        if (paid_ > quoted_) revert LiquidityMaximumExceeded(quoted_, paid_);
    }

    function _delegate(bytes memory call_) private returns (uint256) {
        (bool ok_, bytes memory result_) = address(this).delegatecall(call_);
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        return abi.decode(result_, (uint256));
    }
}
