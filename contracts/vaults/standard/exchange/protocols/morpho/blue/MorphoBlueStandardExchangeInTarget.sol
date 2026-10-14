// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    MorphoBlueStandardExchangeQuoteTarget
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeQuoteTarget.sol";

/**
 * @title MorphoBlueStandardExchangeInTarget
 * @notice Exact-in routes: loanToken → SE and SE → loanToken only.
 */
abstract contract MorphoBlueStandardExchangeInExecutionBase is
    MorphoBlueStandardExchangeQuoteTarget,
    ReentrancyLockModifiers,
    StandardExchangeInExecutionBase
{
    function _exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal override nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        _requireRecipient(recipient);

        address se_ = address(this);
        address loan_ = address(_loan());

        if (address(tokenIn) == loan_ && address(tokenOut) == se_) {
            return _execWrapExactIn(amountIn, recipient, pretransferred, minAmountOut);
        }
        if (address(tokenIn) == se_ && address(tokenOut) == loan_) {
            return _execUnwrapExactIn(msg.sender, amountIn, recipient, pretransferred, minAmountOut);
        }
        _revertInvalidRoute(tokenIn, tokenOut);
    }
}

contract MorphoBlueStandardExchangeInTarget is MorphoBlueStandardExchangeInExecutionBase, IStandardExchangeIn {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256) {
        return _previewExchangeIn(tokenIn, amountIn, tokenOut);
    }
    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minimum, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256)
    {
        return _exchangeIn(tokenIn, amountIn, tokenOut, minimum, recipient, prepaid, deadline);
    }
}
