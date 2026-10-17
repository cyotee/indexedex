// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {NativeStandardYieldErrors as Errors} from "contracts/vaults/standard/sy/NativeStandardYieldErrors.sol";
import {NativeStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {UniswapV3FullSpreadStandardExchangeVaultInTarget} from "./UniswapV3FullSpreadStandardExchangeVaultInTarget.sol";

abstract contract UniswapV3FullSpreadStandardYieldExecutionTarget is UniswapV3FullSpreadStandardExchangeVaultInTarget, NativeStandardYieldExecutionTarget {
    function isValidTokenIn(address token_) public view override returns (bool) { return token_ == _token0() || token_ == _token1(); }
    function isValidTokenOut(address token_) public view override returns (bool) { return isValidTokenIn(token_); }

    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override returns (uint256)
    {
        return _settleNamedHolder(tokenOut_, shares_, minimum_, receiver_, address(this));
    }

    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal override returns (uint256 received_)
    {
        if (address(in_) != address(this) || internal_) return super._standardRoute(in_, amount_, out_, minimum_, receiver_, internal_);
        received_ = _settleNamedHolder(address(out_), amount_, minimum_, receiver_, msg.sender);
        if (received_ < minimum_) revert Errors.SYMinimumNotMet(minimum_, received_);
    }

    function _settleNamedHolder(address tokenOut_, uint256 shares_, uint256 minimum_, address receiver_, address holder_)
        private nonReentrant returns (uint256)
    {
        return _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
    }
}
