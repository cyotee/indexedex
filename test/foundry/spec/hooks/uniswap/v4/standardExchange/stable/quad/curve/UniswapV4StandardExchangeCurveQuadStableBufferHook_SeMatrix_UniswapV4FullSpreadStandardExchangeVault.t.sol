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
import {SeMatrixFixture} from "../../../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../../../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixSibling, FullSpreadV4MatrixChecks} from "../../../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";

/// @notice Four sorted records: two converting FullSpread member faces and two raw tokens.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixSibling internal pairRecord;
    address[4] internal rowTokens;
    address[4] internal rowSes;
    address[4] internal rowProviders;
    address internal raw0;
    address internal raw1;
    uint256 internal beforeLegs;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public override {
        TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.setUp();
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
        _configureCurve(true);
    }

    function _configureCurve(bool faceAtZero_) internal {
        address placementFace_ = faceAtZero_ ? fullSpread.otherToken() : fullSpread.faceToken();
        pairRecord = new FullSpreadV4MatrixSibling();
        pairRecord.load(fullSpread, placementFace_, faceAtZero_);
        assertLt(uint160(pairRecord.p0()), uint160(pairRecord.p1()), "sibling faces sorted");
        assertTrue(pairRecord.p0() != face && pairRecord.p1() != face, "sibling faces disjoint");
        assertTrue(pairRecord.p0() != fullSpread.otherToken() && pairRecord.p1() != fullSpread.otherToken(), "other face disjoint");
        assertTrue(keccak256(abi.encode(pairRecord.backingKey())) != keccak256(abi.encode(fullSpread.key())), "backing keys disjoint");
        raw0 = FullSpreadV4MatrixChecks.raw(fullSpread, faceAtZero_, 0);
        raw1 = FullSpreadV4MatrixChecks.raw(fullSpread, faceAtZero_, 1);
        if (raw0 > raw1) (raw0, raw1) = (raw1, raw0);
        rowTokens = [face, pairRecord.p0(), raw0, raw1];
        SimpleMintableERC20(pairRecord.p0()).mint(user, 1_000_000 ether);
        _bindCurve(face == fullSpread.faceToken() ? fullSpread.currency0Provider() : fullSpread.currency1Provider());
    }

    function _bindCurve(address provider_) internal {
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
            }
        }
        for (uint256 i; i < 4; ++i) {
            bool isFace_ = rowTokens[i] == face;
            bool isPair_ = rowTokens[i] == pairRecord.p0();
            rowSes[i] = isFace_ ? seUT : (isPair_ ? pairRecord.share() : address(0));
            rowProviders[i] = isFace_ ? provider_ : (isPair_ ? pairRecord.provider() : address(0));
            legDec[i] = 18;
            fxs[i] = isFace_ ? fx : SeMatrixFixture(address(0));
            if (isFace_) faceIdx = i;
            if (rowTokens[i] == raw0) otherIdx = i;
        }
        other = raw0;
        IPackage.PkgArgs memory args_ = _pkgArgs(rowTokens, rowSes, rowProviders, DEFAULT_BASE_AMP);
        hookPkg.processArgs(abi.encode(args_));
        _deployHookWithArgs(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        SimpleMintableERC20(raw0).mint(user, 1_000_000 ether);
        SimpleMintableERC20(raw1).mint(user, 1_000_000 ether);
        SimpleMintableERC20(raw0).mint(address(this), 1_000_000 ether);
        vm.startPrank(user);
        for (uint256 i; i < 4; ++i) {
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            IERC20(rowTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    /// @notice Fixed-four flexible genesis uses shares only on the two SE-backed legs.
    function _seedCurve() internal returns (uint256 shares_) {
        address[] memory tokens_ = new address[](4);
        address[] memory ses_ = new address[](4);
        for (uint256 i_; i_ < 4; ++i_) { tokens_[i_] = rowTokens[i_]; ses_[i_] = rowSes[i_]; }
        FullSpreadV4MatrixChecks.Seed memory seed_ = FullSpreadV4MatrixChecks.prepareSeed(
            fullSpread, tokens_, ses_, hook, user, 100 ether
        );
        vm.prank(user);
        (shares_,) = quad.joinProportionalFlexible(seed_.amounts, seed_.isShare, user, 1, block.timestamp);
        FullSpreadV4MatrixChecks.assertSeed(seed_, tokens_, ses_, hook, user, shares_);
    }

    function _curveDirections(address counter_) internal {
        FullSpreadV4MatrixChecks.preview(fullSpread, face);
        PoolKey memory key_ = PairPoolLib.pairKey(face, counter_, 1, IHooks(hook));
        bool faceAtZero_ = face < counter_;
        assertEq(Currency.unwrap(faceAtZero_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product/backing keys");
        uint256 input_ = IERC20(face).balanceOf(user);
        uint256 out_ = IERC20(counter_).balanceOf(user);
        uint256 quote_ = quad.previewSwapExactIn(face, counter_, 10 ether);
        uint256 siblingSupply_ = counter_ == pairRecord.p0() ? IERC20(pairRecord.share()).totalSupply() : 0;
        uint256 vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face, counter_, 10 ether);
        FullSpreadV4MatrixChecks.hookRefund(face, seUT, hook, hookFace_);
        assertEq(IERC20(counter_).balanceOf(user) - out_, quote_, "forward amountOut parity");
        assertGt(IERC20(seUT).totalSupply(), vaultSupply_, "forward transaction mints FullSpread shares");
        if (counter_ == pairRecord.p0()) {
            assertLt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "forward redeems sibling");
            siblingSupply_ = IERC20(pairRecord.share()).totalSupply();
        }
        assertEq(input_ - IERC20(face).balanceOf(user), 10 ether, "face input settled");
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input direction");
        input_ = IERC20(counter_).balanceOf(user);
        out_ = IERC20(face).balanceOf(user);
        quote_ = quad.previewSwapExactIn(counter_, face, 10 ether);
        vaultSupply_ = IERC20(seUT).totalSupply();
        _swapExactIn(counter_, face, 10 ether);
        assertEq(IERC20(face).balanceOf(user) - out_, quote_, "reverse amountOut parity");
        assertLt(IERC20(seUT).totalSupply(), vaultSupply_, "reverse transaction burns FullSpread shares");
        if (counter_ == pairRecord.p0()) assertGt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "reverse mints sibling");
        assertEq(input_ - IERC20(counter_).balanceOf(user), 10 ether, "counter input settled");
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input direction");
    }

    /// @notice Historical failure name, now a real sibling member/conversion proof.
    function test_row_identity_pairToken() public {
        FullSpreadV4MatrixChecks.membership(pairRecord.share(), pairRecord.p0());
        _seedCurve();
        _curveDirections(pairRecord.p0());
    }
    function test_row_rateTarget_currency1() public {
        _currency1Directions(true);
    }

    function test_row_rateTarget_currency1_index1() public {
        _currency1Directions(false);
    }

    function _currency1Directions(bool faceAtZero_) internal {
        assertTrue(vm.revertToState(beforeLegs));
        _configureCurve(faceAtZero_);
        address primaryHook_ = hook;
        address raw_ = raw0;
        address pairShare_ = pairRecord.share();
        rowTokens[faceIdx] = fullSpread.otherToken();
        face = fullSpread.otherToken();
        _bindCurve(fullSpread.currency1Provider());
        assertNotEq(hook, primaryHook_, "second rate-target product pool");
        assertEq(raw0, raw_, "currency1 keeps the primary raw companion");
        assertEq(pairRecord.share(), pairShare_, "currency1 keeps the primary FullSpread sibling record");
        assertEq(face < raw0, faceAtZero_, "currency1 face product index before swap");
        assertEq(face < pairRecord.p0(), faceAtZero_, "currency1 sibling member pair index before swap");
        _seedCurve();
        _curveDirections(raw0);
        _curveDirections(pairRecord.p0());
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(raw0));
        assertLt(uint160(face), uint160(raw1));
        assertTrue(pairRecord.sideMatched(), "required sibling member product index");
        assertLt(uint160(face), uint160(pairRecord.p0()));
        _seedCurve();
        _curveDirections(raw0);
        _curveDirections(pairRecord.p0());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureCurve(false);
        assertGt(uint160(face), uint160(raw0));
        assertGt(uint160(face), uint160(raw1));
        assertTrue(pairRecord.sideMatched(), "required sibling member product index");
        assertGt(uint160(face), uint160(pairRecord.p0()));
        _seedCurve();
        _curveDirections(raw0);
        _curveDirections(pairRecord.p0());
    }

    // Two independently backed SE legs and two raw transfer legs.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(quad.tokens().length, 4);
        assertEq(quad.standardExchange(faceIdx), seUT);
        assertTrue(quad.isBuffered(faceIdx));
        assertEq(quad.standardExchange(otherIdx), address(0));
        assertFalse(quad.isBuffered(otherIdx));
        _assertAllDoorsLive();
        _seedCurve();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedCurve();
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "unbooked donation stays outside caller seed");
    }
    // The V4 vault refunds input to its calling hook; it has no sleeve or capacity gate.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedCurve();
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
        _curveDirections(raw0);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedCurve();
        uint256 in_ = IERC20(raw0).balanceOf(hook);
        uint256 out_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IFullSpreadV4MatrixMoney(hook).exchangeIn(raw0, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(raw0).balanceOf(hook), in_);
        assertEq(IERC20(face).balanceOf(rowEoa), out_);
    }
    // Local output remains executable even though the underlying SE has no exact-output route.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedCurve();
        _curveLocalExactOut(true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedCurve();
        _curveLocalExactOut(false);
    }

    function _curveLocalExactOut(bool pretransferred_) internal {
        uint256 local_ = IERC20(face).balanceOf(hook);
        uint256 want_ = local_ / 2;
        assertGt(want_, 0);
        uint256 needed_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(raw0), IERC20(face), want_);
        assertGt(needed_, 0);
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 before_ = IERC20(face).balanceOf(address(rowCaller));
        uint256 maximum_ = needed_ * 3;
        bytes memory data_ = abi.encodeCall(IStandardExchangeOut.exchangeOut, (
            IERC20(raw0), maximum_, IERC20(face), want_, address(rowCaller), pretransferred_, block.timestamp
        ));
        vm.prank(user);
        IERC20(raw0).approve(address(rowCaller), maximum_);
        bytes memory returned_;
        if (pretransferred_) returned_ = rowCaller.consumePretransfer(IERC20(raw0), user, hook, maximum_, data_);
        else returned_ = rowCaller.consumePull(IERC20(raw0), user, hook, needed_, data_);
        assertEq(abi.decode(returned_, (uint256)), needed_);
        assertEq(IERC20(face).balanceOf(address(rowCaller)) - before_, want_);
        assertEq(IERC20(face).balanceOf(hook), local_ - want_);
        assertEq(IERC20(seUT).balanceOf(hook), shares_);
        assertEq(IERC20(seUT).totalSupply(), supply_, "no unavailable SE output operation");
        assertEq(IERC20(raw0).balanceOf(address(rowCaller)), pretransferred_ ? maximum_ - needed_ : 0);
        uint256 deficitRequest_ = IERC20(face).balanceOf(hook) + 1 ether;
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(raw0), IERC20(face), deficitRequest_);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedCurve();
        _curveDirections(raw0);
        _curveDirections(pairRecord.p0());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 r_ = IERC20(raw0).balanceOf(user);
        PoolKey memory key_ = PairPoolLib.pairKey(raw0, face, 1, IHooks(hook));
        bool z_ = raw0 < face;
        uint256 unsupported_ = IERC20(face).balanceOf(hook) + 1 ether;
        SwapParams memory p_ = SwapParams(z_, int256(unsupported_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_, "exact-out pays no face");
        assertEq(IERC20(raw0).balanceOf(user), r_, "exact-out pays no raw");
    }
    // A public minimum-output failure replaces the V3 operative-revert mock.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override {
        _seedCurve();
        _curveDirections(raw0);
        _curveDirections(pairRecord.p0());
    }
    // There is no reserved sleeve; another depositor receives shares, not this hook's inventory.
    function test_row_ammCallerFundSeparation() public override {
        _seedCurve();
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

    /// @notice Cold primary-target redemption must exceed local inventory and burn SE supply.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency0_redeem() public {
        _composedGas(false, true);
    }

    /// @notice Cold mint through a separate product pool using the second provider target.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_mint() public {
        _composedGas(true, false);
    }

    /// @notice Cold second-target redemption, including hook work and actual SE burn.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_redeem() public {
        _composedGas(true, true);
    }

    function _composedGas(bool currency1_, bool redeem_) internal {
        if (currency1_) {
            address primaryHook_ = hook;
            rowTokens[faceIdx] = fullSpread.otherToken();
            face = fullSpread.otherToken();
            _bindCurve(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "separate second-target product pool");
            assertEq(quad.rateProvider(faceIdx), fullSpread.currency1Provider());
        }
        _seedCurve();
        address tokenIn_ = redeem_ ? raw0 : face;
        address tokenOut_ = redeem_ ? face : raw0;
        uint256 amount_ = redeem_ ? 30 ether : 1 ether;
        uint256 preview_ = quad.previewSwapExactIn(tokenIn_, tokenOut_, amount_);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        if (redeem_) assertGt(preview_, IERC20(face).balanceOf(hook), "output requires primary SE redemption");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 before_ = IERC20(tokenOut_).balanceOf(user);
        bool z_ = tokenIn_ < tokenOut_;
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, PairPoolLib.pairKey(face, raw0, 1, IHooks(hook)),
            SwapParams(z_, -int256(amount_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public {
        _seedCurve();
        bool z_ = face < raw0;
        uint256 preview_ = quad.previewSwapExactIn(face, raw0, 1 ether);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, PairPoolLib.pairKey(face, raw0, 1, IHooks(hook)),
            SwapParams(z_, -int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT
        );
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }
}
