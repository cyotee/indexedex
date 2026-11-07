// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixSibling, FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/// @notice Three sorted records: primary FullSpread member 50%, sibling member 25%, raw 25%.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3 is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixSibling internal pairRecord;
    address[] internal rowTokens;
    address[] internal rowSes;
    address[] internal rowProviders;
    uint256[] internal rowWeights;
    uint256 internal beforeLegs;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public override {
        TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp();
        fx = _newFixture();
        face = fx.faceToken();
        seUT = fx.se();
        faceDec = 18;
        rejectBytes = abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector);
        pm = fullSpread.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        beforeLegs = vm.snapshotState();
        _configureThree(true);
    }

    function _configureThree(bool faceAtZero_) internal {
        pairRecord = new FullSpreadV4MatrixSibling();
        pairRecord.load(fullSpread, face, faceAtZero_);
        assertLt(uint160(pairRecord.p0()), uint160(pairRecord.p1()), "sibling faces sorted");
        assertTrue(pairRecord.p0() != face && pairRecord.p1() != face, "sibling faces disjoint");
        assertTrue(pairRecord.p0() != fullSpread.otherToken() && pairRecord.p1() != fullSpread.otherToken(), "other face disjoint");
        assertTrue(keccak256(abi.encode(pairRecord.backingKey())) != keccak256(abi.encode(fullSpread.key())), "backing keys disjoint");
        other = FullSpreadV4MatrixChecks.raw(fullSpread, faceAtZero_, 0);
        delete rowTokens;
        rowTokens.push(face);
        rowTokens.push(pairRecord.p0());
        SimpleMintableERC20(pairRecord.p0()).mint(user, 1_000_000 ether);
        rowTokens.push(other);
        _bindThree(fullSpread.currency0Provider());
    }

    /// @notice Sort complete records by token identity, retaining each SE, provider and weight.
    function _bindThree(address provider_) internal {
        for (uint256 i; i < 3; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
            }
        }
        delete rowSes;
        delete rowProviders;
        delete rowWeights;
        for (uint256 i; i < 3; ++i) {
            bool isFace_ = rowTokens[i] == face;
            bool isPair_ = rowTokens[i] == pairRecord.p0();
            rowSes.push(isFace_ ? seUT : (isPair_ ? pairRecord.share() : address(0)));
            rowProviders.push(isFace_ ? provider_ : (isPair_ ? pairRecord.provider() : address(0)));
            rowWeights.push(isFace_ ? 0.5e18 : 0.25e18);
            if (isFace_) faceIdx = i;
            if (rowTokens[i] == other) otherIdx = i;
        }
        IPackage.PkgArgs memory args_ = _pkgArgs(rowTokens, rowWeights, rowSes, rowProviders);
        hookPkg.processArgs(abi.encode(args_));
        _deployHookWithArgs(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(address(this), 1_000_000 ether);
        vm.startPrank(user);
        for (uint256 i; i < 3; ++i) {
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            IERC20(rowTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    /// @dev Runtime-length amount array: no inherited two-leg seed/join/amount helpers.
    /// @notice Bootstrap using pre-acquired shares for SE legs and raw tokens otherwise.
    function _seedThree() internal returns (uint256 shares_) {
        address[] memory tokens_ = rowTokens;
        address[] memory ses_ = rowSes;
        FullSpreadV4MatrixChecks.Seed memory seed_ = FullSpreadV4MatrixChecks.prepareSeed(
            fullSpread, tokens_, ses_, hook, user, 100 ether
        );
        vm.prank(user);
        (shares_,) = weighted.joinProportionalFlexible(
            seed_.amounts, seed_.isShare, user, 1, block.timestamp
        );
        FullSpreadV4MatrixChecks.assertSeed(seed_, tokens_, ses_, hook, user, shares_);
    }

    function _threeDirections(address counter_) internal {
        FullSpreadV4MatrixChecks.preview(fullSpread, face);
        PoolKey memory key_ = PairPoolLib.pairKey(face, counter_, 1, IHooks(hook));
        bool z_ = face < counter_;
        assertEq(Currency.unwrap(z_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product/backing keys");
        uint256 input_ = IERC20(face).balanceOf(user);
        uint256 out_ = IERC20(counter_).balanceOf(user);
        uint256 quote_ = weighted.previewSwapExactIn(face, counter_, 10 ether);
        uint256 siblingSupply_ = counter_ == pairRecord.p0() ? IERC20(pairRecord.share()).totalSupply() : 0;
        uint256 siblingLocal_ = IERC20(counter_).balanceOf(hook);
        uint256 vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face, counter_, 10 ether);
        FullSpreadV4MatrixChecks.hookRefund(face, seUT, hook, hookFace_);
        assertEq(IERC20(counter_).balanceOf(user) - out_, quote_, "forward amountOut parity");
        assertGt(IERC20(seUT).totalSupply(), vaultSupply_, "forward transaction mints FullSpread shares");
        if (counter_ == pairRecord.p0()) {
            if (quote_ > siblingLocal_) assertLt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "deficit redeems sibling");
            else assertEq(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "local sibling output does not redeem");
            siblingSupply_ = IERC20(pairRecord.share()).totalSupply();
        }
        assertEq(input_ - IERC20(face).balanceOf(user), 10 ether, "face input settled");
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input direction");
        input_ = IERC20(counter_).balanceOf(user);
        out_ = IERC20(face).balanceOf(user);
        quote_ = weighted.previewSwapExactIn(counter_, face, 10 ether);
        vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 localBefore_ = IERC20(face).balanceOf(hook);
        _swapExactIn(counter_, face, 10 ether);
        assertEq(IERC20(face).balanceOf(user) - out_, quote_, "reverse amountOut parity");
        if (quote_ > localBefore_) assertLt(IERC20(seUT).totalSupply(), vaultSupply_, "reverse deficit burns FullSpread shares");
        else assertEq(IERC20(seUT).totalSupply(), vaultSupply_, "local output leaves FullSpread shares intact");
        if (counter_ == pairRecord.p0()) assertGt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "reverse mints sibling");
        assertEq(input_ - IERC20(counter_).balanceOf(user), 10 ether, "counter input settled");
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input direction");
    }

    /// @notice Historical failure name, now a real sibling member/conversion proof.
    function test_row_identity_pairToken() public {
        FullSpreadV4MatrixChecks.membership(pairRecord.share(), pairRecord.p0());
        _seedThree();
        _threeDirections(pairRecord.p0());
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(other));
        assertTrue(pairRecord.sideMatched(), "required sibling member product index");
        assertLt(uint160(face), uint160(pairRecord.p0()));
        _seedThree();
        _threeDirections(other);
        _threeDirections(pairRecord.p0());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureThree(false);
        assertGt(uint160(face), uint160(other));
        assertTrue(pairRecord.sideMatched(), "required sibling member product index");
        assertGt(uint160(face), uint160(pairRecord.p0()));
        _seedThree();
        _threeDirections(other);
        _threeDirections(pairRecord.p0());
    }

    // All inherited fixed-two-leg tests are overridden; both SE member legs convert.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(weighted.numTokens(), 3);
        assertEq(weighted.standardExchange(faceIdx), seUT);
        assertTrue(weighted.isBuffered(faceIdx));
        assertEq(weighted.rateProvider(faceIdx), fullSpread.currency0Provider());
        assertEq(weighted.standardExchange(otherIdx), address(0));
        assertFalse(weighted.isBuffered(otherIdx));
        assertEq(rowWeights[faceIdx], 0.5e18);
        for (uint256 i; i < 3; ++i) assertEq(rowWeights[i], i == faceIdx ? 0.5e18 : 0.25e18);
        assertEq(rowWeights[0] + rowWeights[1] + rowWeights[2], 1e18);
        _assertAllDoorsLive();
        _seedThree();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedThree();
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "unbooked donation stays outside caller seed");
    }
    // Refund-to-hook, not a sleeve booked remainder.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedThree();
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
        _threeDirections(other);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedThree();
        uint256 in_ = IERC20(other).balanceOf(hook);
        uint256 out_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(other).balanceOf(hook), in_);
        assertEq(IERC20(face).balanceOf(rowEoa), out_);
    }
    // Both trust flags settle local-only exact output and reconcile credit.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedThree();
        _localExactOut(true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedThree();
        _localExactOut(false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedThree();
        _threeDirections(other);
        _threeDirections(pairRecord.p0());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        PoolKey memory key_ = PairPoolLib.pairKey(other, face, 1, IHooks(hook));
        bool z_ = other < face;
        SwapParams memory p_ = SwapParams(z_, int256(IERC20(face).balanceOf(hook) + 1), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_);
        assertEq(IERC20(other).balanceOf(user), o_);
    }
    // Public minimum failure replaces mocked dependency failure; no sleeve exists.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override {
        _seedThree();
        _threeDirections(other);
        _threeDirections(pairRecord.p0());
    }
    function test_row_ammCallerFundSeparation() public override {
        _seedThree();
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT, 10 ether);
        IFullSpreadV4MatrixMoney(seUT).exchangeIn(fullSpread.otherToken(), 10 ether, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT).balanceOf(hook), shares_);
        assertEq(IERC20(face).balanceOf(rowBob), 0);
    }
    function test_row_exactOutAbsent() public { FullSpreadV4MatrixChecks.absentOut(seUT, face); }

    /// @notice Rebind the primary face without detaching either SE/provider/weight record.
    function _bindSecondTarget() internal {
        address primaryHook_ = hook;
        rowTokens[faceIdx] = fullSpread.otherToken();
        face = fullSpread.otherToken();
        _bindThree(fullSpread.currency1Provider());
        assertNotEq(hook, primaryHook_, "separate second-target product pool");
        for (uint256 i_; i_ < 3; ++i_) {
            if (i_ != 0) assertLt(uint160(rowTokens[i_ - 1]), uint160(rowTokens[i_]), "sorted complete records");
            bool primary_ = rowTokens[i_] == face;
            bool sibling_ = rowTokens[i_] == pairRecord.p0();
            assertEq(weighted.standardExchange(i_), primary_ ? seUT : (sibling_ ? pairRecord.share() : address(0)));
            assertEq(weighted.rateProvider(i_), primary_ ? fullSpread.currency1Provider() : (sibling_ ? pairRecord.provider() : address(0)));
            assertEq(weighted.weight(i_), primary_ ? 0.5e18 : 0.25e18);
        }
    }

    /// @notice The larger weighted configuration also exercises the second rate target.
    function test_row_rateTarget_currency1() public {
        _bindSecondTarget();
        _seedThree();
        _threeDirections(other);
        _threeDirections(pairRecord.p0());
    }

    /// @notice Cold primary-target redemption requires a real SE deficit.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency0_redeem() public {
        _composedGas(false, true);
    }

    /// @notice Cold mint with the second provider on the primary FullSpread leg.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_mint() public {
        _composedGas(true, false);
    }

    /// @notice Cold second-target redemption must burn primary FullSpread supply.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_redeem() public {
        _composedGas(true, true);
    }

    function _composedGas(bool currency1_, bool redeem_) internal {
        if (currency1_) _bindSecondTarget();
        _seedThree();
        address tokenIn_ = redeem_ ? other : face;
        address tokenOut_ = redeem_ ? face : other;
        uint256 amount_ = redeem_ ? 30 ether : 1 ether;
        uint256 preview_ = weighted.previewSwapExactIn(tokenIn_, tokenOut_, amount_);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        if (redeem_) assertGt(preview_, IERC20(face).balanceOf(hook), "output requires primary SE redemption");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 before_ = IERC20(tokenOut_).balanceOf(user);
        bool z_ = tokenIn_ < tokenOut_;
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)),
            SwapParams(z_, -int256(amount_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public {
        _seedThree();
        bool z_ = face < other;
        uint256 preview_ = weighted.previewSwapExactIn(face, other, 1 ether);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)),
            SwapParams(z_, -int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT
        );
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    function _localExactOut(bool pretransferred) internal {
        uint256 amount = IERC20(face).balanceOf(hook) / 2;
        assertGt(amount, 0);
        uint256 quoted = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), amount);
        uint256 budget = quoted + 1 ether;
        IERC20(other).approve(address(rowCaller), budget);
        uint256 sharesBefore = IERC20(seUT).balanceOf(hook);
        uint256 supplyBefore = IERC20(seUT).totalSupply();
        uint256 localBefore = IERC20(face).balanceOf(hook);
        uint256 recipientBefore = IERC20(face).balanceOf(address(rowCaller));
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(other), budget, IERC20(face), amount, address(rowCaller), pretransferred, block.timestamp));
        bytes memory result = pretransferred
            ? rowCaller.consumePretransfer(IERC20(other), address(this), hook, budget, data)
            : rowCaller.consumePull(IERC20(other), address(this), hook, budget, data);
        assertEq(abi.decode(result, (uint256)), quoted);
        assertEq(IERC20(other).balanceOf(address(rowCaller)), budget - quoted);
        assertEq(IERC20(face).balanceOf(address(rowCaller)) - recipientBefore, amount);
        assertEq(IERC20(face).balanceOf(hook), localBefore - amount);
        assertEq(IERC20(seUT).balanceOf(hook), sharesBefore);
        assertEq(IERC20(seUT).totalSupply(), supplyBefore, "local-only output bypasses unavailable SE exact-out");
    }
}
