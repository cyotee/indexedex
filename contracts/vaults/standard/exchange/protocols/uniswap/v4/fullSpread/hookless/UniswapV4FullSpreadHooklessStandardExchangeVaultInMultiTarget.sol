// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiTarget is UniswapV4FullSpreadHooklessStandardExchangeVaultInBase {
    function exchangeInManyToOne(
        address[] calldata tokenIn,
        uint256[] calldata amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant operationScope returns (uint256 amountOut) {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();
        if (address(tokenOut) != address(this) || !_isDualPoolCurrencies(tokenIn) || !_dualAmountsPositive(amountsIn)) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }

        uint256 actual0 = _secureTokenTransfer(IERC20(tokenIn[0]), amountsIn[0], pretransferred);
        _requireExactDelivery(amountsIn[0], actual0);
        uint256 actual1 = _secureTokenTransfer(IERC20(tokenIn[1]), amountsIn[1], pretransferred);
        _requireExactDelivery(amountsIn[1], actual1);
        amountOut = _executeZapInDualDeposit(actual0, actual1, minAmountOut, recipient);
        _pokeBoundPoolTwap();
    }
}
