// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";
import {IUniswapV4BalancerStableLiquidityUnits} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice V3-ACC-10/17 matrix row: caller refunds, share-funded joins, and fail-closed SE exact-output.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function _legsV3() internal view returns (address[] memory tokens, address[] memory ses) {
        tokens = legTokens; ses = legSes;
    }

    /// @dev V3-ACC-17: bootstrap with exact-input-acquired shares, never the retired SE inverse.
    function _seedV3() internal returns (uint256 lp) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        Checks.Seed memory s = Checks.prepareSeed(tokens, ses, hook, user, 100 ether);
        vm.prank(user);
        (lp,) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(s.amounts, s.isShare, user, 1, block.timestamp);
        Checks.assertSeed(s, tokens, ses, hook, user, lp);
    }

    /// @dev Share-funded proportional join retains preview, accepted-input and LP custody checks.
    function _joinV3(uint256 budget) internal returns (uint256 lp, uint256 faceUsed) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        uint256 beforeFace = IERC20(face).balanceOf(user);
        uint256[] memory a = new uint256[](tokens.length);
        bool[] memory flags = new bool[](tokens.length);
        uint256[] memory balances = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            flags[i] = ses[i] != address(0);
            a[i] = flags[i] ? Checks.acquireShares(ses[i], tokens[i], user, budget) : budget;
            address input = flags[i] ? ses[i] : tokens[i];
            balances[i] = IERC20(input).balanceOf(user);
            vm.prank(user);
            IERC20(input).approve(hook, a[i]);
        }
        uint256 quote;
        uint256[] memory expected;
        (quote, expected) = IUniswapV4BalancerStableLiquidityUnits(hook).previewJoinProportionalFlexible(a, flags);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256[] memory used;
        vm.prank(user);
        (lp, used) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(a, flags, user, 0, block.timestamp);
        assertGt(lp, 0, "positive proportional join");
        assertEq(lp, quote, "flexible join preview equals execution");
        assertEq(used, expected, "all accepted inputs equal their previews");
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, lp, "net LP custody");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(balances[i] - IERC20(flags[i] ? ses[i] : tokens[i]).balanceOf(user), used[i], "caller pays accepted input only");
        }
        faceUsed = beforeFace - IERC20(face).balanceOf(user);
    }

    function test_row_bind_deploysThroughPackage() public override {
        assertEq(quad.numTokens(), LEGS, "four legs");
        for (uint256 i; i < LEGS; ++i) {
            assertEq(quad.token(i), legTokens[i], "face token on the leg");
            if (address(fxs[i]) != address(0)) {
                assertEq(quad.standardExchange(i), legSes[i], "SE bound on the leg");
                assertTrue(quad.isBuffered(i), "SE leg is buffered");
                assertGt(ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(legSes[i]))), IERC20(legTokens[i]), _legAmt(i, 1), IERC20(legSes[i])
                    ),
                    0,
                    "SE quotes its face"
                );
            } else {
                assertEq(quad.standardExchange(i), address(0), "raw leg has no SE");
                assertFalse(quad.isBuffered(i), "raw leg is not buffered");
            }
        }
        assertEq(quad.standardExchange(faceIdx), seUT, "SE under test on the face leg");
        _assertAllDoorsLive();
        assertGt(_seedV3(), 0, "first mint through the package-deployed hook");
        assertGt(_hookSeShares(), 0, "hook holds SE shares after buffering");
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedV3();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 amountIn = _legAmt(otherIdx, 1);
        _mintFor(other, rowEoa, amountIn);
        vm.prank(rowEoa);
        tin.transfer(hook, amountIn);
        uint256 hookInBefore = tin.balanceOf(hook);
        uint256 outBefore = tout.balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(IStandardExchangeIn(hook))), tin, amountIn, tout, 0, rowEoa, true, block.timestamp + 1 hours);
        assertEq(tin.balanceOf(hook), hookInBefore, "no state change on reject");
        assertEq(tout.balanceOf(rowEoa), outBefore, "no output on reject");
    }

    /// @dev V3-ACC-10: unused deposit input returns to the caller instead of a sleeve.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedV3();
        Checks.refunds(fx, hook, face);
    }

    function test_row_roundingToZeroControl() public {
        _seedV3();
        _roundingToZeroControl();
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seedV3();
        fx.fund(hook, 500 ether);
        uint256 beforeFace = IERC20(face).balanceOf(user);
        uint256 beforeShares = IERC20(seUT).balanceOf(hook);
        (, uint256 used) = _joinV3(1 ether);
        assertGt(used, 0, "joiner funds its own deposit");
        assertEq(beforeFace - IERC20(face).balanceOf(user), used, "resting face does not fund the joiner");
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "ambient donation remains outside the caller basket");
        assertGt(IERC20(seUT).balanceOf(hook), beforeShares, "accepted shares belong to hook");
    }

    /// @dev V3-ACC-17: a deficit needing the SE inverse rejects without consuming caller credit.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedV3();
        _mintFor(other, address(this), 10 ether);
        Checks.hookOut(hook, other, face, true);
        Checks.absentOut(seUT, face);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedV3();
        _mintFor(other, address(this), 10 ether);
        Checks.hookOut(hook, other, face, false);
        Checks.absentOut(seUT, face);
    }

    function test_row_seFailure_rollsBack() public override {
        _seedV3();
        Checks.rollback(fx, hook, other, address(pm));
    }

    function test_row_ammCallerFundSeparation() public override {
        _seedV3();
        Checks.callerSeparation(fx, hook, rowBob);
    }

    function test_row_previewMatchesExecution() public override {
        uint256 shares = _seedV3();
        _joinV3(10 ether);
        uint256 burn = shares / 10;
        uint256 singleQuote = quad.previewWithdrawSingle(face, burn);
        uint256 checkpoint = vm.snapshotState();
        uint256 singleBefore = IERC20(face).balanceOf(user);
        uint256 singleLp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 singlePaid = quad.withdrawSingle(face, burn, user, singleQuote, block.timestamp);
        assertGt(singlePaid, 0);
        assertEq(singlePaid, singleQuote);
        assertEq(IERC20(face).balanceOf(user) - singleBefore, singleQuote);
        assertEq(IERC20(hook).balanceOf(user), singleLp - burn);
        assertTrue(vm.revertToState(checkpoint));
        (address[] memory tokens,) = _legsV3();
        uint256[] memory before = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) before[i] = IERC20(tokens[i]).balanceOf(user);
        uint256[] memory expected = quad.previewExitProportional(burn);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256[] memory out = quad.exitProportional(burn, user, expected, block.timestamp + 1 hours);
        assertEq(out, expected, "proportional withdrawal preview == execution");
        assertEq(IERC20(hook).balanceOf(user), lpBefore - burn, "caller LP burned");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(IERC20(tokens[i]).balanceOf(user) - before[i], out[i], "each withdrawal token delivered");
        }

        uint256 pSwap = quad.previewSwapExactIn(face, other, _f(1));
        uint256 oBefore = IERC20(other).balanceOf(user);
        _swapExactIn(face, other, _f(1));
        assertEq(IERC20(other).balanceOf(user) - oBefore, pSwap, "swap preview == execution");
    }

    function test_row_bufferedUnbalancedPreviewMatchesMintForPairsAndShares() public {
        _seedV3();
        uint256 funded = Checks.acquireShares(seUT, face, user, 10 ether);
        vm.prank(user);
        IERC20(seUT).approve(hook, funded);
        for (uint256 mode; mode < 2; ++mode) {
            uint256 checkpoint = vm.snapshotState();
            address[] memory inputs = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            inputs[0] = mode == 0 ? face : seUT;
            amounts[0] = mode == 0 ? 1 ether : funded / 10;
            uint256 beforeLp = IERC20(hook).balanceOf(user);
            uint256 beforeInput = IERC20(inputs[0]).balanceOf(user);
            uint256 quote = IUniswapV4SeBufferHook(hook).previewJoinUnbalanced(inputs, amounts);
            (uint256 exchangeQuote, uint256 refund) = IStandardExchangeIn(hook).previewExchangeIn(
                IERC20(inputs[0]), amounts[0], IERC20(hook)
            );
            assertEq(exchangeQuote, quote);
            vm.prank(user);
            uint256 minted = IUniswapV4SeBufferHook(hook).joinUnbalanced(inputs, amounts, user, quote, block.timestamp);
            assertGt(minted, 0);
            assertEq(minted, quote);
            assertEq(IERC20(hook).balanceOf(user) - beforeLp, quote);
            assertEq(beforeInput - IERC20(inputs[0]).balanceOf(user), amounts[0] - refund, "exact caller refund");
            assertTrue(vm.revertToState(checkpoint));
        }
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedV3();
        uint256 supply = IERC20(hook).totalSupply();
        uint256 beforeOut = IERC20(other).balanceOf(user);
        uint256 expected = quad.previewSwapExactIn(face, other, 1 ether);
        _swapExactIn(face, other, 1 ether);
        assertGt(expected, 0, "forward executable quote");
        assertEq(IERC20(other).balanceOf(user) - beforeOut, expected, "forward exact-input parity");
        beforeOut = IERC20(face).balanceOf(user);
        expected = quad.previewSwapExactIn(other, face, 1 ether);
        _swapExactIn(other, face, 1 ether);
        assertGt(expected, 0, "reverse executable quote");
        assertEq(IERC20(face).balanceOf(user) - beforeOut, expected, "reverse exact-input parity");
        assertEq(IERC20(hook).totalSupply(), supply, "swaps issue no LP");
        Checks.poolOut(swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)), other, face, user);
        Checks.poolOut(swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)), face, other, user);
    }

}
