// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IStandardExchangeErrors {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    error DeadlineExceeded(uint256 deadline, uint256 currentTimestamp);

    /**
     * @dev Error thrown when the maximum allowed amount is exceeded
     * @param maxAmount The maximum allowed amount
     * @param requiredAmount The required amount that exceeded the maximum
     */
    error MaxAmountExceeded(uint256 maxAmount, uint256 requiredAmount);

    error MinAmountNotMet(uint256 minAmount, uint256 actualAmount);

    /**
     * @dev Error thrown when an invalid token route is attempted
     * @param tokenIn The input token address
     * @param tokenOut The output token address
     */
    error InvalidRoute(address tokenIn, address tokenOut);

    error RouteNotSupported(address tokenIn, address tokenOut, bytes4 functionSelector);

    error AmountOutNotMet(uint256 amountOut, uint256 actualOut);

    error UnknownReserve(address targetReserve);
}
