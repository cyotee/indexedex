// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultInTarget is IStandardExchangeIn {
    function exchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, uint256 minimum_, address recipient_, bool pushed_, uint256 deadline_)
        external returns (uint256 amountOut_)
    {
        Money.begin(deadline_);
        bool deposit = _route(tokenIn_, tokenOut_);
        amountOut_ = deposit ? Money.deposit(amountIn_, minimum_, recipient_, pushed_)
            : Money.redeem(amountIn_, minimum_, recipient_, pushed_);
        Money.end();
    }
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_) external view returns (uint256) {
        return Money.preview(_route(tokenIn_, tokenOut_), amountIn_);
    }
    function _route(IERC20 tokenIn_, IERC20 tokenOut_) private view returns (bool deposit_) {
        address target = address(Money.target());
        if (address(tokenIn_) == target && address(tokenOut_) == address(this)) return true;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == target) return false;
        revert InvalidRoute(address(tokenIn_), address(tokenOut_));
    }
}
