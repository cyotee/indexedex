// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Permit2                                   */
/* -------------------------------------------------------------------------- */

import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";

/**
 * @title IBalancerV3StandardExchangeRouterExactOutSwap - Interface for Standard Exchange Router exact out swaps.
 * @author cyotee doge <not_cyotee@proton.me>
 */
interface IBalancerV3StandardExchangeRouterExactOutSwap is BalancerV3StandardExchangeRouterTypes {

    /**
     * @notice Processes a 
     */
    function swapSingleTokenExactOut(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut,
        uint256 maxAmountIn,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256 );

    /**
     *
     */
    function swapSingleTokenExactOutWithPermit(
        StandardExchangeSwapSingleTokenHookParams calldata swapParams,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external payable returns (uint256);

    function swapSingleTokenExactOutHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        external
        returns (uint256);
}
