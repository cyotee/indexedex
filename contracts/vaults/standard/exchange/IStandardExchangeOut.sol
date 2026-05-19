// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

// import {BetterIERC20 as IERC20} from "contracts/crane/interfaces/BetterIERC20.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
// import {IERC2612} from "contracts/crane/access/erc2612/interfaces/IERC2612.sol";
// import {IERC5267} from "contracts/crane/access/erc5267/interfaces/IERC5267.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
/**
 * @custom:interfaceid 0xba39dfe2
 */

interface IStandardExchangeOut is IStandardExchangeErrors {
    struct OutArgs {
        IERC20 tokenIn;
        uint256 maxAmountIn;
        IERC20 tokenOut;
        uint256 amountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    error ExchangeOutNotAvailable();

    /* ---------------------------------------------------------------------- */
    /*                                Functions                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @param tokenIn The token provided to the vault for an exchange.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @param amountOut The amount of `tokenOut` the caller wishes to receive in exchange for `tokenIn`.
     * @return amountIn The amount of `tokenIn` the caller will need to provide in exchange for `amountOut` of `tokenOut`.
     * @custom:selector 0xdb149bc5
     */
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    /**
     * @notice Any pretransferred amount that exceeds `maxAmountIn` will be refunded to the caller.
     * @param tokenIn The token provided to the vault for an exchange.
     * @param maxAmountIn The maximum amount of `tokenIn` the caller is willing to provide.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @param amountOut The amount of `tokenOut` the caller wishes to receive in exchange for `tokenIn`.
     * @param recipient The address to receive the `tokenOut` tokens.
     * @param pretransferred Whether the `tokenIn` tokens have already been transferred to the vault.
     * @return amountIn The amount of `tokenIn` the caller has provided in exchange for `amountOut` of `tokenOut`.
     * @custom:selector 0x612d4427
     */
    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn);
}
