// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

interface IStandardExchangeOutMulti {
    /**
     * @notice Preview the exact-out dual exit: shares that would be burned to pay `amountsOut`.
     * @param tokenIn The input token. Must be vault shares (`address(this)`).
     * @param tokensOut The two pool currencies, unique, strictly ascending by address.
     * @param amountsOut Exact amounts of each `tokensOut` the caller wants to receive.
     * @return amountIn Shares that would be burned (exact-out). Does not simulate tail-rebalance.
     */
    function previewExchangeOutOneToMany(
        IERC20 tokenIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) external view returns (uint256 amountIn);

    /**
     * @notice Exact-out dual exit: burn shares to receive exact `amountsOut` of both pool tokens.
     * @param tokenIn The input token. Must be vault shares (`address(this)`).
     * @param maxAmountIn Maximum shares the caller is willing to burn. Unused shares are refunded to `msg.sender`.
     * @param tokensOut The two pool currencies, unique, strictly ascending by address.
     * @param amountsOut Exact amounts of each `tokensOut` that must be received.
     * @param recipient The address that will receive both output tokens.
     * @param pretransferred Whether the shares have already been transferred to the vault.
     * @param deadline The timestamp after which the transaction will revert.
     * @return amountIn Shares burned (not the output token amounts).
     */
    function exchangeOutOneToMany(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn);
}
