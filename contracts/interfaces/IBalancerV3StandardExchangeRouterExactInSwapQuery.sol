// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";

interface IBalancerV3StandardExchangeRouterExactInSwapQuery is BalancerV3StandardExchangeRouterTypes {
    function querySwapSingleTokenExactIn(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        address sender,
        bytes calldata userData
    ) external returns (uint256 amountOut);

    function querySwapSingleTokenExactInHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        external
        returns (uint256);
}
