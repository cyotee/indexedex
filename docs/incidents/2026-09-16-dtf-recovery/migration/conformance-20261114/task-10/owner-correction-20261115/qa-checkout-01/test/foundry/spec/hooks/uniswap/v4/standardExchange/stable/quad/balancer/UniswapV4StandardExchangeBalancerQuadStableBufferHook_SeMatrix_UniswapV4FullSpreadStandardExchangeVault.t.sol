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
import {IUniswapV4BalancerStableLiquidityUnits} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../../../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../../../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixSibling, FullSpreadV4MatrixChecks} from "../../../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";

/// @notice Two-leg Balancer row; all assertions also accept the separate five-leg row's runtime length.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixSibling internal pairRecord;
    address[] internal rowProviders;
    address[] internal rawTokens;
    uint256 internal rowCount;
    uint256 internal beforeLegs;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.setUp();
        _initializeBalancer(2);
    }

    function _initializeBalancer(uint256 count_) internal {
        rowCount = count_;
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
        _configureBalancer(true);
    }

    function _configureBalancer(bool faceAtZero_) internal {
        address placementFace_ = faceAtZero_ ? fullSpread.otherToken() : fullSpread.faceToken();
        delete legTokens;
        delete rawTokens;
        legTokens.push(face);
        if (rowCount == 5) {
            pairRecord = new FullSpreadV4MatrixSibling();
            pairRecord.load(fullSpread, placementFace_, faceAtZero_);
            assertLt(uint160(pairRecord.p0()), uint160(pairRecord.p1()), "sibling faces sorted");
            assertTrue(pairRecord.p0() != face && pairRecord.p1() != face, "sibling faces disjoint");
            assertTrue(pairRecord.p0() != fullSpread.otherToken() && pairRecord.p1() != fullSpread.otherToken(), "other face disjoint");
            assertTrue(keccak256(abi.encode(pairRecord.backingKey())) != keccak256(abi.encode(fullSpread.key())), "backing keys disjoint");
            legTokens.push(pairRecord.p0());
            SimpleMintableERC20(pairRecord.p0()).mint(user, 1_000_000 ether);
        }
        uint256 rawCount_ = rowCount == 5 ? 3 : 1;
        for (uint256 i; i < rawCount_; ++i) {
            address raw_ = FullSpreadV4MatrixChecks.raw(fullSpread, faceAtZero_, i);
            rawTokens.push(raw_);
            legTokens.push(raw_);
        }
        for (uint256 i; i < rawCount_; ++i) {
            for (uint256 j = i + 1; j < rawCount_; ++j) {
                if (rawTokens[j] < rawTokens[i]) (rawTokens[i], rawTokens[j]) = (rawTokens[j], rawTokens[i]);
            }
        }
        other = rawTokens[0];
        _bindBalancer(face == fullSpread.faceToken() ? fullSpread.currency0Provider() : fullSpread.currency1Provider());
    }

    function _bindBalancer(address provider_) internal {
        for (uint256 i; i < rowCount; ++i) {
            for (uint256 j = i + 1; j < rowCount; ++j) {
                if (legTokens[j] < legTokens[i]) (legTokens[i], legTokens[j]) = (legTokens[j], legTokens[i]);
            }
        }
        delete legSes;
        delete legDecs;
        delete rowProviders;
        delete fxs;
        for (uint256 i; i < rowCount; ++i) {
            bool isFace_ = legTokens[i] == face;
            bool isPair_ = rowCount == 5 && legTokens[i] == pairRecord.p0();
            legSes.push(isFace_ ? seUT : (isPair_ ? pairRecord.share() : address(0)));
            rowProviders.push(isFace_ ? provider_ : (isPair_ ? pairRecord.provider() : address(0)));
            legDecs.push(18);
            fxs.push(isFace_ ? fx : SeMatrixFixture(address(0)));
            if (isFace_) faceIdx = i;
            if (legTokens[i] == other) otherIdx = i;
        }
        // Deliberately do not call the TestBase's fixed-four `_pkgArgs` constructor.
        IPackage.PkgArgs memory args_;
        args_.poolManager = address(pm);
        args_.feeOracle = address(indexedexManager);
        args_.tokens = legTokens;
        args_.standardExchanges = legSes;
        args_.rateProviders = rowProviders;
        args_.tokenDecimals = new uint8[](rowCount);
        args_.seDecimals = new uint8[](rowCount);
        args_.baseAmp = DEFAULT_BASE_AMP;
        for (uint256 i; i < rowCount; ++i) {
            args_.tokenDecimals[i] = 18;
            args_.seDecimals[i] = legSes[i] == address(0) ? 0 : 18;
        }
        hookPkg.processArgs(abi.encode(args_));
        _deployHookWithArgs(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        for (uint256 i; i < rawTokens.length; ++i) {
            SimpleMintableERC20(rawTokens[i]).mint(user, 1_000_000 ether);
            SimpleMintableERC20(rawTokens[i]).mint(address(this), 1_000_000 ether);
        }
        vm.startPrank(user);
        for (uint256 i; i < rowCount; ++i) {
            IERC20(legTokens[i]).approve(hook, type(uint256).max);
            IERC20(legTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    /// @dev No `_seed`, `_joinBoth`, `_joinAll`, or `_amounts`: they assume four legs.
    /// @notice Bootstrap using pre-acquired shares for SE legs and raw tokens otherwise.
    function _seedBalancer() internal returns (uint256 shares_) {
        address[] memory tokens_ = legTokens;
        address[] memory ses_ = legSes;
        FullSpreadV4MatrixChecks.Seed memory seed_ = FullSpreadV4MatrixChecks.prepareSeed(
            fullSpread, tokens_, ses_, hook, user, 100 ether
        );
        vm.prank(user);
        (shares_,) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(
            seed_.amounts, seed_.isShare, user, 1, block.timestamp
        );
        FullSpreadV4MatrixChecks.assertSeed(seed_, tokens_, ses_, hook, user, shares_);
    }

    function _balancerDirections(address counter_) internal {
        FullSpreadV4MatrixChecks.preview(fullSpread, face);
        PoolKey memory key_ = PairPoolLib.pairKey(face, counter_, 1, IHooks(hook));
        bool faceAtZero_ = face < counter_;
        assertEq(Currency.unwrap(faceAtZero_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product/backing");
        uint256 input_ = IERC20(face).balanceOf(user);
        uint256 out_ = IERC20(counter_).balanceOf(user);
        uint256 quote_ = quad.previewSwapExactIn(face, counter_, 10 ether);
        uint256 siblingSupply_ = rowCount == 5 && counter_ == pairRecord.p0() ? IERC20(pairRecord.share()).totalSupply() : 0;
        uint256 vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face, counter_, 10 ether);
        FullSpreadV4MatrixChecks.hookRefund(face, seUT, hook, hookFace_);
        assertEq(IERC20(counter_).balanceOf(user) - out_, quote_, "forward amountOut parity");
        assertGt(IERC20(seUT).totalSupply(), vaultSupply_, "forward transaction mints FullSpread shares");
        if (rowCount == 5 && counter_ == pairRecord.p0()) {
            assertLt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "forward redeems sibling");
            siblingSupply_ = IERC20(pairRecord.share()).totalSupply();
        }
        assertEq(input_ - IERC20(face).balanceOf(user), 10 ether, "face input settled");
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input paid");
        input_ = IERC20(counter_).balanceOf(user);
        out_ = IERC20(face).balanceOf(user);
        quote_ = quad.previewSwapExactIn(counter_, face, 10 ether);
        vaultSupply_ = IERC20(seUT).totalSupply();
        _swapExactIn(counter_, face, 10 ether);
        assertEq(IERC20(face).balanceOf(user) - out_, quote_, "reverse amountOut parity");
        assertLt(IERC20(seUT).totalSupply(), vaultSupply_, "reverse transaction burns FullSpread shares");
        if (rowCount == 5 && counter_ == pairRecord.p0()) assertGt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "reverse mints sibling");
        assertEq(input_ - IERC20(counter_).balanceOf(user), 10 ether, "counter input settled");
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input paid");
        if (rowCount == 5) {
        }
    }

    function test_row_rateTarget_currency1() public virtual {
        uint256 snapshot_ = beforeLegs;
        for (uint256 i; i < 2; ++i) {
            assertTrue(vm.revertToState(snapshot_));
            snapshot_ = vm.snapshotState();
            _configureBalancer(i == 0);
            address primaryHook_ = hook;
            address raw_ = other;
            legTokens[faceIdx] = fullSpread.otherToken();
            face = fullSpread.otherToken();
            _bindBalancer(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "second rate-target product pool");
            assertEq(other, raw_, "currency1 keeps the primary raw companion");
            assertEq(face < other, i == 0, "currency1 face product index before swap");
            _seedBalancer();
            _balancerDirections(other);
        }
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(other));
        if (rowCount == 5) assertTrue(pairRecord.sideMatched(), "required sibling member product index");
        if (rowCount == 5) assertLt(uint160(face), uint160(pairRecord.p0()));
        _seedBalancer();
        _balancerDirections(other);
        if (rowCount == 5) _balancerDirections(pairRecord.p0());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureBalancer(false);
        assertGt(uint160(face), uint160(other));
        if (rowCount == 5) assertTrue(pairRecord.sideMatched(), "required sibling member product index");
        if (rowCount == 5) assertGt(uint160(face), uint160(pairRecord.p0()));
        _seedBalancer();
        _balancerDirections(other);
        if (rowCount == 5) _balancerDirections(pairRecord.p0());
    }

    // Every inherited public test uses the runtime-length mixed record instead of fixed-four helpers.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(quad.numTokens(), rowCount);
        assertEq(quad.standardExchange(faceIdx), seUT);
        assertTrue(quad.isBuffered(faceIdx));
        assertEq(quad.standardExchange(otherIdx), address(0));
        assertFalse(quad.isBuffered(otherIdx));
        _assertAllDoorsLive();
        _seedBalancer();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedBalancer();
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "unbooked donation stays outside caller seed");
    }
    // FullSpread refunds to its caller, not to a sleeve or directly to the swapper.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedBalancer();
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
        _balancerDirections(other);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedBalancer();
        uint256 in_ = IERC20(other).balanceOf(hook);
        uint256 out_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(other).balanceOf(hook), in_);
        assertEq(IERC20(face).balanceOf(rowEoa), out_);
    }
    // Local-only exact output succeeds; an SE deficit retains the unsupported conversion boundary.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedBalancer();
        _balancerLocalExactOut(true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedBalancer();
        _balancerLocalExactOut(false);
    }

    function _balancerLocalExactOut(bool prepaid) internal {
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 wanted = local / 2;
        assertGt(wanted, 0);
        uint256 required = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), wanted);
        uint256 maximum = required * 2;
        uint256 sharesBefore = IERC20(seUT).balanceOf(hook);
        if (prepaid) {
            SimpleMintableERC20(other).mint(address(this), maximum);
            IERC20(other).approve(address(rowCaller), maximum);
            uint256 oldRefund = IERC20(other).balanceOf(address(rowCaller));
            uint256 oldOutput = IERC20(face).balanceOf(address(rowCaller));
            bytes memory result = rowCaller.consumePretransfer(IERC20(other), address(this), hook, maximum,
                abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(other), maximum, IERC20(face), wanted, address(rowCaller), true, block.timestamp)));
            assertEq(abi.decode(result, (uint256)), required);
            assertEq(IERC20(other).balanceOf(address(rowCaller)) - oldRefund, maximum - required);
            assertEq(IERC20(face).balanceOf(address(rowCaller)) - oldOutput, wanted);
        } else {
            uint256 oldInput = IERC20(other).balanceOf(user);
            uint256 oldOutput = IERC20(face).balanceOf(user);
            vm.prank(user);
            uint256 spent = IStandardExchangeOut(hook).exchangeOut(IERC20(other), maximum, IERC20(face), wanted, user, false, block.timestamp);
            assertEq(spent, required);
            assertEq(oldInput - IERC20(other).balanceOf(user), required);
            assertEq(IERC20(face).balanceOf(user) - oldOutput, wanted);
        }
        assertEq(IERC20(face).balanceOf(hook), local - wanted);
        assertEq(IERC20(seUT).balanceOf(hook), sharesBefore, "local output avoids unavailable SE exact-out");
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), local - wanted + 1);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedBalancer();
        _balancerDirections(other);
        if (rowCount == 5) _balancerDirections(pairRecord.p0());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        PoolKey memory key_ = PairPoolLib.pairKey(other, face, 1, IHooks(hook));
        bool z_ = other < face;
        SwapParams memory p_ = SwapParams(z_, int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_);
        assertEq(IERC20(other).balanceOf(user), o_);
    }
    // Public AmountOutNotMet replaces the inherited operative-dependency mock.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override {
        _seedBalancer();
        _balancerDirections(other);
        if (rowCount == 5) _balancerDirections(pairRecord.p0());
    }
    function test_row_ammCallerFundSeparation() public override {
        _seedBalancer();
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT, 10 ether);
        IFullSpreadV4MatrixMoney(seUT).exchangeIn(fullSpread.otherToken(), 10 ether, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT).balanceOf(hook), shares_, "other caller cannot take hook shares");
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
            legTokens[faceIdx] = fullSpread.otherToken();
            face = fullSpread.otherToken();
            _bindBalancer(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "separate second-target product pool");
            assertEq(quad.rateProvider(faceIdx), fullSpread.currency1Provider());
        }
        _seedBalancer();
        address tokenIn_ = redeem_ ? other : face;
        address tokenOut_ = redeem_ ? face : other;
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
            swapRouter, PairPoolLib.pairKey(face, other, 1, IHooks(hook)),
            SwapParams(z_, -int256(amount_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public virtual {
        _seedBalancer();
        bool z_ = face < other;
        uint256 preview_ = quad.previewSwapExactIn(face, other, 1 ether);
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
}
