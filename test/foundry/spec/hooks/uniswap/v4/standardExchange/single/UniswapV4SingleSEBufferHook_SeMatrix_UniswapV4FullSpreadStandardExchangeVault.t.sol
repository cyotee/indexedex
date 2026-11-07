// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeRateProvider} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProvider.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

interface IFullSpreadTuple {
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

/// @notice Single-leg hook row for UniswapV4FullSpreadStandardExchangeVault.
/// @dev Does not override setUp. Exact-out is a revert, not a direction.
contract UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        pm = f.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        return f;
    }

    /// @notice K04: actual registered vault, ordered backing faces, and two external providers.
    function test_row_fixtureProductionBinding() public view {
        SeMatrix_FullSpreadV4Fixture f_ = SeMatrix_FullSpreadV4Fixture(address(fx));
        address[] memory faces_ = IBasicVault(seUT).vaultTokens();
        assertEq(faces_.length, 2);
        assertEq(faces_[0], Currency.unwrap(f_.key().currency0));
        assertEq(faces_[1], Currency.unwrap(f_.key().currency1));
        assertEq(faces_[0], f_.faceToken());
        assertEq(faces_[1], f_.otherToken());
        assertNotEq(faces_[0], seUT, "own share is implicit, not a member pair");
        assertNotEq(faces_[1], seUT, "own share is implicit, not a member pair");
        FullSpreadV4MatrixChecks.membership(seUT, face);
        assertLt(uint160(faces_[0]), uint160(faces_[1]));
        assertEq(address(f_.key().hooks), address(0));
        assertTrue(keccak256(abi.encode(poolKey)) != keccak256(abi.encode(f_.key())), "product and backing keys differ");
        assertEq(address(pm), address(f_.poolManager()));
        assertTrue(_registry().isVault(seUT));
        assertTrue(indexedexManager.isPackage(f_.pkg()));
        assertNotEq(f_.currency0Provider(), f_.currency1Provider());
        for (uint256 i; i < 2; ++i) {
            address provider_ = i == 0 ? f_.currency0Provider() : f_.currency1Provider();
            assertNotEq(provider_, seUT);
            assertGt(provider_.code.length, 0);
            assertEq(address(IStandardExchangeRateProvider(provider_).reserveVault()), seUT);
            assertEq(address(IStandardExchangeRateProvider(provider_).rateTarget()), faces_[i]);
        }
        assertEq(f_.seBooked(), 0);
        assertFalse(f_.hasPartialCase());
    }

    function test_row_exactOutAbsent() public {
        assertEq(
            IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), _f(1)),
            0,
            "direct previewExchangeOut is zero"
        );
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(seUT).exchangeOut(
            IERC20(face), _f(1), IERC20(seUT), 0, address(this), false, block.timestamp
        );
    }

    function test_row_bind_deploysThroughPackage() public override {
        assertEq(address(buffer.poolManager()), address(pm), "PoolManager bound");
        assertEq(buffer.standardExchange(), seUT, "SE bound on the single leg");
        assertEq(buffer.wrapper(), seUT, "SE share token is the SE diamond");
        assertEq(buffer.pairToken(), face, "face token is the pairToken");
        address c0 = buffer.currency0();
        address c1 = buffer.currency1();
        assertTrue(c0 < c1, "currency order");
        assertTrue((c0 == face && c1 == seUT) || (c0 == seUT && c1 == face), "currencies are face/SE");
        assertTrue(_registry().isVault(hook), "registered through the package path");
        (uint256 quoted, uint256 refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, _f(1), seUT);
        assertGt(quoted, 0, "SE quotes the face");
        uint256 hookBefore = _faceOf(hook);
        uint256 seOut = _wrapExactIn(_f(1));
        assertEq(seOut, quoted, "wrap pays the quoted shares");
        assertEq(_faceOf(hook) - hookBefore, refund, "unused input is refunded to the hook");
        assertEq(_seOf(hook), 0, "hook retains no shares");
    }

    function test_row_partialConsumption_bookedNotRefunded() public override {
        uint256 shares_ = _wrapExactIn(_f(1));
        (, uint256 fullRefund_) = IFullSpreadTuple(seUT).previewExchangeIn(seUT, shares_, face);
        assertEq(fullRefund_, 0, "fully consumed exit has no input refund");
        uint256 hookShares_ = _seOf(hook);
        _unwrapExactIn(shares_);
        assertEq(_seOf(hook), hookShares_, "fully consumed input leaves no share refund");
        uint256 amount_ = _f(1);
        (, uint256 refund_) = IFullSpreadTuple(seUT).previewExchangeIn(face, amount_, seUT);
        assertGt(refund_, 0, "one-sided mint cannot consume all input");
        uint256 hookFace_ = _faceOf(hook);
        _wrapExactIn(amount_);
        assertEq(_faceOf(hook) - hookFace_, refund_, "unused input is refunded to the calling hook");
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        uint256 amt = _f(1);
        fx.fund(rowEoa, amt * 2);
        vm.prank(rowEoa);
        IERC20(face).transfer(hook, amt);
        uint256 hookFace = _faceOf(hook);
        uint256 eoaSe = _seOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadTuple(hook).exchangeIn(face, amt, seUT, 0, rowEoa, true, block.timestamp);
        assertEq(_faceOf(hook), hookFace, "rejected direct call does not touch the pretransfer");
        (uint256 quoted, uint256 refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, amt, seUT);
        vm.prank(rowEoa);
        IERC20(face).approve(address(swapRouter), amt);
        _swapExactInAs(rowEoa, true, amt);
        assertEq(_seOf(rowEoa) - eoaSe, quoted, "output is the quote of the settled input");
        assertEq(_faceOf(hook), hookFace + refund, "pretransfer stays; only unused settled input is added");
    }

    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        fx.fund(address(this), 10 ether);
        FullSpreadV4MatrixChecks.hookOut(hook, face, seUT, true);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        fx.fund(address(this), 10 ether);
        FullSpreadV4MatrixChecks.hookOut(hook, face, seUT, false);
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 seOut = _wrapExactIn(_f(1));
        assertGt(seOut, 0, "exact-in wrap");
        assertGt(IERC20(seUT).totalSupply(), supply_, "face direction mints FullSpread shares");
        supply_ = IERC20(seUT).totalSupply();
        uint256 faceOut = _unwrapExactIn(seOut / 2);
        assertGt(faceOut, 0, "exact-in unwrap");
        assertLt(IERC20(seUT).totalSupply(), supply_, "share direction burns FullSpread shares");
        _expectExactOutSwapReverts(true);
        _expectExactOutSwapReverts(false);
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        address donor = makeAddr("donor");
        uint256 donation = _f(500);
        fx.fund(donor, donation);
        vm.prank(donor);
        IERC20(face).transfer(hook, donation);
        (uint256 quoted, uint256 refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, _f(1), seUT);
        uint256 seOut = _wrapExactIn(_f(1));
        assertEq(seOut, quoted, "swapper receives its own quote");
        assertEq(_faceOf(hook), donation + refund, "donation stays; only unused input is added");
        assertEq(_seOf(hook), 0, "no shares minted from the resting face");
    }

    function test_row_ammCallerFundSeparation() public override {
        _wrapExactIn(_f(10));
        uint256 reservedFace = IBasicVault(seUT).reserveOfToken(face);
        address ot = fx.otherToken();
        uint256 amt = 10 ether;
        fx.fundOther(rowBob, amt);
        vm.startPrank(rowBob);
        IERC20(ot).approve(seUT, amt);
        IFullSpreadTuple(seUT).exchangeIn(ot, amt, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        uint256 after_ = IBasicVault(seUT).reserveOfToken(face);
        assertGe(after_, reservedFace, "other-token caller does not reduce the reserved face");
        assertEq(IERC20(face).balanceOf(rowBob), 0, "other-token caller receives no face");
    }

    function _expectExactOutSwapReverts(bool wrap) internal {
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);
        (SwapParams memory p,) = _swapParams(wrap, int256(_f(1)));
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(poolKey, p, type(uint256).max, "");
        assertEq(_faceOf(user), userFace, "exact-out pays no face");
        assertEq(_seOf(user), userSe, "exact-out pays no shares");
    }

    function test_row_seFailure_rollsBack() public override {
        uint256 amount = _f(10);
        (uint256 quoted,) = IFullSpreadTuple(seUT).previewExchangeIn(face, amount, seUT);
        uint256 supply = IERC20(seUT).totalSupply();
        uint256 vaultFace = IERC20(face).balanceOf(seUT);
        uint256 callerFace = IERC20(face).balanceOf(address(this));
        fx.fund(address(this), amount);
        IERC20(face).approve(seUT, amount);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quoted + 1, quoted));
        IFullSpreadTuple(seUT).exchangeIn(face, amount, seUT, quoted + 1, address(this), false, block.timestamp);
        assertEq(IERC20(seUT).totalSupply(), supply, "shares unchanged");
        assertEq(IERC20(face).balanceOf(address(this)), callerFace + amount, "caller face unchanged by the revert");
        assertEq(IERC20(face).balanceOf(seUT), vaultFace, "vault face unchanged");
    }

    function test_row_previewMatchesExecution() public override {
        uint256 x = _f(3);
        (uint256 quoted,) = IFullSpreadTuple(seUT).previewExchangeIn(face, x, seUT);
        assertEq(buffer.previewWrap(x), quoted, "wrap preview is the SE quote");
        uint256 seOut = _wrapExactIn(x);
        assertEq(seOut, quoted, "mint amountOut parity");
        (uint256 unwrapQuoted,) = IFullSpreadTuple(seUT).previewExchangeIn(seUT, seOut, face);
        assertEq(buffer.previewUnwrap(seOut), unwrapQuoted, "unwrap preview is the SE quote");
        assertEq(_unwrapExactIn(seOut), unwrapQuoted, "exit amountOut parity");
        _expectExactOutSwapReverts(true);
    }

    /// @notice Cold unwrap consumes the actual SE share token, not its member face.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency0_redeem() public {
        _composedGas(false, true);
    }

    /// @notice H1 has no provider field; bind the member matching the second provider target.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_mint() public {
        _composedGas(true, false);
    }

    /// @notice Cold unwrap to the second member face must burn primary SE supply.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_redeem() public {
        _composedGas(true, true);
    }

    function _composedGas(bool currency1_, bool redeem_) internal {
        SeMatrix_FullSpreadV4Fixture f_ = SeMatrix_FullSpreadV4Fixture(address(fx));
        if (currency1_) {
            address primaryHook_ = hook;
            face = fx.otherToken();
            pairToken = SimpleMintableERC20(face);
            _deployRowHook(_defaultPkgArgs());
            assertNotEq(hook, primaryHook_, "separate second-member product pool");
            assertEq(buffer.pairToken(), face);
            assertEq(address(IStandardExchangeRateProvider(f_.currency1Provider()).rateTarget()), face);
            fx.fundOther(user, _f(1_000_000));
            vm.startPrank(user);
            IERC20(face).approve(hook, type(uint256).max);
            IERC20(face).approve(address(swapRouter), type(uint256).max);
            vm.stopPrank();
        }
        // Public share acquisition is setup, outside both measured frames.
        uint256 amount_ = redeem_ ? f_.acquireShares(seUT, face, user, _f(1)) : _f(1);
        (SwapParams memory params_,) = _swapParams(!redeem_, -int256(amount_));
        uint256 preview_ = redeem_ ? buffer.previewUnwrap(amount_) : buffer.previewWrap(amount_);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        address tokenOut_ = redeem_ ? face : seUT;
        uint256 before_ = IERC20(tokenOut_).balanceOf(user);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(swapRouter, poolKey, params_, user, seUT, !redeem_);
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public {
        (SwapParams memory params_,) = _swapParams(true, -int256(_f(1)));
        uint256 preview_ = buffer.previewWrap(_f(1));
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(swapRouter, poolKey, params_, user, seUT);
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }
}
