// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookPairPoolLib.sol";
import {FullSpreadV3MatrixChecks as Checks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadV3MatrixChecks.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × UniswapV3FullSpreadStandardExchangeVault.
/// @dev Run every gold row against production. D69's allowance and current-state quote
///      corrections supersede the former log-only INCOMPATIBLE markers.
contract UniswapV4SingleSEBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }


    /// @dev V3-ACC-10: the hook keeps only this call's actual input refund, beside any resting face.
    function _wrapV3(uint256 amount) internal returns (uint256 shares) {
        (uint256 quote, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), amount, IERC20(seUT));
        uint256 callerFace = _faceOf(user);
        uint256 callerShares = _seOf(user);
        uint256 hookFace = _faceOf(hook);
        uint256 hookShares = _seOf(hook);
        assertEq(buffer.previewWrap(amount), quote, "wrap preview is the SE quote");
        shares = _wrapExactIn(amount);
        assertEq(shares, quote, "wrap output matches preview");
        assertEq(_seOf(user) - callerShares, shares, "caller receives minted shares");
        assertEq(callerFace - _faceOf(user), amount, "router settles only caller input");
        assertEq(_faceOf(hook), hookFace + refund, "unused settled input returns to calling hook");
        assertEq(_seOf(hook), hookShares, "hook keeps no operation-created shares");
    }

    function test_row_partialConsumption_bookedNotRefunded() public override {
        uint256 shares = _wrapV3(_f(1));
        uint256 resting = _seOf(hook);
        (uint256 quote, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), shares, IERC20(face));
        assertEq(refund, 0, "complete exit consumes the share input");
        assertEq(_unwrapExactIn(shares), quote, "exact-input exit receipt parity");
        assertEq(_seOf(hook), resting, "no operation-created share refund");
        (, refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), _f(1), IERC20(seUT));
        assertGt(refund, 0, "one-sided mint returns its unused input");
        _wrapV3(_f(1));
    }

    function test_row_roundingToZeroControl() public { _roundingToZeroControl(); }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        fx.fund(hook, _f(500));
        _wrapV3(_f(1));
        assertEq(_seOf(hook), 0, "resting face mints no shares for hook");
    }

    /// @dev V3-ACC-17: reject exact-output unwrap even with settled contract credit and resting shares.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        fx.fund(address(this), _f(100));
        uint256 shares = Checks.acquireShares(seUT, face, address(this), _f(100));
        uint256 credit = shares / 10;
        IERC20(seUT).transfer(address(rowCaller), credit);
        rowCaller.execute(seUT, abi.encodeCall(IERC20.transfer, (hook, credit)));
        uint256 maximum = shares / 2;
        IERC20(seUT).approve(address(rowCaller), maximum);
        address[] memory tokens = new address[](2);
        tokens[0] = face; tokens[1] = seUT;
        address[] memory accounts = new address[](5);
        accounts[0] = address(this); accounts[1] = address(rowCaller); accounts[2] = hook;
        accounts[3] = address(pm); accounts[4] = address(swapRouter);
        bytes32 before = Checks.custody(tokens, accounts);
        bytes memory data = _exactOutCalldata(false, _f(1), maximum);
        vm.expectRevert();
        rowCaller.consumePull(IERC20(seUT), address(this), address(swapRouter), maximum, data);
        assertEq(Checks.custody(tokens, accounts), before, "unavailable inverse leaves settled credit and resting shares untouched");
        Checks.absentOut(seUT, face);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        Checks.poolOut(swapRouter, poolKey, face, seUT, user);
        Checks.absentOut(seUT, face);
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        uint256 shares = _wrapV3(_f(1));
        uint256 hookShares = _seOf(hook);
        uint256 faceBefore = _faceOf(user);
        uint256 quote = buffer.previewUnwrap(shares / 2);
        assertEq(_unwrapExactIn(shares / 2), quote, "unwrap preview equals execution");
        assertEq(_faceOf(user) - faceBefore, quote, "unwrap pays exact receipt");
        assertEq(_seOf(hook), hookShares, "no share residual");
        Checks.poolOut(swapRouter, poolKey, face, seUT, user);
        Checks.poolOut(swapRouter, poolKey, seUT, face, user);
    }

    function test_row_previewMatchesExecution() public override {
        uint256 shares = _wrapV3(_f(3));
        (uint256 quote,) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), shares, IERC20(face));
        assertEq(buffer.previewUnwrap(shares), quote, "unwrap preview is the SE quote");
        assertEq(_unwrapExactIn(shares), quote, "withdrawal pays its preview");
        Checks.absentOut(seUT, face);
        Checks.poolOut(swapRouter, poolKey, face, seUT, user);
    }

    function test_row_ammCallerFundSeparation() public override {
        _wrapV3(_f(10));
        Checks.callerSeparation(fx, hook, rowBob);
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
        address[] memory vt = IBasicVault(hook).vaultTokens();
        assertEq(vt.length, 2, "vault tokens are the pair");
        assertEq(vt[0], c0, "vault token 0");
        assertEq(vt[1], c1, "vault token 1");
        assertTrue(_registry().isVault(hook), "registered through the package path");
        assertTrue(PairPoolLib.isPoolLive(pm, poolKey), "product pool initialized");
        assertGt(ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(seUT))), IERC20(face), _f(1), IERC20(seUT)), 0, "SE quotes the face"
        );
        assertGt(_wrapV3(_f(1)), 0, "first wrap through the package-deployed hook");
        assertEq(_seOf(hook), 0, "hook holds no operation-created SE shares");
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        uint256 amt = _f(1);
        fx.fund(rowEoa, amt * 2);
        vm.prank(rowEoa);
        IERC20(face).transfer(hook, amt);
        uint256 hookFace = _faceOf(hook);
        uint256 eoaSe = _seOf(rowEoa);
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(rowEoa);
        vm.expectRevert(abi.encodeWithSelector(Proxy.NoTargetFor.selector, IStandardExchangeIn.exchangeIn.selector));ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(IStandardExchangeIn(hook))), IERC20(face), amt, IERC20(seUT), 0, rowEoa, true, deadline);
        assertEq(_faceOf(hook), hookFace, "no state change on reject");
        assertEq(_seOf(rowEoa), eoaSe, "no output on reject");

        vm.prank(rowEoa);
        IERC20(face).approve(address(swapRouter), amt);
        uint256 preview = buffer.previewWrap(amt);
        (, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), amt, IERC20(seUT));
        _swapExactInAs(rowEoa, true, amt);
        assertEq(_seOf(rowEoa) - eoaSe, preview, "output equals the quote of the settled input only");
        assertEq(_faceOf(rowEoa), 0, "EOA paid the settled input; the pretransfer bought nothing");
        assertEq(_faceOf(hook), hookFace + refund, "pretransfer stays separate from settled input refund");
    }

}
