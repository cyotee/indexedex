// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixSibling, FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/// @notice Runtime-length row assertions shared by the two- and three-leg concrete rows.
/// @dev Family-plan section 12: call the weighted test base, then `_initializeWeighted(2)`.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixSibling internal pairRecord;
    address[] internal rowTokens;
    address[] internal rowSes;
    address[] internal rowProviders;
    uint256[] internal rowWeights;
    uint256 internal rowCount;
    uint256 internal beforeLegs;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp();
        _initializeWeighted(2);
    }

    function _initializeWeighted(uint256 count_) internal {
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
        _configureWeighted(true);
    }

    function _configureWeighted(bool faceAtZero_) internal {
        address placementFace_ = faceAtZero_ ? fullSpread.otherToken() : fullSpread.faceToken();
        other = FullSpreadV4MatrixChecks.raw(fullSpread, faceAtZero_, 0);
        delete rowTokens;
        rowTokens.push(face);
        rowTokens.push(other);
        if (rowCount == 3) {
            pairRecord = FullSpreadV4MatrixChecks.pair(fullSpread, placementFace_, faceAtZero_);
            rowTokens.push(pairRecord.p0());
            SimpleMintableERC20(pairRecord.p0()).mint(user, 1_000_000 ether);
        }
        _bindWeighted(face == fullSpread.faceToken() ? fullSpread.currency0Provider() : fullSpread.currency1Provider());
    }

    function _bindWeighted(address provider_) internal {
        for (uint256 i; i < rowCount; ++i) {
            for (uint256 j = i + 1; j < rowCount; ++j) {
                if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
            }
        }
        delete rowSes;
        delete rowProviders;
        delete rowWeights;
        for (uint256 i; i < rowCount; ++i) {
            address token_ = rowTokens[i];
            bool isFace_ = token_ == face;
            bool isPair_ = rowCount == 3 && token_ == pairRecord.p0();
            rowSes.push(isFace_ ? seUT : (isPair_ ? pairRecord.share() : address(0)));
            rowProviders.push(isFace_ ? provider_ : (isPair_ ? pairRecord.provider() : address(0)));
            rowWeights.push(isFace_ || rowCount == 2 ? 0.5e18 : 0.25e18);
            if (isFace_) faceIdx = i;
            if (token_ == other) otherIdx = i;
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
        for (uint256 i; i < rowCount; ++i) {
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            IERC20(rowTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    /// @dev Never reaches the inherited length-two `_amounts` or `_seed`.
    /// @notice Bootstrap using pre-acquired shares for SE legs and raw tokens otherwise.
    function _seedWeighted() internal returns (uint256 shares_) {
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

    function _weightedDirections(address counter_) internal {
        FullSpreadV4MatrixChecks.preview(fullSpread, face);
        bool z_ = face < counter_;
        PoolKey memory key_ = PoolKey(Currency.wrap(z_ ? face : counter_), Currency.wrap(z_ ? counter_ : face), 0, 1, IHooks(hook));
        assertEq(Currency.unwrap(z_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint backing/product");
        uint256 out_ = IERC20(counter_).balanceOf(user);
        uint256 quote_ = weighted.previewSwapExactIn(face, counter_, 10 ether);
        uint256 siblingSupply_ = rowCount == 3 && counter_ == pairRecord.p0() ? IERC20(pairRecord.share()).totalSupply() : 0;
        uint256 siblingLocal_ = IERC20(counter_).balanceOf(hook);
        uint256 vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face, counter_, 10 ether);
        FullSpreadV4MatrixChecks.hookRefund(face, seUT, hook, hookFace_);
        assertEq(IERC20(counter_).balanceOf(user) - out_, quote_, "forward amountOut parity");
        assertGt(IERC20(seUT).totalSupply(), vaultSupply_, "forward transaction mints FullSpread shares");
        if (rowCount == 3 && counter_ == pairRecord.p0()) {
            if (quote_ > siblingLocal_) assertLt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "deficit redeems sibling");
            else assertEq(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "local sibling output does not redeem");
            siblingSupply_ = IERC20(pairRecord.share()).totalSupply();
        }
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input direction");
        out_ = IERC20(face).balanceOf(user);
        quote_ = weighted.previewSwapExactIn(counter_, face, 10 ether);
        vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 localBefore_ = IERC20(face).balanceOf(hook);
        _swapExactIn(counter_, face, 10 ether);
        assertEq(IERC20(face).balanceOf(user) - out_, quote_, "reverse amountOut parity");
        if (quote_ > localBefore_) assertLt(IERC20(seUT).totalSupply(), vaultSupply_, "reverse deficit burns FullSpread shares");
        else assertEq(IERC20(seUT).totalSupply(), vaultSupply_, "local output leaves FullSpread shares intact");
        if (rowCount == 3 && counter_ == pairRecord.p0()) assertGt(IERC20(pairRecord.share()).totalSupply(), siblingSupply_, "reverse mints sibling");
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input direction");
    }

    function test_row_rateTarget_currency1() public virtual {
        uint256 snapshot_ = beforeLegs;
        for (uint256 i; i < 2; ++i) {
            assertTrue(vm.revertToState(snapshot_));
            snapshot_ = vm.snapshotState();
            _configureWeighted(i == 0);
            address primaryHook_ = hook;
            address raw_ = other;
            rowTokens[faceIdx] = fullSpread.otherToken();
            face = fullSpread.otherToken();
            _bindWeighted(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "second rate-target product pool");
            assertEq(other, raw_, "currency1 keeps the primary raw companion");
            assertEq(face < other, i == 0, "currency1 face product index before swap");
            _seedWeighted();
            _weightedDirections(other);
        }
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(other));
        if (rowCount == 3) assertLt(uint160(face), uint160(pairRecord.p0()));
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3) _weightedDirections(pairRecord.p0());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureWeighted(false);
        assertGt(uint160(face), uint160(other));
        if (rowCount == 3) assertGt(uint160(face), uint160(pairRecord.p0()));
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3) _weightedDirections(pairRecord.p0());
    }

    // Runtime-length, mixed-leg checks replace helpers fixed at two legs.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(weighted.numTokens(), rowCount);
        assertEq(weighted.standardExchange(faceIdx), seUT);
        assertTrue(weighted.isBuffered(faceIdx));
        assertEq(weighted.standardExchange(otherIdx), address(0));
        assertFalse(weighted.isBuffered(otherIdx));
        uint256 sum_;
        for (uint256 i; i < rowCount; ++i) sum_ += rowWeights[i];
        assertEq(sum_, 1e18);
        for (uint256 i; i < rowCount; ++i) {
            assertEq(rowWeights[i], rowCount == 2 || i == faceIdx ? 0.5e18 : 0.25e18, "record keeps its weight");
        }
        _assertAllDoorsLive();
        _seedWeighted();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedWeighted();
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "unbooked donation stays outside caller seed");
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
    }
    // Refunds belong to the calling hook, not a sleeve or the swapper.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedWeighted();
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
        _weightedDirections(other);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedWeighted();
        uint256 in_ = IERC20(other).balanceOf(hook);
        uint256 out_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(other).balanceOf(hook), in_);
        assertEq(IERC20(face).balanceOf(rowEoa), out_);
    }
    // Local-only output needs no unavailable SE operation.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedWeighted();
        _localExactOut(true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedWeighted();
        _localExactOut(false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3) _weightedDirections(pairRecord.p0());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        bool z_ = other < face;
        PoolKey memory key_ = PoolKey(Currency.wrap(z_ ? other : face), Currency.wrap(z_ ? face : other), 0, 1, IHooks(hook));
        SwapParams memory p_ = SwapParams(z_, int256(IERC20(face).balanceOf(hook) + 1), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_, "no face paid");
        assertEq(IERC20(other).balanceOf(user), o_, "no raw paid");
    }
    // A real minimum-output failure replaces dependency injection; previews decode both words.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override {
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3) _weightedDirections(pairRecord.p0());
    }
    function test_row_ammCallerFundSeparation() public override {
        _seedWeighted();
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT, 10 ether);
        IFullSpreadV4MatrixMoney(seUT).exchangeIn(fullSpread.otherToken(), 10 ether, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT).balanceOf(hook), shares_, "other caller cannot consume hook shares");
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
            _bindWeighted(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "separate second-target product pool");
            assertEq(weighted.rateProvider(faceIdx), fullSpread.currency1Provider());
        }
        _seedWeighted();
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
            swapRouter, poolKey01,
            SwapParams(z_, -int256(amount_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public {
        _seedWeighted();
        bool z_ = face < other;
        uint256 preview_ = weighted.previewSwapExactIn(face, other, 1 ether);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey01,
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
