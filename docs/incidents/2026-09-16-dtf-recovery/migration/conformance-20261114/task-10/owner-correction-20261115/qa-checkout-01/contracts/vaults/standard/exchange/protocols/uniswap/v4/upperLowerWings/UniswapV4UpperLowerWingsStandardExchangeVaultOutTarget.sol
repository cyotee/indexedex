// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget is IStandardExchangeOut {
    function exchangeOut(IERC20 tokenIn_, uint256 maximum_, IERC20 tokenOut_, uint256 amountOut_, address recipient_, bool pushed_, uint256 deadline_)
        external returns (uint256 amountIn_)
    {
        bool deposit = _route(tokenIn_, tokenOut_);
        amountIn_ = Money.requiredInput(deposit, amountOut_);
        if (amountIn_ > maximum_) revert MaxAmountExceeded(maximum_, amountIn_);
        Money.begin(deadline_);
        uint256 budget = pushed_ ? Money.pretransferBudget(tokenIn_, maximum_) : amountIn_;
        // Delivery is authenticated by the same money implementation before harvesting.
        if (deposit) Money.depositExactShares(amountIn_, amountOut_, recipient_, pushed_, budget > amountIn_ ? budget - amountIn_ : 0);
        else Money.redeemExactAssets(amountIn_, amountOut_, recipient_, pushed_);
        if (pushed_ && budget > amountIn_) Money.refund(tokenIn_, budget - amountIn_);
        Money.end();
    }
    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_) external view returns (uint256) {
        return Money.requiredInput(_route(tokenIn_, tokenOut_), amountOut_);
    }
    function _route(IERC20 tokenIn_, IERC20 tokenOut_) private view returns (bool deposit_) {
        address target = address(Money.target());
        if (address(tokenIn_) == target && address(tokenOut_) == address(this)) return true;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == target) return false;
        revert InvalidRoute(address(tokenIn_), address(tokenOut_));
    }
}
