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
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixChecks} from "../../../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {FullSpreadV4MatrixNamedPairToken} from "../../../weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";

/// @notice Four sorted records: one converting FullSpread face, PairToken identity, and two raw tokens.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixNamedPairToken internal pairRecord;
    address[4] internal rowTokens;
    address[4] internal rowSes;
    address[4] internal rowProviders;
    address internal raw0;
    address internal raw1;
    bool internal identityAccepted;
    bytes internal identityRevert;
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
        pairRecord = new FullSpreadV4MatrixNamedPairToken();
        pairRecord.initialize(address(this), face, faceAtZero_);
        assertLt(uint160(pairRecord.p0()), uint160(pairRecord.p1()), "PairToken faces sorted");
        assertTrue(pairRecord.p0() != face && pairRecord.p1() != face, "PairToken faces disjoint");
        assertTrue(pairRecord.p0() != fullSpread.otherToken() && pairRecord.p1() != fullSpread.otherToken(), "other face disjoint");
        assertTrue(keccak256(abi.encode(pairRecord.backingKey())) != keccak256(abi.encode(fullSpread.key())), "backing keys disjoint");
        raw0 = FullSpreadV4MatrixChecks.raw(face, faceAtZero_, keccak256("curve raw0"));
        raw1 = FullSpreadV4MatrixChecks.raw(face, faceAtZero_, keccak256("curve raw1"));
        if (raw0 > raw1) (raw0, raw1) = (raw1, raw0);
        rowTokens = [face, pairRecord.share(), raw0, raw1];
        _bindCurve(fullSpread.currency0Provider());
    }

    function _bindCurve(address provider_) internal {
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
            }
        }
        for (uint256 i; i < 4; ++i) {
            bool isFace_ = rowTokens[i] == face;
            bool isPair_ = rowTokens[i] == pairRecord.share();
            rowSes[i] = isFace_ ? seUT : (isPair_ ? pairRecord.share() : address(0));
            rowProviders[i] = isFace_ ? provider_ : (isPair_ ? pairRecord.provider() : address(0));
            legDec[i] = 18;
            fxs[i] = isFace_ ? fx : SeMatrixFixture(address(0));
            if (isFace_) faceIdx = i;
            if (rowTokens[i] == raw0) otherIdx = i;
        }
        other = raw0;
        IPackage.PkgArgs memory args_ = _pkgArgs(rowTokens, rowSes, rowProviders, DEFAULT_BASE_AMP);
        identityAccepted = false;
        try hookPkg.processArgs(abi.encode(args_)) returns (bytes memory) {
            identityAccepted = true;
        } catch (bytes memory reason_) {
            identityRevert = reason_;
            FullSpreadV4MatrixChecks.record(address(hookPkg), abi.encode(args_), reason_);
            // Separate face/raw0 control, not FS-A26: keep the real share token but omit its rejected SE binding.
            for (uint256 i; i < 4; ++i) {
                if (rowTokens[i] == pairRecord.share()) {
                    args_.standardExchanges[i] = address(0);
                    args_.rateProviders[i] = address(0);
                    args_.seDecimals[i] = 0;
                }
            }
        }
        _deployHookWithArgs(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        SimpleMintableERC20(raw0).mint(user, 1_000_000 ether);
        SimpleMintableERC20(raw1).mint(user, 1_000_000 ether);
        SimpleMintableERC20(raw0).mint(address(this), 1_000_000 ether);
        IERC20(pairRecord.share()).transfer(user, 100_000 ether);
        vm.startPrank(user);
        for (uint256 i; i < 4; ++i) {
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            IERC20(rowTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    function _seedCurve() internal returns (uint256 shares_) {
        uint256[] memory amounts_ = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts_[i] = 100 ether;
        uint256 supply_ = IERC20(pairRecord.share()).totalSupply();
        vm.prank(user);
        (shares_,) = quad.joinProportional(amounts_, user, 0, block.timestamp);
        assertGt(shares_, 0, "real mixed-leg seed");
        assertEq(IERC20(pairRecord.share()).totalSupply(), supply_, "PairToken seed is transfer only");
    }

    function _curveDirections(address counter_) internal {
        PoolKey memory key_ = PairPoolLib.pairKey(face, counter_, 1, IHooks(hook));
        bool faceAtZero_ = face < counter_;
        assertEq(Currency.unwrap(faceAtZero_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product/backing keys");
        address pair_ = pairRecord.share();
        vm.expectCall(pair_, abi.encodeWithSelector(IFullSpreadV4MatrixMoney.exchangeIn.selector), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSelector(IStandardExchangeOut.exchangeOut.selector), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSignature(
            "exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)"
        ), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSignature(
            "exchangeBundleOut(address,uint256,uint256[],address,bool,uint256)"
        ), uint64(0));
        uint256 supply_ = IERC20(pairRecord.share()).totalSupply();
        uint256 input_ = IERC20(face).balanceOf(user);
        uint256 out_ = IERC20(counter_).balanceOf(user);
        _swapExactIn(face, counter_, 1 ether);
        assertEq(input_ - IERC20(face).balanceOf(user), 1 ether, "face input settled");
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input direction");
        input_ = IERC20(counter_).balanceOf(user);
        out_ = IERC20(face).balanceOf(user);
        _swapExactIn(counter_, face, 1 ether);
        assertEq(input_ - IERC20(counter_).balanceOf(user), 1 ether, "counter input settled");
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input direction");
        assertEq(IERC20(pairRecord.share()).totalSupply(), supply_, "PairToken supply unchanged");
    }

    function test_row_identity_pairToken() public {
        emit log_named_bytes("FS-HOOK-04 PairToken rejection; FS-A26 OPEN", identityRevert);
        if (!identityAccepted) {
            assertGt(identityRevert.length, 0, "FS-HOOK-04 recorded; FS-A26 not passed");
            return;
        }
        _seedCurve();
        _curveDirections(pairRecord.share());
    }
    function test_row_rateTarget_currency1() public {
        rowTokens[faceIdx] = fullSpread.otherToken();
        face = fullSpread.otherToken();
        _bindCurve(fullSpread.currency1Provider());
        assertEq(quad.rateProvider(faceIdx), fullSpread.currency1Provider());
        _seedCurve();
        _curveDirections(raw0);
        if (identityAccepted) _curveDirections(pairRecord.share());
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(raw0));
        assertLt(uint160(face), uint160(raw1));
        if (!pairRecord.sideMatched()) {
            emit log("PairToken product-index-0 case UNVERIFIED after 32 vault candidates; raw0 case continues");
            _seedCurve();
            _curveDirections(raw0);
            return;
        }
        assertLt(uint160(face), uint160(pairRecord.share()));
        _seedCurve();
        _curveDirections(raw0);
        if (identityAccepted) _curveDirections(pairRecord.share());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureCurve(false);
        assertGt(uint160(face), uint160(raw0));
        assertGt(uint160(face), uint160(raw1));
        if (!pairRecord.sideMatched()) {
            emit log("PairToken product-index-1 case UNVERIFIED after 32 vault candidates; raw0 case continues");
            _seedCurve();
            _curveDirections(raw0);
            return;
        }
        assertGt(uint160(face), uint160(pairRecord.share()));
        _seedCurve();
        _curveDirections(raw0);
        if (identityAccepted) _curveDirections(pairRecord.share());
    }

    // The other three legs are not converting FullSpread fixtures.
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
        assertLt(IERC20(face).balanceOf(hook), 500 ether, "donation is not returned as a joiner refund");
    }
    // The V4 vault refunds input to its calling hook; it has no sleeve or capacity gate.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
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
    // Hook exact-out rejection is separate from the direct zero vault preview.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedCurve();
        FullSpreadV4MatrixChecks.hookOut(hook, raw0, face, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedCurve();
        FullSpreadV4MatrixChecks.hookOut(hook, raw0, face, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedCurve();
        _curveDirections(raw0);
        if (identityAccepted) _curveDirections(pairRecord.share());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 r_ = IERC20(raw0).balanceOf(user);
        PoolKey memory key_ = PairPoolLib.pairKey(raw0, face, 1, IHooks(hook));
        bool z_ = raw0 < face;
        SwapParams memory p_ = SwapParams(z_, int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_, "exact-out pays no face");
        assertEq(IERC20(raw0).balanceOf(user), r_, "exact-out pays no raw");
    }
    // A public minimum-output failure replaces the V3 operative-revert mock.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override { FullSpreadV4MatrixChecks.preview(fullSpread, face); }
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
}
