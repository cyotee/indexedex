// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
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
        return f;
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
        uint256 amount = _f(1);
        uint256 refund = 1;
        for (uint256 i; i < 8 && refund != 0; ++i) {
            (, refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, amount, seUT);
            if (refund != 0 && amount > refund) amount -= refund;
        }
        (, refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, amount, seUT);
        assertLt(refund, amount / 100, "one-sided remainder stays a rounding residue, not the input");
        uint256 hookBefore = _faceOf(hook);
        _wrapExactIn(amount);
        assertEq(_faceOf(hook) - hookBefore, refund, "unused input is refunded to the hook, not booked");

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
        _expectExactOutSwapReverts(false);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _expectExactOutSwapReverts(true);
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        uint256 seOut = _wrapExactIn(_f(1));
        assertGt(seOut, 0, "exact-in wrap");
        uint256 faceOut = _unwrapExactIn(seOut / 2);
        assertGt(faceOut, 0, "exact-in unwrap");
        _expectExactOutSwapReverts(true);
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
        (uint256 unwrapQuoted,) = IFullSpreadTuple(seUT).previewExchangeIn(seUT, seOut, face);
        assertEq(buffer.previewUnwrap(seOut), unwrapQuoted, "unwrap preview is the SE quote");
        _unwrapExactIn(seOut);
        _expectExactOutSwapReverts(true);
    }
}
