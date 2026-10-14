// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol";
import {UniswapV4FullSpreadPonsFamilyHookInDelegateExecutionBase} from "./UniswapV4FullSpreadPonsFamilyHookInTarget.sol";

abstract contract UniswapV4FullSpreadPonsFamilyStandardYieldExecutionTarget is UniswapV4FullSpreadPonsFamilyHookInDelegateExecutionBase, NativeStandardYieldExecutionTarget {
    function isValidTokenIn(address token_) public view override returns (bool) { return token_ == _token0() || token_ == _token1(); }
    function isValidTokenOut(address token_) public view override returns (bool) { return isValidTokenIn(token_); }

    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant operationScope returns (uint256 amount_)
    {
        amount_ = _executeInputRedeem(tokenOut_, shares_, minimum_, receiver_);
        _pokeBoundPoolTwap();
    }
}
