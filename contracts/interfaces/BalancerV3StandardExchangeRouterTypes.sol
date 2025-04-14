// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {SwapKind} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

interface BalancerV3StandardExchangeRouterTypes {
    error InsufficientEth();
    error InvalidRoute(address tokenIn, address tokenVault, address tokenOut, address tokenOutVault);
    error LimitExceeded(uint256 limit, uint256 actual);
    error MinAmountOutNotMet(uint256 minAmountOut, uint256 actualAmountOut);

    /**
     * @notice The sender has not transferred the correct amount of tokens to the Vault.
     * @param token The address of the token that should have been transferred
     */
    error InsufficientPayment(IERC20 token);

    /**
     * @notice Data for the swap hook.
     * @param sender Account initiating the swap operation
     * @param kind Type of swap (exact in or exact out)
     * @param pool Address of the liquidity pool
     * @param tokenIn Token to be swapped from
     * @param tokenOut Token to be swapped to
     * @param amountGiven Amount given based on kind of the swap (e.g., tokenIn for exact in)
     * @param limit Maximum or minimum amount based on the kind of swap (e.g., maxAmountIn for exact out)
     * @param deadline Deadline for the swap, after which it will revert
     * @param wethIsEth If true, incoming ETH will be wrapped to WETH and outgoing WETH will be unwrapped to ETH
     * @param userData Additional (optional) data sent with the swap request
     */
    struct StandardExchangeSwapSingleTokenHookParams {
        address sender;
        SwapKind kind;
        address pool;
        IERC20 tokenIn;
        IStandardExchangeProxy tokenInVault;
        IERC20 tokenOut;
        IStandardExchangeProxy tokenOutVault;
        uint256 amountGiven;
        uint256 limit;
        uint256 deadline;
        bool wethIsEth;
        bytes userData;
    }
}
