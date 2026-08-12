// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";

/// @dev Direct swap + rebalance on Facet; heavy zap-out via CREATE3 OutExecutionDelegate (Option 2b).
abstract contract UniswapV4StandardExchangeOutExecuteTarget is UniswapV4StandardExchangeOutBase {
    using Address for address;

    address immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE = executionDelegate;
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeOut_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            _requireCanOpenPoolManagerUnlock();
            uint256 estimatedAmountIn = _quoteSwapOut(amountOut, address(tokenIn) == token0);
            if (estimatedAmountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();

            uint256 providedAmountIn = _secureTokenTransfer(tokenIn, maxAmountIn, pretransferred);
            uint256 actualOut;
            (amountIn, actualOut) = _executeDirectSwapOut(address(tokenIn), amountOut, recipient);
            if (amountIn > providedAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();
            if (actualOut < amountOut) revert UniswapV4ExchangeOut_SlippageExceeded();

            _refundExcess(tokenIn, providedAmountIn, amountIn, msg.sender);
            _rebalanceLiquidReserveBestEffort();
            return amountIn;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            amountIn = _delegateExecuteZapOutWithdrawal(
                address(tokenOut), maxAmountIn, amountOut, recipient, pretransferred
            );
            _rebalanceLiquidReserveBestEffort();
            return amountIn;
        }

        revert ExchangeOutNotAvailable();
    }

    function _executeDirectSwapOut(address tokenIn, uint256 amountOut, address recipient)
        internal
        returns (uint256 actualIn, uint256 actualOut)
    {
        bool zeroForOne = tokenIn == _token0();
        address outputToken = zeroForOne ? _token1() : _token0();
        uint256 inputBalanceBefore = IERC20(tokenIn).balanceOf(address(this));
        uint256 balanceBefore = IERC20(outputToken).balanceOf(address(this));

        _executeUnlock(
            OperationParams({
                op: Operation.SwapExactOut,
                zeroForOne: zeroForOne,
                amountSpecified: amountOut,
                tickLower: 0,
                tickUpper: 0,
                liquidity: 0,
                salt: bytes32(0)
            })
        );

        actualIn = inputBalanceBefore - IERC20(tokenIn).balanceOf(address(this));
        actualOut = IERC20(outputToken).balanceOf(address(this)) - balanceBefore;
        _transferCurrency(outputToken, recipient, actualOut);
    }

    function _delegateExecuteZapOutWithdrawal(
        address tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 sharesBurned) {
        bytes memory result = UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeZapOutWithdrawal(address,uint256,uint256,address,bool)",
                tokenOut,
                maxSharesToBurn,
                minAmountOut,
                recipient,
                pretransferred
            )
        );
        return abi.decode(result, (uint256));
    }

    function _refundExcess(IERC20 token, uint256 providedAmount, uint256 usedAmount, address recipient) internal {
        if (providedAmount > usedAmount) {
            _transferCurrency(address(token), recipient, providedAmount - usedAmount);
        }
    }
}
