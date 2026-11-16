// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixSibling, FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

/// @notice Two converting FullSpread member faces and one raw leg.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixSibling internal pairRecord;
    uint256 internal beforePair;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public override {
        TestBase_UniswapV4StandardExchangeOrbitalBufferHook.setUp();
        fx0 = _newFixture();
        face0 = fx0.faceToken();
        seUT0 = fx0.se();
        faceDec0 = 18;
        faceDec1 = 18;
        faceDec2 = 18;
        rejectBytes = abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector);
        pm = fullSpread.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        beforePair = vm.snapshotState();
        _configureOrbital(true);
    }

    function _configureOrbital(bool faceAtZero_) internal {
        address placementFace_ = faceAtZero_ ? fullSpread.otherToken() : fullSpread.faceToken();
        pairRecord = FullSpreadV4MatrixChecks.pair(fullSpread, placementFace_, faceAtZero_);
        face1 = pairRecord.p0();
        seUT1 = pairRecord.share();

        face2 = FullSpreadV4MatrixChecks.raw(fullSpread, faceAtZero_, 0);
        seUT2 = address(0);
        _bindOrbital(face0 == fullSpread.faceToken() ? fullSpread.currency0Provider() : fullSpread.currency1Provider());
    }

    function _bindOrbital(address provider_) internal {
        IPackage.PkgArgs memory args_;
        args_.poolManager = address(pm);
        args_.feeOracle = address(indexedexManager);
        args_.token0 = face0;
        args_.token1 = face1;
        args_.token2 = face2;
        args_.decimals0 = 18;
        args_.decimals1 = 18;
        args_.decimals2 = 18;
        args_.se0 = seUT0;
        args_.se1 = seUT1;
        args_.rp0 = provider_;
        args_.rp1 = pairRecord.provider();
        args_.tickSpacing = 60;
        args_.sqrtPriceX96 = uint160(1) << 96;
        args_.owner = owner;
        hookPkg.processArgs(abi.encode(args_));
        _deployRowHook(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        SimpleMintableERC20(face2).mint(user, 1_000_000 ether);
        SimpleMintableERC20(face2).mint(address(this), 1_000_000 ether);
        SimpleMintableERC20(face1).mint(user, 1_000_000 ether);
        vm.startPrank(user);
        IERC20(face0).approve(hook, type(uint256).max);
        IERC20(face1).approve(hook, type(uint256).max);
        IERC20(face2).approve(hook, type(uint256).max);
        IERC20(face0).approve(address(swapRouter), type(uint256).max);
        IERC20(face1).approve(address(swapRouter), type(uint256).max);
        IERC20(face2).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Use installed flexible inputs: two pre-acquired SE shares and one raw leg.
    function _seedMixed() internal {
        address[] memory tokens_ = new address[](3);
        address[] memory ses_ = new address[](3);
        tokens_[0] = face0; tokens_[1] = face1; tokens_[2] = face2;
        ses_[0] = seUT0; ses_[1] = seUT1;
        FullSpreadV4MatrixChecks.Seed memory seed_ = FullSpreadV4MatrixChecks.prepareSeed(
            fullSpread, tokens_, ses_, hook, user, 100 ether
        );
        vm.prank(user);
        (uint256 shares_,,,) = orbital.depositFlexible(
            seed_.amounts[0], true, seed_.amounts[1], true, seed_.amounts[2], false, user, 1, block.timestamp
        );
        FullSpreadV4MatrixChecks.assertSeed(seed_, tokens_, ses_, hook, user, shares_);
    }

    function _directions(address counter_) internal {
        FullSpreadV4MatrixChecks.preview(fullSpread, face0);
        PoolKey memory key_ = counter_ == face1 ? poolKey01 : poolKey02;
        assertEq(address(key_.hooks), hook);
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product key");
        assertEq(address(key_.hooks), hook, "product hook bound");
        assertEq(Currency.unwrap(face0 < counter_ ? key_.currency0 : key_.currency1), face0, "face product index before swap");
        uint256 siblingSupply_ = IERC20(seUT1).totalSupply();
        uint256 output_ = IERC20(counter_).balanceOf(user);
        uint256 quote_ = orbital.previewSwapExactIn(face0, counter_, 10 ether);
        uint256 siblingLocal_ = orbital.rawReserve(1);
        uint256 vaultSupply_ = IERC20(seUT0).totalSupply();
        uint256 hookFace_ = IERC20(face0).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face0, counter_, 10 ether);
        FullSpreadV4MatrixChecks.hookRefund(face0, seUT0, hook, hookFace_);
        assertEq(IERC20(counter_).balanceOf(user) - output_, quote_, "forward amountOut parity");
        assertGt(IERC20(seUT0).totalSupply(), vaultSupply_, "forward transaction mints FullSpread shares");
        assertGt(IERC20(counter_).balanceOf(user), output_, "face exact-input paid");
        if (counter_ == face1) {
            if (quote_ > siblingLocal_) assertLt(IERC20(seUT1).totalSupply(), siblingSupply_, "forward deficit redeems sibling");
            else assertEq(IERC20(seUT1).totalSupply(), siblingSupply_, "local output does not redeem sibling");
        }
        siblingSupply_ = IERC20(seUT1).totalSupply();
        output_ = IERC20(face0).balanceOf(user);
        quote_ = orbital.previewSwapExactIn(counter_, face0, 10 ether);
        uint256 primaryLocal_ = orbital.rawReserve(0);
        vaultSupply_ = IERC20(seUT0).totalSupply();
        _swapExactIn(counter_, face0, 10 ether);
        assertEq(IERC20(face0).balanceOf(user) - output_, quote_, "reverse amountOut parity");
        if (quote_ > primaryLocal_) assertLt(IERC20(seUT0).totalSupply(), vaultSupply_, "reverse deficit burns FullSpread shares");
        else assertEq(IERC20(seUT0).totalSupply(), vaultSupply_, "reverse local payment keeps FullSpread supply");
        assertGt(IERC20(face0).balanceOf(user), output_, "reverse exact-input paid");
        if (counter_ == face1) assertGt(IERC20(seUT1).totalSupply(), siblingSupply_, "reverse mints sibling");
    }

    /// @notice Historical failure name, now a valid second-SE membership/conversion proof.
    function test_row_identity_pairToken() public {
        FullSpreadV4MatrixChecks.membership(seUT1, face1);
        _seedMixed();
        _directions(face1);
    }
    function test_row_rateTarget_currency1() public {
        _currency1Directions(true);
    }

    function test_row_rateTarget_currency1_index1() public {
        _currency1Directions(false);
    }

    function _currency1Directions(bool faceAtZero_) internal {
        assertTrue(vm.revertToState(beforePair));
        _configureOrbital(faceAtZero_);
        address primaryHook_ = hook;
        address raw_ = face2;
        address pairShare_ = pairRecord.share();
        face0 = fullSpread.otherToken();
        _bindOrbital(fullSpread.currency1Provider());
        assertNotEq(hook, primaryHook_, "second rate-target product pool");
        assertEq(face2, raw_, "currency1 keeps the primary raw companion");
        assertEq(pairRecord.share(), pairShare_, "currency1 keeps the primary FullSpread sibling record");
        assertEq(face0 < face2, faceAtZero_, "currency1 face product index before swap");
        assertEq(face0 < face1, faceAtZero_, "currency1 sibling member pair index before swap");
        _seedMixed();
        _directions(face2);
        _directions(face1);
    }
    function test_row_index0() public {
        assertLt(uint160(face0), uint160(face1));
        assertLt(uint160(face0), uint160(face2));
        _seedMixed();
        _directions(face2);
        _directions(face1);
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforePair));
        _configureOrbital(false);
        assertGt(uint160(face0), uint160(face1));
        assertGt(uint160(face0), uint160(face2));
        _seedMixed();
        _directions(face2);
        _directions(face1);
    }
    /// @notice The raw leg transfers; the second FullSpread member leg really converts.
    function test_row_pair12_transferControl() public {
        _seedMixed();
        uint256 siblingSupply_ = IERC20(seUT1).totalSupply();
        uint256 primarySupply_ = IERC20(seUT0).totalSupply();
        uint256 output_ = IERC20(face2).balanceOf(user);
        uint256 quote_ = orbital.previewSwapExactIn(face1, face2, 10 ether);
        _swapExactIn(face1, face2, 10 ether);
        assertEq(IERC20(face2).balanceOf(user) - output_, quote_, "sibling to raw parity");
        assertGt(IERC20(seUT1).totalSupply(), siblingSupply_, "sibling input mints real shares");
        siblingSupply_ = IERC20(seUT1).totalSupply();
        output_ = IERC20(face1).balanceOf(user);
        quote_ = orbital.previewSwapExactIn(face2, face1, 10 ether);
        _swapExactIn(face2, face1, 10 ether);
        assertEq(IERC20(face1).balanceOf(user) - output_, quote_, "raw to sibling parity");
        assertLt(IERC20(seUT1).totalSupply(), siblingSupply_, "sibling deficit redeems real shares");
        assertEq(IERC20(seUT0).totalSupply(), primarySupply_, "unrelated primary leg does not convert");
    }

    // Two SE legs convert; the third leg stays raw.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(orbital.standardExchange(0), seUT0);
        assertEq(orbital.standardExchange(2), address(0));
        assertEq(orbital.rateProvider(0), fullSpread.currency0Provider());
        assertEq(orbital.rateProvider(2), address(0));
        _seedMixed();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face0).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedMixed();
        assertLe(IERC20(face0).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertGe(IERC20(face0).balanceOf(hook), 500 ether, "unconsumed donation stays on the hook");
    }
    // FullSpread refunds unconsumed input to the hook instead of booking a sleeve remainder.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seedMixed();
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face0);
        _directions(face2);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedMixed();
        uint256 in_ = IERC20(face2).balanceOf(hook);
        uint256 out_ = IERC20(face0).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadV4MatrixMoney(hook).exchangeIn(face2, 1 ether, face0, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(face2).balanceOf(hook), in_);
        assertEq(IERC20(face0).balanceOf(rowEoa), out_);
    }
    // Enabled exact-out is negative even when a direct vault preview returns zero.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedMixed();
        _localExactOut(true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedMixed();
        _localExactOut(false);
    }

    function _localExactOut(bool prepaid) private {
        uint256 wanted = orbital.rawReserve(0) / 2;
        assertGt(wanted, 0);
        uint256 needed = IStandardExchangeOut(hook).previewExchangeOut(IERC20(face2), IERC20(face0), wanted);
        uint256 credit = needed * 2;
        uint256 beforeShares = orbital.seBalance(0);
        uint256 beforeLocal = orbital.rawReserve(0);
        if (prepaid) {
            SimpleMintableERC20(face2).mint(address(this), credit);
            IERC20(face2).approve(address(rowCaller), credit);
            uint256 callerInput = IERC20(face2).balanceOf(address(rowCaller));
            uint256 callerOutput = IERC20(face0).balanceOf(address(rowCaller));
            bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (IERC20(face2), credit, IERC20(face0), wanted, address(rowCaller), true, block.timestamp));
            uint256 used = abi.decode(rowCaller.consumePretransfer(IERC20(face2), address(this), hook, credit, data), (uint256));
            assertEq(used, needed);
            assertEq(IERC20(face2).balanceOf(address(rowCaller)) - callerInput, credit - used);
            assertEq(IERC20(face0).balanceOf(address(rowCaller)) - callerOutput, wanted);
        } else {
            uint256 payerInput = IERC20(face2).balanceOf(user);
            uint256 payerOutput = IERC20(face0).balanceOf(user);
            vm.prank(user);
            uint256 used = IStandardExchangeOut(hook).exchangeOut(IERC20(face2), credit, IERC20(face0), wanted, user, false, block.timestamp);
            assertEq(used, needed);
            assertEq(payerInput - IERC20(face2).balanceOf(user), used);
            assertEq(IERC20(face0).balanceOf(user) - payerOutput, wanted);
        }
        assertEq(orbital.seBalance(0), beforeShares);
        assertEq(orbital.rawReserve(0), beforeLocal - wanted);
        vm.expectRevert(bytes4(keccak256("InsufficientTokenOut()")));
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(face2), IERC20(face0), beforeLocal + 1);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedMixed();
        _directions(face2);
        _directions(face1);
        uint256 f_ = IERC20(face0).balanceOf(user);
        uint256 r_ = IERC20(face2).balanceOf(user);
        bool z_ = face2 < face0;
        SwapParams memory p_ = SwapParams(z_, int256(orbital.rawReserve(0) + 1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(poolKey02, p_, 10 ether, "");
        assertEq(IERC20(face0).balanceOf(user), f_);
        assertEq(IERC20(face2).balanceOf(user), r_);
    }
    // Public minimum failure replaces a V3 pool-mint mock.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face0); }
    function test_row_previewMatchesExecution() public override {
        _seedMixed();
        _directions(face2);
        _directions(face1);
    }
    // There is no sleeve; another face depositor cannot take this hook's shares.
    function test_row_ammCallerFundSeparation() public override {
        _seedMixed();
        uint256 shares_ = IERC20(seUT0).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT0, 10 ether);
        IFullSpreadV4MatrixMoney(seUT0).exchangeIn(fullSpread.otherToken(), 10 ether, seUT0, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT0).balanceOf(hook), shares_);
        assertEq(IERC20(face0).balanceOf(rowBob), 0);
    }
    function test_row_exactOutAbsent() public { FullSpreadV4MatrixChecks.absentOut(seUT0, face0); }

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
            face0 = fullSpread.otherToken();
            _bindOrbital(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "separate second-target product pool");
            assertEq(orbital.rateProvider(0), fullSpread.currency1Provider());
        }
        _seedMixed();
        address tokenIn_ = redeem_ ? face2 : face0;
        address tokenOut_ = redeem_ ? face0 : face2;
        uint256 amount_ = redeem_ ? 30 ether : 1 ether;
        uint256 preview_ = orbital.previewSwapExactIn(tokenIn_, tokenOut_, amount_);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        if (redeem_) assertGt(preview_, IERC20(face0).balanceOf(hook), "output requires primary SE redemption");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 before_ = IERC20(tokenOut_).balanceOf(user);
        bool z_ = tokenIn_ < tokenOut_;
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey02,
            SwapParams(z_, -int256(amount_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT0, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public {
        _seedMixed();
        bool z_ = face0 < face2;
        uint256 preview_ = orbital.previewSwapExactIn(face0, face2, 1 ether);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey02,
            SwapParams(z_, -int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT0
        );
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }
}
