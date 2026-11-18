// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";
import {FullSpreadSequentialQuoteChecks as StateChecks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSequentialQuoteChecks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice V3-ACC-10/17 matrix row: caller refunds, share-funded joins, and fail-closed SE exact-output.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function test_sequentialQuote_externalSwapMatchesExecution() public {
        _seedV3();
        _setDexFee(0.003e18);
        StateChecks.swaps(fx, hook, other, weighted.rateProvider(faceIdx));
    }

    function test_sequentialQuote_externalDepositJoinMatchesExecution() public {
        _seedV3();
        StateChecks.join(fx, hook);
    }

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function _legsV3() internal view returns (address[] memory tokens, address[] memory ses) {
        tokens = new address[](2); ses = new address[](2);
        tokens[faceIdx] = face; tokens[otherIdx] = other; ses[faceIdx] = seUT;
    }

    /// @dev V3-ACC-17: bootstrap with exact-input-acquired shares, never the retired SE inverse.
    function _seedV3() internal returns (uint256 lp) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        Checks.Seed memory s = Checks.prepareSeed(tokens, ses, hook, user, 100 ether);
        vm.prank(user);
        (lp,) = weighted.joinProportionalFlexible(s.amounts, s.isShare, user, 1, block.timestamp);
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
        (quote, expected) = weighted.previewJoinProportionalFlexible(a, flags);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256[] memory used;
        vm.prank(user);
        (lp, used) = weighted.joinProportionalFlexible(a, flags, user, 0, block.timestamp);
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
        assertEq(weighted.standardExchange(faceIdx), seUT, "SE bound on the face leg");
        assertTrue(weighted.isBuffered(faceIdx), "face leg is buffered");
        assertEq(weighted.standardExchange(otherIdx), address(0), "raw leg has no SE");
        assertEq(weighted.token(faceIdx), face, "face token on the leg");
        _assertAllDoorsLive();
        assertGt(ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(seUT))), IERC20(face), _f(1), IERC20(seUT)), 0, "SE quotes the face"
        );
        assertGt(_seedV3(), 0, "first mint through the package-deployed hook");
        assertGt(_hookSeShares(), 0, "hook holds SE shares after buffering");
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedV3();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 amountIn = 1 ether;
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
        uint256 checkpoint = vm.snapshotState();
        uint256 singleQuote = weighted.previewWithdrawSingle(face, burn);
        assertGt(singleQuote, 0);
        uint256 faceBeforeSingle = IERC20(face).balanceOf(user);
        uint256 lpBeforeSingle = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 singlePaid = weighted.withdrawSingle(face, burn, user, singleQuote, block.timestamp + 1 hours);
        assertEq(singlePaid, singleQuote, "sequential single withdrawal preview == execution");
        assertEq(IERC20(face).balanceOf(user) - faceBeforeSingle, singleQuote, "single output delivered");
        assertEq(IERC20(hook).balanceOf(user), lpBeforeSingle - burn, "single withdrawal burns caller LP");
        assertTrue(vm.revertToState(checkpoint));
        (address[] memory tokens,) = _legsV3();
        uint256[] memory before = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) before[i] = IERC20(tokens[i]).balanceOf(user);
        uint256[] memory expected = weighted.previewExitProportional(burn);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256[] memory out = weighted.exitProportional(burn, user, expected, block.timestamp + 1 hours);
        assertEq(out, expected, "proportional withdrawal preview == execution");
        assertEq(IERC20(hook).balanceOf(user), lpBefore - burn, "caller LP burned");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(IERC20(tokens[i]).balanceOf(user) - before[i], out[i], "each withdrawal token delivered");
        }

        uint256 pSwap = weighted.previewSwapExactIn(face, other, _f(1));
        uint256 oBefore = IERC20(other).balanceOf(user);
        _swapExactIn(face, other, _f(1));
        assertEq(IERC20(other).balanceOf(user) - oBefore, pSwap, "swap preview == execution");
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedV3();
        uint256 supply = IERC20(hook).totalSupply();
        uint256 beforeOut = IERC20(other).balanceOf(user);
        uint256 expected = weighted.previewSwapExactIn(face, other, 1 ether);
        _swapExactIn(face, other, 1 ether);
        assertGt(expected, 0, "forward executable quote");
        assertEq(IERC20(other).balanceOf(user) - beforeOut, expected, "forward exact-input parity");
        beforeOut = IERC20(face).balanceOf(user);
        expected = weighted.previewSwapExactIn(other, face, 1 ether);
        _swapExactIn(other, face, 1 ether);
        assertGt(expected, 0, "reverse executable quote");
        assertEq(IERC20(face).balanceOf(user) - beforeOut, expected, "reverse exact-input parity");
        assertEq(IERC20(hook).totalSupply(), supply, "swaps issue no LP");
        Checks.poolOut(swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)), other, face, user);
        Checks.poolOut(swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)), face, other, user);
    }

    function test_row_localExactOut_preservesPretransferCredit() public {
        _seedV3();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 wantOut = _f(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(needIn, 0);
        uint256 fatMax = needIn * 3;
        _mintFor(other, address(this), fatMax);
        tin.approve(address(rowCaller), fatMax);
        uint256 callerOutBefore = tout.balanceOf(address(rowCaller));
        uint256 seBefore = _hookSeShares();
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 deficit = wantOut > local ? wantOut - local : 0;
        uint256 expectedDebit = deficit == 0 ? 0 : IStandardExchangeOut(seUT).previewExchangeOut(IERC20(seUT), IERC20(face), deficit);
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (tin, fatMax, tout, wantOut, address(rowCaller), true, block.timestamp + 1 hours)
        );
        vm.recordLogs();
        uint256 used = abi.decode(rowCaller.consumePretransfer(tin, address(this), hook, fatMax, data), (uint256));
        assertGt(used, 0);
        assertLe(used, fatMax, "used within the bounded credit");
        assertEq(tout.balanceOf(address(rowCaller)) - callerOutBefore, wantOut, "exact output delivered");
        assertEq(tin.balanceOf(address(rowCaller)), fatMax - used, "refund is credit - used");
        assertEq(tin.balanceOf(address(this)), 0, "payer spent fatMax");
        assertEq(
            seBefore + _faceSharesMintedToHook(), _hookSeShares() + expectedDebit,
            "SE share debit matches the exact-output quote including minted-back shares"
        );
    }

    function test_row_localExactOut_pullsOnlyUsed() public {
        _seedV3();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 wantOut = _f(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        uint256 fatMax = needIn * 3;
        _mintFor(other, user, fatMax);
        vm.startPrank(user);
        tin.approve(hook, fatMax);
        uint256 outBefore = tout.balanceOf(user);
        uint256 inBefore = tin.balanceOf(user);
        uint256 used =
            IStandardExchangeOut(hook).exchangeOut(tin, fatMax, tout, wantOut, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(used, needIn, "pulls quoted used");
        assertEq(inBefore - tin.balanceOf(user), needIn, "only used pulled");
        assertEq(tout.balanceOf(user) - outBefore, wantOut, "exact output");
    }

}
