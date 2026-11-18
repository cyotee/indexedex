// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {UniswapV4DualSEBCPHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual x UniswapV3FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool token0 (`SimpleMintableERC20`) of a hermetic Uniswap V3 3000-fee pool seeded by an
///         independent LP; SE deployed through the production FullSpread V3 package (shared per test contract).
contract UniswapV4DualSEBCPHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }


    function _legsV3() internal view returns (address[] memory tokens, address[] memory ses) {
        tokens = new address[](2); ses = new address[](2);
        tokens[0] = dual.currency0(); tokens[1] = dual.currency1();
        ses[0] = faceIsC0 ? seUT : seUT1; ses[1] = faceIsC0 ? seUT1 : seUT;
    }

    /// @dev V3-ACC-17: bootstrap does not depend on the retired SE inverse.
    function _seed() internal override returns (uint256 lp) {
        (address[] memory tokens, address[] memory ses) = _legsV3();
        Checks.Seed memory s = Checks.prepareSeed(tokens, ses, hook, user, 100 ether);
        vm.prank(user);
        (lp,,) = dual.depositFlexible(s.amounts[0], true, s.amounts[1], true, user, 1, block.timestamp);
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
        (quote, expected[0], expected[1]) = dual.previewDepositFlexible(a[0], true, a[1], true);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256[] memory used = new uint256[](2);
        vm.prank(user);
        (lp, used[0], used[1]) = dual.depositFlexible(a[0], true, a[1], true, user, 0, block.timestamp);
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
        _mintFor(other, address(this), 10 ether);
        Checks.hookOut(hook, other, face, true);
        Checks.absentOut(seUT, face);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed();
        _mintFor(other, address(this), 10 ether);
        Checks.hookOut(hook, other, face, false);
        Checks.absentOut(seUT, face);
    }

    function test_row_seFailure_rollsBack() public override {
        _seed();
        Checks.rollback(fx, hook, other, address(pm));
    }

    function test_row_ammCallerFundSeparation() public override {
        _seed();
        Checks.callerSeparation(fx, hook, rowBob);
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seed();
        fx.fund(hook, 500 ether);
        uint256 caller = IERC20(face).balanceOf(user);
        uint256 shares = IERC20(seUT).balanceOf(hook);
        (, uint256 used) = _joinV3(1 ether);
        assertGt(used, 0, "joiner funds its input");
        assertEq(caller - IERC20(face).balanceOf(user), used, "resting face is not joiner credit");
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "ambient donation remains outside accepted input");
        assertGt(IERC20(seUT).balanceOf(hook), shares, "hook owns accepted shares");
    }
    function test_row_previewMatchesExecution() public override {
        uint256 lp = _seed();
        _joinV3(10 ether);
        _assertWithdrawPreview(lp / 10);
        _assertSwapPreview();
    }

    function test_row_sequentialShareJoinPreviewMatchesMintAndRefund() public {
        _seed();
        uint256 amount = Checks.acquireShares(seUT, face, user, 10 ether);
        vm.prank(user);
        IERC20(seUT).approve(hook, amount);
        uint256 beforeShares = IERC20(seUT).balanceOf(user);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        (uint256 quote, uint256 used0, uint256 used1) = dual.previewDepositFlexible(
            faceIsC0 ? amount : 0, true, faceIsC0 ? 0 : amount, true
        );
        assertEq(IUniswapV4SeBufferHook(hook).previewJoinSingleAssetExactIn(seUT, amount), quote);
        vm.prank(user);
        uint256 minted = IUniswapV4SeBufferHook(hook).joinSingleAssetExactIn(seUT, amount, user, quote, block.timestamp);
        assertGt(minted, 0);
        assertEq(minted, quote);
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, quote);
        assertEq(beforeShares - IERC20(seUT).balanceOf(user), faceIsC0 ? used0 : used1);
    }

    function test_row_sequentialPairExitsMatchCustodyInBothDirections() public {
        _seed();
        for (uint256 mode; mode < 2; ++mode) {
            uint256 checkpoint = vm.snapshotState();
            address token = mode == 0 ? face : other;
            uint256 burned = IERC20(hook).balanceOf(user) / 10;
            uint256 beforeToken = IERC20(token).balanceOf(user);
            uint256 beforeLp = IERC20(hook).balanceOf(user);
            uint256 supply = IERC20(hook).totalSupply();
            uint256 quote = IUniswapV4SeBufferHook(hook).previewExitSingleAssetExactBptIn(token, burned);
            vm.prank(user);
            uint256 paid = IUniswapV4SeBufferHook(hook).exitSingleAssetExactBptIn(token, burned, user, quote, block.timestamp);
            assertGt(paid, 0);
            assertEq(paid, quote);
            assertEq(IERC20(token).balanceOf(user) - beforeToken, quote);
            assertEq(IERC20(hook).balanceOf(user), beforeLp - burned);
            assertEq(IERC20(hook).totalSupply(), supply - burned);
            assertTrue(vm.revertToState(checkpoint));
        }
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        uint256 supply = IERC20(hook).totalSupply();
        uint256 beforeOut = IERC20(other).balanceOf(user);
        uint256 quote = dual.previewSwapExactIn(face < other, 1 ether);
        _swapExactIn(face, 1 ether);
        assertGt(quote, 0, "forward executable quote");
        assertApproxEqAbs(IERC20(other).balanceOf(user) - beforeOut, quote, DUST, "forward exact-input parity");
        beforeOut = IERC20(face).balanceOf(user);
        quote = dual.previewSwapExactIn(other < face, 1 ether);
        _swapExactIn(other, 1 ether);
        assertGt(quote, 0, "reverse executable quote");
        assertApproxEqAbs(IERC20(face).balanceOf(user) - beforeOut, quote, DUST, "reverse exact-input parity");
        assertEq(IERC20(hook).totalSupply(), supply, "swaps issue no LP");
        Checks.poolOut(swapRouter, poolKey, other, face, user);
        Checks.poolOut(swapRouter, poolKey, face, other, user);
    }

}
