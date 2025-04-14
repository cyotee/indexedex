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

import {
    AddLiquidityHookParams,
    RemoveLiquidityHookParams
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/RouterTypes.sol";
// import {AddLiquidityKind, AddLiquidityParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

// import {
//     IBalancerV3StandardExchangeRouterInterrupter
// } from "contracts/indexedex/interfaces/IBalancerV3StandardExchangeRouterInterrupter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

interface IBalancerV3StandardExchangeRouterPrepay {
    error NotCurrentStandardExchangeToken(address provided, address current);

    // /**
    //  * @notice Data for the remove liquidity hook.
    //  * @param sender Account originating the remove liquidity operation
    //  * @param pool Address of the liquidity pool
    //  * @param minAmountsOut Minimum amounts of tokens to be received, sorted in token registration order
    //  * @param maxBptAmountIn Maximum amount of pool tokens provided
    //  * @param kind Type of exit (e.g., single or multi-token)
    //  * @param wethIsEth If true, incoming ETH will be wrapped to WETH and outgoing WETH will be unwrapped to ETH
    //  * @param userData Additional (optional) data sent with the request to remove liquidity
    //  */
    // struct RemoveLiquidityHookParams {
    //     address sender;
    //     address pool;
    //     uint256[] minAmountsOut;
    //     uint256 maxBptAmountIn;
    //     RemoveLiquidityKind kind;
    //     bool wethIsEth;
    //     bytes userData;
    // }

    function isPrepaid() external view returns (bool);

    // function interrupter() external view returns (IBalancerV3StandardExchangeRouterInterrupter);

    function currentStandardExchange() external view returns (IStandardExchangeProxy);

    function prepayInitialize(
        address pool,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 bptAmountOut);

    function prepayAddLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 bptAmountOut);

    function prepayRemoveLiquidityProportional(
        address pool,
        uint256 exactBptAmountIn,
        uint256[] memory minAmountsOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256[] memory amountsOut);

    function prepayRemoveLiquiditySingleTokenExactIn(
        address pool,
        uint256 exactBptAmountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 amountOut);
}
