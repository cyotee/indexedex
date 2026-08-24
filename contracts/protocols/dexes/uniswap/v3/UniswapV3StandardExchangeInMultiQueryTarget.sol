// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV3StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInBase.sol";

contract UniswapV3StandardExchangeInMultiQueryTarget is UniswapV3StandardExchangeInBase {
    function previewExchangeInManyToOne(address[] calldata tokenIn, uint256[] calldata amountsIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (address(tokenOut) != address(this) || !_isDualPoolCurrencies(tokenIn) || !_dualAmountsPositive(amountsIn)) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }
        return _previewZapInDualDeposit(amountsIn[0], amountsIn[1]);
    }
}
