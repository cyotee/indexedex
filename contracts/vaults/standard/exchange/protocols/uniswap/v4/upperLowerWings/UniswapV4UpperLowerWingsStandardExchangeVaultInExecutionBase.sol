// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase} from "./UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

abstract contract UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase is UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase, StandardExchangeInExecutionBase {
    function _exchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, uint256 minimum_, address recipient_, bool pushed_, uint256 deadline_)
        internal override returns (uint256 amountOut_)
    {
        Money.begin(deadline_);
        bool deposit = _route(tokenIn_, tokenOut_);
        amountOut_ = deposit ? Money.deposit(amountIn_, minimum_, recipient_, pushed_)
            : Money.redeem(amountIn_, minimum_, recipient_, pushed_);
        Money.end();
    }
}
