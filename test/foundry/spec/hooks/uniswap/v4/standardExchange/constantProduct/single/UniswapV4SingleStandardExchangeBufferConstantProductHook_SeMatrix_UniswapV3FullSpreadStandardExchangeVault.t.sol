// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";
import {FullSpreadSequentialQuoteChecks as StateChecks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSequentialQuoteChecks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/// @dev External provider dependency deliberately exposes only its actual live SE quote.
contract LiveOnlyFullSpreadRateProvider {
    IStandardExchangeIn private immutable exchange;
    IERC20 private immutable pair;

    constructor(IStandardExchangeIn exchange_, IERC20 pair_) {
        exchange = exchange_;
        pair = pair_;
    }

    function getRate() external view returns (uint256 amount_) {
        (amount_,) = exchange.previewExchangeIn(IERC20(address(exchange)), 1 ether, pair);
    }
}

/// @notice D20: constantProduct/single x UniswapV3FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool token0 (`SimpleMintableERC20`) of a hermetic Uniswap V3 3000-fee pool seeded by an
///         independent LP; SE deployed through the production FullSpread V3 package (shared per test contract).
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function test_sequentialQuote_externalSwapMatchesExecution() public {
        _seed();
        StateChecks.swaps(fx, hook, raw, single.rateProvider(face));
    }

    function test_sequentialQuote_externalDepositJoinMatchesExecution() public {
        _seed();
        StateChecks.join(fx, hook);
    }

    function test_sequentialQuote_providerRejectsForeignState() public {
        SeMatrixFixture foreignFixture = _newFixture();
        StateChecks.rejectForeignState(single.rateProvider(face), seUT, face, foreignFixture.se());
    }

    function test_sequentialQuote_doesNotSubstituteLiveOnlyProviderRate() public {
        _seed();
        fx.fund(address(this), 10 ether);
        IERC20(face).approve(seUT, 10 ether);
        (uint256 shares,) = IStandardExchangeIn(seUT).exchangeIn(
            IERC20(face), 10 ether, IERC20(seUT), 1, address(this), false, block.timestamp
        );
        LiveOnlyFullSpreadRateProvider provider =
            new LiveOnlyFullSpreadRateProvider(IStandardExchangeIn(seUT), IERC20(face));
        assertGt(provider.getRate(), 0, "a usable live rate is not a projected rate contract");
        LegLib.ExternalQuote memory projected = LegLib.afterExternalExchange(seUT, face, seUT, shares / 2, hook);
        vm.expectRevert(LegLib.RateProviderFailed.selector);
        LegLib.rateAfterExchange(projected, face, address(provider));
    }

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }


    function _legsV3() internal view returns (address[] memory tokens, address[] memory ses) {
        tokens = new address[](2); ses = new address[](2);
        tokens[0] = face; tokens[1] = raw; ses[0] = seUT;
    }

    /// @dev V3-ACC-17: bootstrap does not depend on the retired SE inverse.
    function _seed() internal override returns (uint256 lp) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        Checks.Seed memory s = Checks.prepareSeed(tokens, ses, hook, user, seedUnits * 1 ether);
        vm.prank(user);
        (lp,,) = single.depositWithSeShares(s.amounts[1], s.amounts[0], user, 1, block.timestamp);
        Checks.assertSeed(s, tokens, ses, hook, user, lp);
    }

    function _joinV3(uint256 budget) internal returns (uint256 lp, uint256 faceUsed) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256[] memory a = new uint256[](2);
        uint256[] memory balances = new uint256[](2);
        for (uint256 j; j < 2; ++j) {
            a[j] = ses[j] == address(0) ? budget : Checks.acquireShares(ses[j], tokens[j], user, budget);
            address input = ses[j] == address(0) ? tokens[j] : ses[j];
            balances[j] = IERC20(input).balanceOf(user);
            vm.prank(user);
            IERC20(input).approve(hook, a[j]);
        }
        uint256 quote;
        uint256[] memory expected = new uint256[](2);
        (quote, expected[1], expected[0]) = single.previewDepositWithSeShares(a[1], a[0]);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256[] memory used = new uint256[](2);
        vm.prank(user);
        (lp, used[1], used[0]) = single.depositWithSeShares(a[1], a[0], user, 0, block.timestamp);
        assertGt(lp, 0, "positive share-funded join");
        assertEq(lp, quote, "join LP preview equals execution");
        assertEq(used, expected, "all accepted join inputs match preview");
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, lp, "net LP receipt");
        for (uint256 j; j < 2; ++j) {
            address input = ses[j] == address(0) ? tokens[j] : ses[j];
            assertEq(balances[j] - IERC20(input).balanceOf(user), used[j], "caller pays only accepted join input");
        }
        faceUsed = faceBefore - IERC20(face).balanceOf(user);
    }

    /// @dev V3-ACC-10 replaces booked sleeve input with a refund to the actual caller.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed();
        Checks.refunds(fx, hook, face);
    }

    function test_row_roundingToZeroControl() public {
        _seed();
        _roundingToZeroControl();
    }

    /// @dev V3-ACC-17: no exact-output SE deficit may consume caller input under either flag.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed();
        _mintFor(raw, address(this), 10 ether);
        Checks.hookOut(hook, raw, face, true);
        Checks.absentOut(seUT, face);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed();
        _mintFor(raw, address(this), 10 ether);
        Checks.hookOut(hook, raw, face, false);
        Checks.absentOut(seUT, face);
    }

    function test_row_seFailure_rollsBack() public override {
        _seed();
        Checks.rollback(fx, hook, raw, address(pm));
    }

    function test_row_ammCallerFundSeparation() public override {
        _seed();
        Checks.callerSeparation(fx, hook, rowBob);
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seed();
        uint256 localBefore = IERC20(face).balanceOf(hook);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        address donor = makeAddr("donor");
        uint256 donation = _f(500);
        fx.fund(donor, donation);
        vm.prank(donor);
        IERC20(face).transfer(hook, donation);
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 seBefore = _hookSeShares();
        (, uint256 usedFace) = _joinV3(1 ether);
        assertGt(usedFace, 0, "join used face");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "joiner pays used face; resting face is not the joiner's refund");
        assertGt(_hookSeShares(), seBefore, "buffer-first: SE shares owned by the hook");
        assertEq(IERC20(face).balanceOf(hook),
            localBefore + _f(500) + _ceilComponent(IERC20(hook).totalSupply() - supplyBefore, localBefore, supplyBefore),
            "ambient face remains separate from the accepted local contribution");
    }

    function test_row_previewMatchesExecution() public override {
        uint256 lp = _seed();
        _joinV3(10 ether);

        uint256 burn = lp / 10;
        uint256 pOut = single.previewWithdrawSingle(burn, face);
        uint256 before = IERC20(face).balanceOf(user);
        vm.prank(user);
        uint256 out = single.withdrawSingle(burn, face, user, 0, block.timestamp + 1 hours);
        assertEq(out, pOut, "withdrawSingle(face) preview == execution");
        assertEq(IERC20(face).balanceOf(user) - before, out, "withdraw delivered the returned amount");

        uint256 probe = _previewSwapProbe();
        if (probe == 0) {
            emit log("swap control skipped: the row pins it to a recorded finding (see its test_BLOCKED_* test)");
            return;
        }
        uint256 pSwap = single.previewSwapExactIn(face, raw, probe);
        uint256 rBefore = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, probe);
        assertEq(IERC20(raw).balanceOf(user) - rBefore, pSwap, "swap preview == execution");
    }

    function test_row_localExactOut_preservesPretransferCredit() public { super.test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed(); }
    function test_row_localExactOut_pullsOnlyUsed() public { super.test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly(); }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        uint256 supply = IERC20(hook).totalSupply();
        uint256 beforeOut = IERC20(raw).balanceOf(user);
        uint256 quote = single.previewSwapExactIn(face, raw, 1 ether);
        _swapExactIn(face, raw, 1 ether);
        assertGt(quote, 0, "forward executable quote");
        assertEq(IERC20(raw).balanceOf(user) - beforeOut, quote, "forward exact-input parity");
        beforeOut = IERC20(face).balanceOf(user);
        quote = single.previewSwapExactIn(raw, face, 1 ether);
        _swapExactIn(raw, face, 1 ether);
        assertGt(quote, 0, "reverse executable quote");
        assertEq(IERC20(face).balanceOf(user) - beforeOut, quote, "reverse exact-input parity");
        assertEq(IERC20(hook).totalSupply(), supply, "swaps issue no LP");
        Checks.poolOut(swapRouter, poolKey, raw, face, user);
        Checks.poolOut(swapRouter, poolKey, face, raw, user);
    }

}
