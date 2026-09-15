// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeInBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInBaseV2.sol";

interface IUniswapV4StandardExchangePositionImportV2 {
    function importPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external returns (uint256 sharesOut);
}

import {IStandardExchangePretransfer} from "../IStandardExchangePretransfer.sol";
import {StandardExchangeDeliveryRepo} from "../StandardExchangeDeliveryRepo.sol";

contract UniswapV4StandardExchangeInTargetV2 is UniswapV4StandardExchangeInBaseV2, IStandardExchangePretransfer {
    using Address for address;

    address immutable UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE = executionDelegate;
    }

    /// @inheritdoc IStandardExchangePretransfer
    function preparePretransfer(address[] calldata tokens, uint256[] calldata amounts, bytes32 callHash)
        external override nonReentrant
    {
        _requireNotDisabled();
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] != _token0() && tokens[i] != _token1() && tokens[i] != address(this)) {
                revert IStandardExchangePretransfer.InvalidPretransfer();
            }
        }
        StandardExchangeDeliveryRepo._prepare(tokens, amounts, callHash);
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant inputOperation returns (uint256 amountOut) {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut = _executeDirectSwapIn(address(tokenIn), actualIn, recipient);
            if (amountOut < minAmountOut) revert UniswapV4ExchangeIn_SlippageExceeded();
            _pokeBoundPoolTwap();
            return amountOut;
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut = _delegateExecuteZapInDeposit(address(tokenIn), actualIn, minAmountOut, recipient);
            _pokeBoundPoolTwap();
            return amountOut;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            uint256 actualIn = _secureShareDelivery(amountIn, pretransferred);
            amountOut = _delegateExecuteZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient);
            _pokeBoundPoolTwap();
            return amountOut;
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function _delegateExecuteZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        bytes memory result = UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
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
        bytes memory result =
            UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
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
