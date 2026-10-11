// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeTransitionQuote as Quote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BalancerV3PoolLiquidationLib as Liquidation} from "contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolLiquidationLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice Shared whole-supply rate and native batch controls for the six real BPT SE families.
abstract contract BalancerSeLiquidationBehavior is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @notice Whole-supply live and projected quotes agree and normalize through the generic provider.
    function test_bptLiquidation_fullSupplyRateAndProjection() public {
        uint256 supply = IERC20(seUT).totalSupply();
        uint256 quoted = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), supply, IERC20(face));
        assertGt(quoted, 0, "whole-supply liquidation value");
        (bytes memory state,) = Quote(seUT).quoteState(face, address(this));
        Liquidation.PoolQuoteState memory decoded = abi.decode(state, (Liquidation.PoolQuoteState));
        assertGt(decoded.poolState.length + decoded.weightedState.length, 0, "virtual book is captured");
        assertEq(Quote(seUT).quoteAssets(state, supply), quoted, "whole-supply projected value");
        assertEq(IRateProvider(weighted.rateProvider(faceIdx)).getRate(),
            Math.mulDiv(quoted, 1e18, supply, Math.Rounding.Ceil), "generic whole-supply rate");
        assertEq(IERC20(seUT).totalSupply(), supply, "quote does not burn");
    }

    /// @notice A 45% BPT redemption exceeds both native weighted and stable one-call caps.
    function test_bptLiquidation_largeExactIn_matchesProjectionAndExecution() public {
        address holder = rowBob;
        uint256 amount = IERC20(seUT).totalSupply() * 45 / 100;
        vm.prank(makeAddr("alice"));
        IERC20(seUT).transfer(holder, amount);
        (bytes memory state,) = Quote(seUT).quoteState(face, holder);
        (bytes memory next, uint256 paid, uint256 out,) = Quote(seUT).quoteTransition(state, Quote.Operation.RedeemExactIn, amount);
        assertEq(paid, amount);
        assertEq(out, IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), amount, IERC20(face)));
        uint256 before = IERC20(face).balanceOf(holder);
        vm.startPrank(holder);
        IERC20(seUT).approve(seUT, amount);
        uint256 got = IStandardExchangeIn(seUT).exchangeIn(IERC20(seUT), amount, IERC20(face), out, holder, false, block.timestamp);
        vm.stopPrank();
        assertEq(got, out, "native batch pays exact preview");
        assertEq(IERC20(face).balanceOf(holder) - before, out, "actual payout");
        (bytes memory actual,) = Quote(seUT).quoteState(face, holder);
        assertEq(actual, next, "all balances, fees, supply and virtual books match");
    }

    /// @notice Exact-out batching delivers only the request and pulls only the quoted BPT.
    function test_bptLiquidation_largeExactOut_pullsQuotedOnly() public {
        address holder = rowBob;
        uint256 supply = IERC20(seUT).totalSupply();
        vm.prank(makeAddr("alice"));
        IERC20(seUT).transfer(holder, supply * 60 / 100);
        uint256 want = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), supply * 45 / 100, IERC20(face));
        uint256 need = IStandardExchangeOut(seUT).previewExchangeOut(IERC20(seUT), IERC20(face), want);
        bytes memory projected = _projectWithdrawal(holder, want, need);
        uint256 bptBefore = IERC20(seUT).balanceOf(holder);
        uint256 assetsBefore = IERC20(face).balanceOf(holder);
        vm.startPrank(holder);
        IERC20(seUT).approve(seUT, bptBefore);
        uint256 used = IStandardExchangeOut(seUT).exchangeOut(IERC20(seUT), bptBefore, IERC20(face), want, holder, false, block.timestamp);
        vm.stopPrank();
        assertEq(used, need, "exact-out input preview");
        assertEq(bptBefore - IERC20(seUT).balanceOf(holder), need, "pull only quoted BPT");
        assertEq(IERC20(face).balanceOf(holder) - assetsBefore, want, "exact output");
        (bytes memory actual,) = Quote(seUT).quoteState(face, holder);
        assertEq(actual, projected, "exact-output batch projects every field");
    }

    function _projectWithdrawal(address holder, uint256 want, uint256 need) private view returns (bytes memory next) {
        (bytes memory state,) = Quote(seUT).quoteState(face, holder);
        uint256 paid;
        uint256 out;
        (next, paid, out,) = Quote(seUT).quoteTransition(state, Quote.Operation.WithdrawExactOut, want);
        assertEq(paid, need);
        assertEq(out, want);
    }

    function test_bptLiquidation_batchMinimum_revertsAllState() public {
        uint256 amount = IERC20(seUT).totalSupply() * 45 / 100;
        vm.prank(makeAddr("alice"));
        IERC20(seUT).transfer(rowBob, amount);
        uint256 quoted = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), amount, IERC20(face));
        (bytes memory beforeState,) = Quote(seUT).quoteState(face, rowBob);
        uint256 assetsBefore = IERC20(face).balanceOf(rowBob);
        vm.startPrank(rowBob);
        IERC20(seUT).approve(seUT, amount);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, quoted + 1, quoted));
        IStandardExchangeIn(seUT).exchangeIn(IERC20(seUT), amount, IERC20(face), quoted + 1, rowBob, false, block.timestamp);
        vm.stopPrank();
        (bytes memory afterState,) = Quote(seUT).quoteState(face, rowBob);
        assertEq(afterState, beforeState, "batch rollback restores supply, balances and virtual book");
        assertEq(IERC20(face).balanceOf(rowBob), assetsBefore, "batch rollback restores recipient");
    }
}
