// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title IStandardExchangeIn - Interface for exchanging tokens in a standard exchange.
 * @author cyotee doge <doge.cyotee>
 * @notice This interface is used to exchange tokens in a standard exchange.
 * @custom:interfaceid 0x8c8035da
 */
interface IStandardExchangeIn is IStandardExchangeErrors {
    struct InArgs {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 minAmountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
    }

    /* ---------------------------------------------------------------------- */
    /*                                 EVENTS                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    error ExchangeInNotAvailable();

    /* ---------------------------------------------------------------------- */
    /*                                FUNCTIONS                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @param tokenIn The token provided to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the users wishes to exchange for `tokenOut`.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @return amountOut The amount of `tokenOut` the caller will receive in exchange for `amountIn` of `tokenIn`.
     * @custom:selector 0x89d61912
     */
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut);

    /**
     * @param tokenIn The token provided to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the users wishes to exchange for `tokenOut`.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @param minAmountOut The minimum amount of `tokenOut` the caller is willing to accept.
     * @param recipient The address to receive the `tokenOut` tokens.
     * @param pretransferred Whether the `tokenIn` tokens have already been transferred to the vault.
     * @return amountOut The amount of `tokenOut` the caller has received in exchange for `amountIn` of `tokenIn`.
     * @custom:selector 0x05562cc8
     */
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut);
}
