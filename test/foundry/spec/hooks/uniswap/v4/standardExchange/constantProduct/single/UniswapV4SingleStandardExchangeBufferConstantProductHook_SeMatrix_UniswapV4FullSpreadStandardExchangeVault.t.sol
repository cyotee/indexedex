// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FullSpreadV4MatrixChecks} from "../../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

interface IFullSpreadCpTuple {
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
}

/// @notice Constant-product single row. Does not override setUp.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        pm = f.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        return f;
    }

    function test_row_primaryProvider_currency0() public view {
        assertEq(single.rateProvider(face), SeMatrix_FullSpreadV4Fixture(address(fx)).currency0Provider());
    }

    /// @notice Supply pre-acquired SE shares and an unchanged raw-token leg on genesis.
    function _seed() internal override returns (uint256 lp_) {
        address[] memory tokens_ = new address[](2);
        address[] memory ses_ = new address[](2);
        tokens_[0] = face;
        tokens_[1] = raw;
        ses_[0] = seUT;
        FullSpreadV4MatrixChecks.Seed memory seed_ = FullSpreadV4MatrixChecks.prepareSeed(
            SeMatrix_FullSpreadV4Fixture(address(fx)), tokens_, ses_, hook, user, seedUnits * 1 ether
        );
        vm.prank(user);
        (lp_,,) = single.depositWithSeShares(seed_.amounts[1], seed_.amounts[0], user, 1, block.timestamp);
        FullSpreadV4MatrixChecks.assertSeed(seed_, tokens_, ses_, hook, user, lp_);
    }

    function test_row_exactOutAbsent() public {
        assertEq(IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), _f(1)), 0);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(seUT).exchangeOut(
            IERC20(face), _f(1), IERC20(seUT), 0, address(this), false, block.timestamp
        );
    }

    function test_row_rateTarget_currency1() public {
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i; i < 2; ++i) {
            assertTrue(vm.revertToState(snapshot_));
            snapshot_ = vm.snapshotState();
            _bindFaceIndex(i == 0);
            address primaryHook_ = hook;
            address raw_ = raw;
            face = fx.otherToken();
            IPkg.PkgArgs memory args_ = _rowPkgArgs();
            args_.rateProvider = SeMatrix_FullSpreadV4Fixture(address(fx)).currency1Provider();
            _deployRowHook(args_);
            assertNotEq(hook, primaryHook_, "second rate-target product pool");
            assertEq(raw, raw_, "currency1 keeps the primary raw companion");
            fx.fundOther(user, 1_000_000 ether);
            vm.startPrank(user);
            IERC20(face).approve(hook, type(uint256).max);
            IERC20(face).approve(address(swapRouter), type(uint256).max);
            IERC20(raw).approve(hook, type(uint256).max);
            vm.stopPrank();
            assertEq(face < raw, i == 0, "currency1 face product index before swap");
            assertEq(single.rateProvider(face), SeMatrix_FullSpreadV4Fixture(address(fx)).currency1Provider());
            _seed();
            _cpDirections();
        }
    }

    function _cpDirections() internal {
        SeMatrix_FullSpreadV4Fixture f_ = SeMatrix_FullSpreadV4Fixture(address(fx));
        assertTrue(keccak256(abi.encode(poolKey)) != keccak256(abi.encode(f_.key())), "product and backing differ");
        assertEq(single.currency0() == face, face < raw, "face product index before swap");
        assertEq(single.standardExchangeOf(raw), address(0), "raw leg only transfers");
        FullSpreadV4MatrixChecks.preview(f_, face);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 before_ = IERC20(raw).balanceOf(user);
        uint256 quoted_ = single.previewSwapExactIn(face, raw, _f(10));
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face, raw, _f(10));
        FullSpreadV4MatrixChecks.hookRefund(face, seUT, hook, hookFace_);
        assertEq(IERC20(raw).balanceOf(user) - before_, quoted_, "face to raw amountOut parity");
        assertGt(IERC20(seUT).totalSupply(), supply_, "face input mints FullSpread shares");
        supply_ = IERC20(seUT).totalSupply();
        before_ = IERC20(face).balanceOf(user);
        quoted_ = single.previewSwapExactIn(raw, face, 10 ether);
        _swapExactIn(raw, face, 10 ether);
        assertEq(IERC20(face).balanceOf(user) - before_, quoted_, "raw to face amountOut parity");
        assertLt(IERC20(seUT).totalSupply(), supply_, "face output burns FullSpread shares");
    }

    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed();
        FullSpreadV4MatrixChecks.refunds(SeMatrix_FullSpreadV4Fixture(address(fx)), hook, face);
        _cpDirections();
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seed();
        address donor = makeAddr("donor");
        uint256 donation = _f(500);
        fx.fund(donor, donation);
        vm.prank(donor);
        IERC20(face).transfer(hook, donation);
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 seBefore = _hookSeShares();
        (, uint256 usedFace) = _joinBoth(_f(1), 1 ether);
        assertGt(usedFace, 0, "join used face");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "joiner pays used face, not the resting donation");
        assertGt(_hookSeShares(), seBefore, "buffer-first: SE shares owned by the hook");
        uint256 resting = IERC20(face).balanceOf(hook);
        assertGt(resting, 0, "unused input is refunded to the hook");
        assertGe(resting, donation, "ambient donation stays outside the accepted caller basket");
    }

    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _expectHookExactOutReverts(true);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _expectHookExactOutReverts(false);
    }

    function test_localExactOutputPullsOnlyUsed() public {
        super.test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly();
    }

    function test_localExactOutputPretransferRefundsCredit() public {
        super.test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed();
    }

    function test_localPoolManagerExactOutputUsesNoSe() public {
        _seed();
        uint256 localBefore = IERC20(face).balanceOf(hook);
        uint256 supplyBefore = IERC20(seUT).totalSupply();
        uint256 userBefore = IERC20(face).balanceOf(user);
        assertGe(localBefore, _f(1));
        _swapExactOut(raw, face, _f(1));
        assertEq(IERC20(face).balanceOf(user) - userBefore, _f(1));
        assertEq(IERC20(face).balanceOf(hook), localBefore - _f(1));
        assertEq(IERC20(seUT).totalSupply(), supplyBefore, "no unavailable SE inverse call");
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        uint256 uFace = IERC20(face).balanceOf(user);
        uint256 uRaw = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, _f(1));
        assertGt(IERC20(raw).balanceOf(user), uRaw, "exact-in face->raw paid");
        uRaw = IERC20(raw).balanceOf(user);
        uFace = IERC20(face).balanceOf(user);
        _swapExactIn(raw, face, 1 ether);
        assertGt(IERC20(face).balanceOf(user), uFace, "exact-in raw->face paid");
        _expectPoolExactOutReverts(face, raw);
        _expectPoolExactOutReverts(raw, face);
    }

    function test_row_previewMatchesExecution() public override {
        uint256 amount = _f(1);
        (uint256 quoted,) = IFullSpreadCpTuple(seUT).previewExchangeIn(face, amount, seUT);
        fx.fund(address(this), amount);
        IERC20(face).approve(seUT, amount);
        (uint256 got,) = IFullSpreadCpTuple(seUT).exchangeIn(
            face, amount, seUT, 0, address(this), false, block.timestamp
        );
        assertEq(got, quoted, "exact-in amountOut preview == execution");
        assertEq(IERC20(seUT).balanceOf(address(this)), got, "recipient receives amountOut, not refund");
        assertEq(IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), amount), 0);

        _seed();
        (uint256 a0, uint256 a1) = _ordered(_f(10), 10 ether);
        (uint256 pLp, uint256 pUsed0, uint256 pUsed1) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 gotLp, uint256 used0, uint256 used1) =
            single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertEq(used0, pUsed0, "deposit used0 preview == execution");
        assertEq(used1, pUsed1, "deposit used1 preview == execution");
        assertApproxEqRel(gotLp, pLp, 1e12, "deposit LP preview == execution");

        uint256 probe = _f(1);
        uint256 pSwap = single.previewSwapExactIn(face, raw, probe);
        uint256 rawBefore = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, probe);
        assertEq(IERC20(raw).balanceOf(user) - rawBefore, pSwap, "exact-in swap preview == execution");
        _cpDirections();
    }

    function _expectHookExactOutReverts(bool pretransferred) internal {
        _seed();
        SimpleMintableERC20(raw).mint(address(this), 10 ether);
        FullSpreadV4MatrixChecks.hookOut(hook, raw, face, pretransferred);
    }

    function _expectPoolExactOutReverts(address tokenIn, address tokenOut) internal {
        bool zeroForOne = tokenIn < tokenOut;
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256 rawBefore = IERC20(raw).balanceOf(user);
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(tokenOut == face ? IERC20(face).balanceOf(hook) + 1 : _f(1) / 2),
            sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
        });
        vm.expectRevert();
        vm.prank(user);
        swapRouter.swapExactOut(poolKey, params, type(uint256).max, "");
        assertEq(IERC20(face).balanceOf(user), faceBefore, "exact-out pays no face");
        assertEq(IERC20(raw).balanceOf(user), rawBefore, "exact-out pays no raw");
    }

    function test_row_seFailure_rollsBack() public override {
        uint256 amount_ = _f(10);(uint256 quoted_,) = IFullSpreadCpTuple(seUT).previewExchangeIn(face, amount_, seUT);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 vaultFace_ = IERC20(face).balanceOf(seUT);
        fx.fund(address(this), amount_);
        uint256 callerFace_ = IERC20(face).balanceOf(address(this));
        uint256 callerShares_ = IERC20(seUT).balanceOf(address(this));
        uint256 otherFace_ = IERC20(fx.otherToken()).balanceOf(seUT);
        IERC20(face).approve(seUT, amount_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quoted_ + 1, quoted_));IFullSpreadCpTuple(seUT).exchangeIn(face, amount_, seUT, quoted_ + 1, address(this), false, block.timestamp);
        assertEq(IERC20(seUT).totalSupply(), supply_);
        assertEq(IERC20(face).balanceOf(seUT), vaultFace_);
        assertEq(IERC20(face).balanceOf(address(this)), callerFace_, "caller face rolls back");
        assertEq(IERC20(seUT).balanceOf(address(this)), callerShares_, "caller shares roll back");
        assertEq(IERC20(fx.otherToken()).balanceOf(seUT), otherFace_, "other vault face rolls back");
    }

    function test_row_faceProductIndex0() public {
        _bindFaceIndex(true);
        assertLt(uint160(face), uint160(raw), "counter-leg is above the face");
        assertEq(single.currency0(), face, "face is product index 0");
        _seed();
        _cpDirections();
    }

    function test_row_faceProductIndex1() public {
        _bindFaceIndex(false);
        assertGt(uint160(face), uint160(raw), "counter-leg is below the face");
        assertEq(single.currency1(), face, "face is product index 1");
        _seed();
        _cpDirections();
    }

    function _bindFaceIndex(bool rawAboveFace) internal {
        SeMatrix_FullSpreadV4Fixture f_ = SeMatrix_FullSpreadV4Fixture(address(fx));
        raw = f_.rawToken(rawAboveFace, 0);
        IPkg.PkgArgs memory args = _rowPkgArgs();
        args.rateProvider = face == f_.faceToken() ? f_.currency0Provider() : f_.currency1Provider();
        args.rawToken = raw;
        args.rawTokenDecimals = HookPkgArgsDecimalsLib.tokenDec(raw);
        _deployRowHook(args);
        SimpleMintableERC20(raw).mint(user, 1_000_000 ether);
        vm.startPrank(user);
        IERC20(raw).approve(hook, type(uint256).max);
        IERC20(raw).approve(address(swapRouter), type(uint256).max);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

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
            face = fx.otherToken();
            _bindFaceIndex(true);
            assertNotEq(hook, primaryHook_, "separate second-target product pool");
            assertEq(single.rateProvider(face), SeMatrix_FullSpreadV4Fixture(address(fx)).currency1Provider());
            fx.fundOther(user, 1_000_000 ether);
        }
        _seed();
        address tokenIn_ = redeem_ ? raw : face;
        address tokenOut_ = redeem_ ? face : raw;
        uint256 amount_ = redeem_ ? 30 ether : 1 ether;
        uint256 preview_ = single.previewSwapExactIn(tokenIn_, tokenOut_, amount_);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        if (redeem_) assertGt(preview_, IERC20(face).balanceOf(hook), "output requires primary SE redemption");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 before_ = IERC20(tokenOut_).balanceOf(user);
        bool z_ = tokenIn_ < tokenOut_;
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey,
            SwapParams(z_, -int256(amount_), _sqrtLimit(z_)), user, seUT, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public virtual {
        _seed();
        bool z_ = face < raw;
        uint256 preview_ = single.previewSwapExactIn(face, raw, _f(1));
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey,
            SwapParams(z_, -int256(_f(1)), _sqrtLimit(z_)), user, seUT
        );
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }
}

