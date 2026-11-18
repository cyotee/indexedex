// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";
import {FullSpreadSequentialQuoteChecks as StateChecks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSequentialQuoteChecks.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice V3-ACC-10/17 matrix row: caller refunds, share-funded joins, and fail-closed SE exact-output.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _seedSequentialQuote() internal {
        seUT2 = address(0);
        _deployRowHook(_rowPkgArgs());
        _setUsageFee(0);
        _setDexFee(0.003e18);
        vm.prank(user);
        IERC20(face2).approve(hook, 100 ether);
        _seedV3();
    }

    function test_sequentialQuote_externalSwapMatchesExecution() public {
        _seedSequentialQuote();
        StateChecks.swaps(fx0, hook, face2, orbital.rateProvider(0));
    }

    function test_sequentialQuote_externalDepositJoinMatchesExecution() public {
        _seedSequentialQuote();
        StateChecks.join(fx0, hook);
    }

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    /// @dev F6 fixed 2026-09-21 (D55): FullSpread exact-out spends the previewed shares and delivers exactly the
    ///      request, so the gold body and default residual tolerance apply. Red record: run 6 tolerances.

    function _legsV3() internal view returns (address[] memory tokens, address[] memory ses) {
        tokens = new address[](3); ses = new address[](3);
        tokens[0] = face0; tokens[1] = face1; tokens[2] = face2;
        ses[0] = seUT0; ses[1] = seUT1; ses[2] = seUT2;
    }

    /// @dev V3-ACC-17: bootstrap with exact-input-acquired shares, never the retired SE inverse.
    function _seedV3() internal returns (uint256 lp) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        Checks.Seed memory s = Checks.prepareSeed(tokens, ses, hook, user, 100 ether);
        vm.prank(user);
        (lp,,,) = orbital.depositFlexible(
            s.amounts[0], ses[0] != address(0), s.amounts[1], ses[1] != address(0),
            s.amounts[2], ses[2] != address(0), user, 1, block.timestamp
        );
        Checks.assertSeed(s, tokens, ses, hook, user, lp);
    }

    /// @dev Share-funded proportional join retains preview, accepted-input and LP custody checks.
    function _joinV3(uint256 budget) internal returns (uint256 lp, uint256 faceUsed) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        uint256 beforeFace = IERC20(face0).balanceOf(user);
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
        uint256 p0; uint256 p1; uint256 p2;
        (quote, p0, p1, p2) = orbital.previewDepositFlexible(a[0], flags[0], a[1], flags[1], a[2], flags[2]);
        expected = new uint256[](3); expected[0] = p0; expected[1] = p1; expected[2] = p2;
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256[] memory used;
        vm.prank(user);
        uint256 u0; uint256 u1; uint256 u2;
        (lp, u0, u1, u2) = orbital.depositFlexible(a[0], flags[0], a[1], flags[1], a[2], flags[2], user, 0, block.timestamp);
        used = new uint256[](3); used[0] = u0; used[1] = u1; used[2] = u2;
        assertGt(lp, 0, "positive proportional join");
        assertEq(lp, quote, "flexible join preview equals execution");
        assertEq(used, expected, "all accepted inputs equal their previews");
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, lp, "net LP custody");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(balances[i] - IERC20(flags[i] ? ses[i] : tokens[i]).balanceOf(user), used[i], "caller pays accepted input only");
        }
        faceUsed = beforeFace - IERC20(face0).balanceOf(user);
    }

    function test_row_bind_deploysThroughPackage() public override {
        assertEq(orbital.token0(), face0, "face0 on leg 0");
        assertEq(orbital.token1(), face1, "face1 on leg 1");
        assertEq(orbital.token2(), face2, "face2 on leg 2");
        assertEq(orbital.standardExchange(0), seUT0, "SE bound on leg 0");
        assertEq(orbital.standardExchange(1), seUT1, "SE bound on leg 1");
        assertEq(orbital.standardExchange(2), seUT2, "SE bound on leg 2");
        assertTrue(orbital.isBuffered(0), "leg 0 is buffered");
        assertTrue(orbital.isBuffered(1), "leg 1 is buffered");
        assertTrue(orbital.isBuffered(2), "leg 2 is buffered");
        _assertThreeProductDoorsLive();
        (uint256 previewAmountOut1,) = IStandardExchangeIn(seUT0).previewExchangeIn(IERC20(face0), _f0(1), IERC20(seUT0));
        assertGt(previewAmountOut1, 0, "SE0 quotes face0");
        (uint256 previewAmountOut2,) = IStandardExchangeIn(seUT1).previewExchangeIn(IERC20(face1), _f1(1), IERC20(seUT1));
        assertGt(previewAmountOut2, 0, "SE1 quotes face1");
        (uint256 previewAmountOut3,) = IStandardExchangeIn(seUT2).previewExchangeIn(IERC20(face2), _f2(1), IERC20(seUT2));
        assertGt(previewAmountOut3, 0, "SE2 quotes face2");
        assertGt(_seedV3(), 0, "first mint through the package-deployed hook");
        assertGt(_hookSeShares(0), 0, "hook holds SE0 shares after buffering");
        assertGt(_hookSeShares(1), 0, "hook holds SE1 shares after buffering");
        assertGt(_hookSeShares(2), 0, "hook holds SE2 shares after buffering");
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedV3();
        IERC20 tin = IERC20(face1);
        IERC20 tout = IERC20(face0);
        uint256 amountIn = _f1(1);
        _mintFor(face1, rowEoa, amountIn);
        vm.prank(rowEoa);
        tin.transfer(hook, amountIn);
        uint256 hookInBefore = tin.balanceOf(hook);
        uint256 outBefore = tout.balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);IStandardExchangeIn(hook).exchangeIn(tin, amountIn, tout, 0, rowEoa, true, block.timestamp + 1 hours);
        assertEq(tin.balanceOf(hook), hookInBefore, "no state change on reject");
        assertEq(tout.balanceOf(rowEoa), outBefore, "no output on reject");
    }

    /// @dev V3-ACC-10: unused deposit input returns to the caller instead of a sleeve.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedV3();
        Checks.refunds(fx0, hook, face0);
    }

    function test_row_roundingToZeroControl() public {
        _seedV3();
        _roundingToZeroControl();
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seedV3();
        fx0.fund(hook, 500 ether);
        uint256 beforeFace = IERC20(face0).balanceOf(user);
        uint256 beforeShares = IERC20(seUT0).balanceOf(hook);
        (, uint256 used) = _joinV3(1 ether);
        assertGt(used, 0, "joiner funds its own deposit");
        assertEq(beforeFace - IERC20(face0).balanceOf(user), used, "resting face does not fund the joiner");
        assertGe(IERC20(face0).balanceOf(hook), 500 ether, "ambient donation remains outside the caller basket");
        assertGt(IERC20(seUT0).balanceOf(hook), beforeShares, "accepted shares belong to hook");
    }

    /// @dev V3-ACC-17: a deficit needing the SE inverse rejects without consuming caller credit.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedV3();
        _mintFor(face1, address(this), 10 ether);
        Checks.hookOut(hook, face1, face0, true);
        Checks.absentOut(seUT0, face0);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedV3();
        _mintFor(face1, address(this), 10 ether);
        Checks.hookOut(hook, face1, face0, false);
        Checks.absentOut(seUT0, face0);
    }

    function test_row_seFailure_rollsBack() public override {
        _seedV3();
        Checks.rollback(fx0, hook, face1, address(pm));
    }

    function test_row_ammCallerFundSeparation() public override {
        _seedV3();
        Checks.callerSeparation(fx0, hook, rowBob);
    }

    function test_row_previewMatchesExecution() public override {
        uint256 shares = _seedV3();
        _joinV3(10 ether);
        _previewDepositSingleRow();
        _previewRemoveRow(shares / 10);
        _previewSwapRow();
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedV3();
        uint256 supply = IERC20(hook).totalSupply();
        uint256 beforeOut = IERC20(face1).balanceOf(user);
        uint256 expected = orbital.previewSwapExactIn(face0, face1, 1 ether);
        _swapExactIn(face0, face1, 1 ether);
        assertGt(expected, 0, "forward executable quote");
        assertEq(IERC20(face1).balanceOf(user) - beforeOut, expected, "forward exact-input parity");
        beforeOut = IERC20(face0).balanceOf(user);
        expected = orbital.previewSwapExactIn(face1, face0, 1 ether);
        _swapExactIn(face1, face0, 1 ether);
        assertGt(expected, 0, "reverse executable quote");
        assertEq(IERC20(face0).balanceOf(user) - beforeOut, expected, "reverse exact-input parity");
        assertEq(IERC20(hook).totalSupply(), supply, "swaps issue no LP");
        Checks.poolOut(swapRouter, _poolKeyFor(face0, face1), face1, face0, user);
        Checks.poolOut(swapRouter, _poolKeyFor(face0, face1), face0, face1, user);
    }

}
