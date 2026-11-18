// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice V3-ACC-10/17 matrix row: caller refunds, share-funded joins, and fail-closed SE exact-output.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function _legsV3() internal view returns (address[] memory tokens, address[] memory ses) {
        tokens = new address[](4); ses = new address[](4);
        for (uint256 i; i < 4; ++i) { tokens[i] = fxs[i].faceToken(); ses[i] = fxs[i].se(); }
    }

    /// @dev V3-ACC-17: bootstrap with exact-input-acquired shares, never the retired SE inverse.
    function _seedV3() internal returns (uint256 lp) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        Checks.Seed memory s = Checks.prepareSeed(tokens, ses, hook, user, 100 ether);
        vm.prank(user);
        (lp,) = quad.joinProportionalFlexible(s.amounts, s.isShare, user, 1, block.timestamp);
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
        (quote, expected) = quad.previewJoinProportionalFlexible(a, flags);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256[] memory used;
        vm.prank(user);
        (lp, used) = quad.joinProportionalFlexible(a, flags, user, 0, block.timestamp);
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
        for (uint256 i; i < 4; ++i) {
            address se_ = fxs[i].se();
            address t = fxs[i].faceToken();
            assertEq(quad.standardExchange(i), se_, "SE bound on the leg");
            assertTrue(quad.isBuffered(i), "leg is buffered");
            assertEq(quad.token(i), t, "face token on the leg");
            assertGt(ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se_))), IERC20(t), _legUnits(i, 1), IERC20(se_)),
                0,
                "SE quotes the face"
            );
        }
        assertEq(quad.standardExchange(faceIdx), seUT, "leg under test bound to fx.se()");
        _assertAllDoorsLive();
        assertGt(_seedV3(), 0, "first mint through the package-deployed hook");
        for (uint256 i; i < 4; ++i) {
            assertGt(_hookSeSharesOf(i), 0, "hook holds SE shares on every leg after buffering");
        }
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedV3();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 amountIn = _legUnits(otherIdx, 1);
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
        _assertJoinUnbalancedPreview();
        _assertDepositSinglePreview();
        _assertWithdrawSinglePreview(shares / 10);
        _assertSwapPreview();
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
