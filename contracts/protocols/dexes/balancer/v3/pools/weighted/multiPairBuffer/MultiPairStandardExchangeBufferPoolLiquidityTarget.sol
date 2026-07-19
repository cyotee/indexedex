// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";

/**
 * @title MultiPairStandardExchangeBufferPoolLiquidityTarget
 * @notice CUSTOM add/remove passthrough for hook-only balance reshuffling. Hook-only gate.
 */
contract MultiPairStandardExchangeBufferPoolLiquidityTarget is IPoolLiquidity {
    function onAddLiquidityCustom(
        address router,
        uint256[] memory maxAmountsInScaled18,
        uint256, /*minBptAmountOut*/
        uint256[] memory, /*balancesScaled18*/
        bytes memory /*userData*/
    )
        external
        override
        returns (
            uint256[] memory amountsInScaled18,
            uint256 bptAmountOut,
            uint256[] memory swapFeeAmountsScaled18,
            bytes memory returnData
        )
    {
        if (router != address(this)) {
            revert IMultiPairStandardExchangeBufferPool.NotHookCaller(router);
        }
        amountsInScaled18 = maxAmountsInScaled18;
        bptAmountOut = 0;
        swapFeeAmountsScaled18 = new uint256[](maxAmountsInScaled18.length);
        returnData = "";
    }

    function onRemoveLiquidityCustom(
        address router,
        uint256, /*maxBptAmountIn*/
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory, /*balancesScaled18*/
        bytes memory /*userData*/
    )
        external
        override
        returns (
            uint256 bptAmountIn,
            uint256[] memory amountsOutScaled18,
            uint256[] memory swapFeeAmountsScaled18,
            bytes memory returnData
        )
    {
        if (router != address(this)) {
            revert IMultiPairStandardExchangeBufferPool.NotHookCaller(router);
        }
        bptAmountIn = 0;
        amountsOutScaled18 = minAmountsOutScaled18;
        swapFeeAmountsScaled18 = new uint256[](minAmountsOutScaled18.length);
        returnData = "";
    }
}
