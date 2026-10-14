// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInBase.sol";

contract UniswapV4FullSpreadPonsFamilyHookInMultiQueryTarget is UniswapV4FullSpreadPonsFamilyHookInBase {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewExchangeIn(tokenIn, amountIn, tokenOut);
    }

    function previewExchangeInManyToOne(address[] calldata tokenIn, uint256[] calldata amountsIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (address(tokenOut) != address(this) || !_isDualPoolCurrencies(tokenIn) || !_dualAmountsPositive(amountsIn)) {
            return 0;
        }
        return _previewZapInDualDeposit(amountsIn[0], amountsIn[1]);
    }
}
