// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    MorphoBlueStandardExchangeCommon
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol";

/**
 * @title MorphoBlueStandardExchangeOutTarget
 * @notice Exact-out routes: loanToken → SE and SE → loanToken only.
 */
contract MorphoBlueStandardExchangeOutTarget is
    MorphoBlueStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut
{
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        address se_ = address(this);
        address loan_ = address(_loan());

        if (address(tokenIn) == loan_ && address(tokenOut) == se_) {
            return _previewWrapExactOut(amountOut);
        }
        if (address(tokenIn) == se_ && address(tokenOut) == loan_) {
            return _previewUnwrapExactOut(amountOut);
        }
        _revertInvalidRoute(tokenIn, tokenOut);
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
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        _requireNonZero(maxAmountIn);
        _requireRecipient(recipient);

        address se_ = address(this);
        address loan_ = address(_loan());

        if (address(tokenIn) == loan_ && address(tokenOut) == se_) {
            return _execWrapExactOut(amountOut, maxAmountIn, recipient, pretransferred);
        }
        if (address(tokenIn) == se_ && address(tokenOut) == loan_) {
            return _execUnwrapExactOut(msg.sender, amountOut, maxAmountIn, recipient, pretransferred);
        }
        _revertInvalidRoute(tokenIn, tokenOut);
    }
}
