// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";

/**
 * @title MixedLegWeightedBufferPoolLiquidityTarget
 * @notice Same CUSTOM passthrough + NotHookCaller gate as multi-pair buffer (compatible pattern).
 * @dev Multi-pair LiquidityTarget cannot be shared because it reverts MultiPair-specific error type;
 *      body is intentionally identical.
 */
contract MixedLegWeightedBufferPoolLiquidityTarget is IPoolLiquidity {
    function onAddLiquidityCustom(
        address router,
        uint256[] memory maxAmountsInScaled18,
        uint256,
        uint256[] memory,
        bytes memory
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
            revert IMixedLegWeightedBufferPool.NotHookCaller(router);
        }
        amountsInScaled18 = maxAmountsInScaled18;
        bptAmountOut = 0;
        swapFeeAmountsScaled18 = new uint256[](maxAmountsInScaled18.length);
        returnData = "";
    }

    function onRemoveLiquidityCustom(
        address router,
        uint256,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory,
        bytes memory
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
            revert IMixedLegWeightedBufferPool.NotHookCaller(router);
        }
        bptAmountIn = 0;
        amountsOutScaled18 = minAmountsOutScaled18;
        swapFeeAmountsScaled18 = new uint256[](minAmountsOutScaled18.length);
        returnData = "";
    }
}
