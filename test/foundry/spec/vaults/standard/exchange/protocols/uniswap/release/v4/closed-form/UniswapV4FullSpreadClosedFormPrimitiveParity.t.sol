// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {StandardExchangeConstantProduct} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {UniswapV4FullSpreadClosedFormCandidate} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadClosedFormCandidate.sol";

contract UniswapV4FullSpreadClosedFormPrimitiveParityTest is Test {
    uint160 internal constant Q96 = uint160(1 << 96);
    uint128 internal constant ACTIVE = 1_000_000;
    uint256 internal constant FREE0 = 50_000;
    uint256 internal constant FREE1 = 5_000;

    function test_PrimitiveParity_productionSwapStepMatchesPythonVector() public pure {
        uint160 target = 77444695801180412768602321494;
        (uint160 next, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(Q96, target, ACTIVE, -int256(10 ** 30), 3000);
        assertEq(next, target, "candidate root was not reached");
        assertEq(amountIn, 23029, "input");
        assertEq(amountOut, 22510, "output");
        assertEq(feeAmount, 70, "fee");
    }

    function test_PrimitiveParity_feeBearingRepairMissesOneBasisPoint() public pure {
        uint160 target = 77444695801180412768602321494;
        (, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(Q96, target, ACTIVE, -int256(10 ** 30), 3000);
        assertEq(_inventoryError(target, amountIn, amountOut, feeAmount), 2, "0.30% fee repair misses 1 bp");
    }

    function test_PrimitiveParity_twentyFiveBpClampDoesNotFinishRepair() public pure {
        uint160 cap = 79129312616115486070837105845;
        assertEq(_priceImpactWad(Q96, cap), 0.0025e18, "cap is the 25 bp price bound");
        uint256 beforeError = _inventoryError(Q96, 0, 0, 0);
        (, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(Q96, cap, ACTIVE, -int256(10 ** 30), 3000);
        uint256 afterError = _inventoryError(cap, amountIn, amountOut, feeAmount);
        assertEq(beforeError, 1840, "starting mismatch");
        assertEq(afterError, 1747, "clamped repair still far from 1 bp");
        assertLt(afterError, beforeError, "clamp is progress, not completion");
    }

    function test_RoundingCounterexample_cfBUndershootsProductionSingleExit() public pure {
        uint256 candidate = UniswapV4FullSpreadClosedFormCandidate.cfBShares(50, 12, 100);
        assertEq(candidate, 13, "radical candidate");
        assertEq(StandardExchangeConstantProduct._singleExit(50, 50, candidate, 100), 11, "production forward");
        assertEq(StandardExchangeConstantProduct._singleExit(50, 50, candidate - 1, 100), 11, "predecessor");
    }

    function test_PrimitiveParity_sleeveTargetIsNotPercentOfTotal() public pure {
        uint256 p = 0.2e18;
        assertEq(UniswapV4FullSpreadClosedFormCandidate.targetFree(120, p), 20, "approved sleeve");
        assertEq(UniswapV4FullSpreadClosedFormCandidate.oldPercentOfTotal(120, p), 24, "current formula");
    }

    function _inventoryError(uint160 price, uint256 amountIn, uint256 amountOut, uint256 feeAmount)
        internal
        pure
        returns (uint256)
    {
        uint160 lower = uint160((uint256(Q96) * 3) / 4);
        uint160 upper = uint160((uint256(Q96) * 5) / 4);
        uint256 deployed0 = SqrtPriceMath.getAmount0Delta(price, upper, ACTIVE, false);
        uint256 deployed1 = SqrtPriceMath.getAmount1Delta(lower, price, ACTIVE, false);
        uint256 total0 = deployed0 + FREE0 - amountIn - feeAmount;
        uint256 total1 = deployed1 + FREE1 + amountOut;
        return _ratioErrorBps(total0, total1, deployed0, deployed1);
    }

    function _ratioErrorBps(uint256 total0, uint256 total1, uint256 position0, uint256 position1)
        internal
        pure
        returns (uint256)
    {
        uint256 left = total0 * position1;
        uint256 right = total1 * position0;
        uint256 diff = left > right ? left - right : right - left;
        return (diff * 10_000) / left;
    }

    function _priceImpactWad(uint160 beforePrice, uint160 afterPrice) internal pure returns (uint256) {
        uint256 left = uint256(beforePrice) * beforePrice;
        uint256 right = uint256(afterPrice) * afterPrice;
        uint256 high = left > right ? left : right;
        uint256 low = left > right ? right : left;
        return ((high - low) * 1e18) / low;
    }
}
