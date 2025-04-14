// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

/* ------------------------------- Interfaces ------------------------------- */

import {RemoveLiquidityHookParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/RouterTypes.sol";
import {AddLiquidityHookParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/RouterTypes.sol";
// import {AddLiquidityKind, AddLiquidityParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

// import {
//     IBalancerV3StandardExchangeRouterInterrupter
// } from "contracts/indexedex/interfaces/IBalancerV3StandardExchangeRouterInterrupter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {InitializeHookParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/RouterTypes.sol";

interface IBalancerV3StandardExchangeRouterPrepayHooks {
    function prepayInitializeHook(InitializeHookParams calldata params) external returns (uint256 bptAmountOut);

    function prepayAddLiquidityHook(AddLiquidityHookParams calldata params)
        external
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData);

    function prepayRemoveLiquidityHook(RemoveLiquidityHookParams calldata params)
        external
        returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData);
}
