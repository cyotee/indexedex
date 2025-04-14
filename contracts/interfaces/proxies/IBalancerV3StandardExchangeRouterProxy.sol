// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";

interface IBalancerV3StandardExchangeRouterProxy is

    // StandardExchangeRouterTypes,
    IBalancerV3StandardExchangeRouterExactInSwap,
    IBalancerV3StandardExchangeRouterExactInSwapQuery,
    IBalancerV3StandardExchangeRouterExactOutSwap,
    IBalancerV3StandardExchangeRouterExactOutSwapQuery,
    IBalancerV3StandardExchangeBatchRouterExactIn,
    IBalancerV3StandardExchangeBatchRouterExactOut,
    IBalancerV3StandardExchangeRouterPrepay,
    IBalancerV3StandardExchangeRouterPrepayHooks
{}
