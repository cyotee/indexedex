// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {NativeStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol";
import {UniswapV4StandardExchangeInTarget} from "./UniswapV4StandardExchangeInTarget.sol";

abstract contract UniswapV4StandardYieldExecutionTarget is UniswapV4StandardExchangeInTarget, NativeStandardYieldExecutionTarget {
    function isValidTokenIn(address token_) public view override returns (bool) { return token_ == _token0() || token_ == _token1(); }
    function isValidTokenOut(address token_) public view override returns (bool) { return isValidTokenIn(token_); }

    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override returns (uint256)
    {
        return _settleNamedHolder(tokenOut_, shares_, minimum_, receiver_, address(this));
    }

    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal override returns (uint256)
    {
        if (address(in_) == address(this) && !internal_) {
            return _settleNamedHolder(address(out_), amount_, minimum_, receiver_, msg.sender);
        }
        return super._standardRoute(in_, amount_, out_, minimum_, receiver_, internal_);
    }

    function _settleNamedHolder(address tokenOut_, uint256 shares_, uint256 minimum_, address receiver_, address holder_)
        private nonReentrant returns (uint256 amount_)
    {
        (bool ok_, bytes memory result_) = UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.delegatecall(
            abi.encodeWithSignature("executeNamedHolderRedemption(address,uint256,uint256,address,address)",
                tokenOut_, shares_, minimum_, receiver_, holder_)
        );
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        amount_ = abi.decode(result_, (uint256));
        _pokeBoundPoolTwap();
    }
}
