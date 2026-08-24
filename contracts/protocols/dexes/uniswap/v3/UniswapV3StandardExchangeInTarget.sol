// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV3StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInBase.sol";

/// @dev Mutate-only exchange-in (preview lives on InQueryFacet). Heavy zap via CREATE3 delegate.
contract UniswapV3StandardExchangeInTarget is UniswapV3StandardExchangeInBase {
    using Address for address;

    address immutable UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE = executionDelegate;
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV3ExchangeIn_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut = _executeDirectSwapIn(address(tokenIn), actualIn, recipient);
            if (amountOut < minAmountOut) revert UniswapV3ExchangeIn_SlippageExceeded();
            return amountOut;
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut = _delegateExecuteZapInDeposit(address(tokenIn), actualIn, minAmountOut, recipient);
            return amountOut;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            uint256 actualIn = _secureShareDelivery(amountIn, pretransferred);
            amountOut = _delegateExecuteZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient);
            return amountOut;
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function _delegateExecuteZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        bytes memory result = UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeZapInDeposit(address,uint256,uint256,address)", tokenIn, amountIn, minSharesOut, recipient
            )
        );
        return abi.decode(result, (uint256));
    }

    function _delegateExecuteZapOutExactIn(
        address tokenOut,
        uint256 sharesBurned,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        bytes memory result = UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeZapOutExactIn(address,uint256,uint256,address)",
                tokenOut,
                sharesBurned,
                minAmountOut,
                recipient
            )
        );
        return abi.decode(result, (uint256));
    }
}
