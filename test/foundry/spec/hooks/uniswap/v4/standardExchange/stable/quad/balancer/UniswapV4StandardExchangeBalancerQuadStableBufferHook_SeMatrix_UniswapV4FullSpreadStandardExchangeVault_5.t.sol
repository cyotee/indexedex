// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixChecks} from "../../../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Five-leg Balancer row: two real FullSpread member faces and three sorted raw records.
/// @dev Inherits the row's runtime-length overrides, never the behavior's fixed-four helpers.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5 is
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault
{
    function setUp() public override {
        TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.setUp();
        _initializeBalancer(5);
    }

    /// @notice Historical failure name, now a positive second FullSpread binding and conversion.
    function test_row_identity_pairToken() public {
        FullSpreadV4MatrixChecks.membership(pairRecord.share(), pairRecord.p0());
        assertEq(quad.numTokens(), 5, "five active records");
        assertEq(rawTokens.length, 3);
        assertLt(uint160(rawTokens[0]), uint160(rawTokens[1]));
        assertLt(uint160(rawTokens[1]), uint160(rawTokens[2]));
        _seedBalancer();
        _balancerDirections(pairRecord.p0());
        _balancerDirections(rawTokens[0]);
    }

    /// @notice Retain all five records while binding the primary leg's second provider target.
    function test_row_rateTarget_currency1() public override {
        super.test_row_rateTarget_currency1();
        assertEq(quad.rateProvider(faceIdx), fullSpread.currency1Provider());
        assertEq(quad.token(faceIdx), fullSpread.otherToken());
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public override {
        _seedBalancer();
        bool z_ = face < rawTokens[0];
        uint256 preview_ = quad.previewSwapExactIn(face, rawTokens[0], 1 ether);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, PairPoolLib.pairKey(face, rawTokens[0], 1, IHooks(hook)),
            SwapParams(z_, -int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT
        );
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }
}
