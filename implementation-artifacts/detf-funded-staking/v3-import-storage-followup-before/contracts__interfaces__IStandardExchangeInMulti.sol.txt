// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

interface IStandardExchangeInMulti {
    /**
     * @notice Preview the amount of tokenOut that would be received for exchanging multiple tokenIn amounts.
     * @param tokenIn The array of input token addresses. Sorted in ascending order.
     * @param amountsIn The array of input token amounts corresponding to tokenIn. Must be the same length as tokenIn.
     * @param tokenOut The output token address.
     * @return amountOut The amount of tokenOut that would be received.
     */
    function previewExchangeInManyToOne(
        address[] calldata tokenIn,
        uint256[] calldata amountsIn,
        IERC20 tokenOut
    ) external view returns (uint256 amountOut);

    /**
     * @notice Exchange multiple tokenIn amounts for a single tokenOut amount.
     * @param tokenIn The array of input token addresses. Sorted in ascending order.
     * @param amountsIn The array of input token amounts corresponding to tokenIn. Must be the same length as tokenIn.
     * @param tokenOut The output token address.
     * @param minAmountOut The minimum amount of tokenOut that must be received.
     * @param recipient The address that will receive the output tokens.
     * @param pretransferred Whether the input tokens have already been transferred.
     * @param deadline The timestamp after which the transaction will revert.
     * @return amountOut The amount of tokenOut that was received.
     */
    function exchangeInManyToOne(
        address[] calldata tokenIn,
        uint256[] calldata amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut);
}