// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase} from "./UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultInTarget is UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase, IStandardExchangeIn {
    function exchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, uint256 minimum_, address recipient_, bool pushed_, uint256 deadline_)
        external returns (uint256 amountOut_)
    {
        return _exchangeIn(tokenIn_, amountIn_, tokenOut_, minimum_, recipient_, pushed_, deadline_);
    }
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_) external view returns (uint256) {
        return _previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }
}
