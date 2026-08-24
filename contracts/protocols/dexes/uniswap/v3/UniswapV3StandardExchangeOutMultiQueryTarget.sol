// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutBase.sol";

contract UniswapV3StandardExchangeOutMultiQueryTarget is UniswapV3StandardExchangeOutBase {
    function previewExchangeOutOneToMany(
        IERC20 tokenIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) external view returns (uint256 amountIn) {
        if (address(tokenIn) != address(this) || !_isDualPoolCurrencies(tokensOut) || !_dualAmountsPositive(amountsOut))
        {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }

        uint256 amount0 = amountsOut[0];
        uint256 amount1 = amountsOut[1];
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 total0, uint256 total1) = _totalVaultReservesForShareMath();
        (uint256 s0, uint256 s1) = _dualExitShareBurns(amount0, amount1, total0, total1, totalShares);
        if (s0 != s1) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        if (!canOpenBoundPoolOps()) {
            uint256 free0 = IERC20(_token0()).balanceOf(address(this));
            uint256 free1 = IERC20(_token1()).balanceOf(address(this));
            if (free0 < amount0) {
                revert UniswapV3Exchange_InsufficientLocalReserve(_token0(), amount0, free0);
            }
            if (free1 < amount1) {
                revert UniswapV3Exchange_InsufficientLocalReserve(_token1(), amount1, free1);
            }
        }
        return s0;
    }
}
