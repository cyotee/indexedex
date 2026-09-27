// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
 * @notice D20 / R10.3 row behavior for the curve-quad stable buffer hook (open item 1 PRD §6). A
 *         concrete row supplies the SE fixture through `_newFixture()`, which is called once per
 *         SE leg (M4: four legs, four SE instances of the family under test, each on its own face
 *         token). The hook is redeployed through its real package, registry and hook factory with
 *         the four fixture face tokens sorted ascending and every leg buffered (M3). Leg 0 in
 *         `tokens()` order is the leg under test (`fx`, `face`, `seUT`); leg 1 is `other`.
 */
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior is
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
{
    /// @dev Fixtures in `tokens()` order (ascending face-token address).
    SeMatrixFixture[4] internal fxs;
    /// @dev Leg under test (index `faceIdx`).
    SeMatrixFixture internal fx;
    address internal face;
    address internal other;
    address internal seUT;
    uint256 internal faceIdx;
    uint256 internal otherIdx;
    AtomicPretransferCaller internal rowCaller;
    address internal rowEoa;
    address internal rowBob;
    /// @dev Cached so helpers never make an external call between a `vm.prank` and its target.
    uint8[4] internal legDec;
    uint8 internal faceDec;
    bytes internal rejectBytes;

    function _newFixture() internal virtual returns (SeMatrixFixture);

    /// @dev Face residual the PoolManager swap row tolerates on a buffered leg: rounding dust (D6).
    function _residualTolerance() internal view virtual returns (uint256) {
        return 10;
    }

    function _ctx() internal view returns (SeMatrixFixture.Ctx memory) {
        return SeMatrixFixture.Ctx({
            create3Factory: create3Factory,
            indexedexManager: IIndexedexManagerProxy(address(indexedexManager)),
            owner: owner,
            permit2: permit2,
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
        });
    }

    function setUp() public virtual override {
        super.setUp();
        _createFixtures();
        _bindRowHandles();
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");

        _deployHookWithArgs(_rowPkgArgs());
        _setUsageFee(0);
        _setDexFee(0);

        for (uint256 i; i < 4; ++i) {
            fxs[i].fund(user, _legUnits(i, 1_000_000));
            address t = fxs[i].faceToken();
            vm.startPrank(user);
            IERC20(t).approve(hook, type(uint256).max);
            IERC20(t).approve(address(swapRouter), type(uint256).max);
            vm.stopPrank();
        }
    }

    /* ------------------------------- setup ------------------------------- */

    /// @dev One fixture per SE leg (M4), sorted ascending by face token so the package accepts
    ///      the token order (`TokensNotAscending`).
    function _createFixtures() internal {
        SeMatrixFixture[4] memory raw;
        for (uint256 i; i < 4; ++i) {
            raw[i] = _newFixture();
        }
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (raw[j].faceToken() < raw[i].faceToken()) {
                    (raw[i], raw[j]) = (raw[j], raw[i]);
                }
            }
        }
        for (uint256 i; i < 4; ++i) {
            fxs[i] = raw[i];
            legDec[i] = raw[i].faceDecimals();
        }
    }

    function _bindRowHandles() internal {
        faceIdx = 0;
        otherIdx = 1;
        fx = fxs[faceIdx];
        face = fx.faceToken();
        seUT = fx.se();
        faceDec = legDec[faceIdx];
        // A9 / A10: per-leg SE address and face decimals for the matrix evidence (parsed from the -vv log).
        emit log_named_address("matrix.se0", seUT);
        emit log_named_uint("matrix.faceDecimals0", faceDec);
        rejectBytes = fx.rejectBytes();
        other = fxs[otherIdx].faceToken();
    }

    function _rowPkgArgs()
        internal
        
        returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory)
    {
        address[4] memory toks;
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            toks[i] = fxs[i].faceToken();
            ses[i] = fxs[i].se();
        }
        // D60: every buffered leg carries a StandardExchangeRateProvider quoting one share into the face token.
        rps = RateProviderFixtureLib.providersFor4(create3Factory, diamondPackageFactory, toks, ses);
        return _pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP);
    }

    /* ------------------------------- helpers ------------------------------ */

    function _legUnits(uint256 leg, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(legDec[leg]));
    }

    function _f(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec));
    }

    function _fixtureOf(address token) internal view returns (SeMatrixFixture) {
        for (uint256 i; i < 4; ++i) {
            if (fxs[i].faceToken() == token) return fxs[i];
        }
        revert("SeMatrix: token is not a leg face");
    }

    function _mintFor(address token, address to, uint256 amount) internal {
        _fixtureOf(token).fund(to, amount);
    }

    /// @dev Amounts in `tokens()` order: `faceAmt` raw units on the leg under test, `otherHuman`
    ///      whole units (scaled per leg) on the other three legs.
    function _amounts(uint256 faceAmt, uint256 otherHuman) internal view returns (uint256[] memory a) {
        a = new uint256[](4);
        for (uint256 i; i < 4; ++i) {
            a[i] = i == faceIdx ? faceAmt : _legUnits(i, otherHuman);
        }
    }

    function _joinAll(uint256 faceAmt, uint256 otherHuman) internal returns (uint256 shares, uint256 usedFace) {
        uint256[] memory used;
        vm.prank(user);
        (shares, used) = quad.joinProportional(_amounts(faceAmt, otherHuman), user, 0, block.timestamp + 1 hours);
        usedFace = used[faceIdx];
    }

    function _seed() internal returns (uint256 shares) {
        (shares,) = _joinAll(_f(100), 100);
    }

    function _hookSeShares() internal view returns (uint256) {
        return IERC20(seUT).balanceOf(hook);
    }

    function _hookSeSharesOf(uint256 leg) internal view returns (uint256) {
        return IERC20(fxs[leg].se()).balanceOf(hook);
    }

    /* ------------------------------ §6 rows ------------------------------- */

    function test_row_bind_deploysThroughPackage() public virtual {
        for (uint256 i; i < 4; ++i) {
            address se_ = fxs[i].se();
            address t = fxs[i].faceToken();
            assertEq(quad.standardExchange(i), se_, "SE bound on the leg");
            assertTrue(quad.isBuffered(i), "leg is buffered");
            assertEq(quad.token(i), t, "face token on the leg");
            assertGt(
                IStandardExchangeIn(se_).previewExchangeIn(IERC20(t), _legUnits(i, 1), IERC20(se_)),
                0,
                "SE quotes the face"
            );
        }
        assertEq(quad.standardExchange(faceIdx), seUT, "leg under test bound to fx.se()");
        _assertAllDoorsLive();
        assertGt(_seed(), 0, "first mint through the package-deployed hook");
        for (uint256 i; i < 4; ++i) {
            assertGt(_hookSeSharesOf(i), 0, "hook holds SE shares on every leg after buffering");
        }
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public virtual {
        _seed();
        address donor = makeAddr("donor");
        uint256 donation = _f(500);
        fx.fund(donor, donation);
        vm.prank(donor);
        IERC20(face).transfer(hook, donation);
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 seBefore = _hookSeShares();
        (, uint256 usedFace) = _joinAll(_f(1), 1);
        assertGt(usedFace, 0, "join used face");
        assertEq(
            userFace - IERC20(face).balanceOf(user),
            usedFace,
            "joiner pays used face; resting face is not the joiner's refund"
        );
        assertGt(_hookSeShares(), seBefore, "buffer-first: SE shares owned by the hook");
    }

    function test_row_partialConsumption_bookedNotRefunded() public virtual {
        _seed();
        if (!fx.hasPartialCase()) {
            _roundingToZeroControl();
            return;
        }
        uint256 allow = _f(10);
        fx.limitCapacity(allow);
        uint256 bookedBefore = fx.seBooked();
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 seBefore = _hookSeShares();
        (, uint256 usedFace) = _joinAll(_f(50), 50);
        assertGt(usedFace, allow, "join used more face than the dependency could take");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "no refund of the unconsumed part");
        uint256 booked = fx.seBooked() - bookedBefore;
        assertGe(booked, usedFace - allow, "SE booked the remainder above capacity");
        assertLe(booked, usedFace, "booked remainder never exceeds what was used");
        assertGt(_hookSeShares(), seBefore, "hook still receives SE shares for the booked input");
        fx.openCapacity();
        uint256 bookedAfter = fx.seBooked();
        _joinAll(_f(1), 1);
        if (fx.sweepsOnNextInvest()) {
            assertLt(fx.seBooked(), bookedAfter, "next investing operation sweeps the booked remainder");
        } else {
            assertGe(fx.seBooked(), bookedAfter, "sleeve-only family: booked credit is retained, never refunded");
        }
    }

    /// @dev Families with no leftover case: a dust deposit that rounds to zero SE output is either
    ///      rejected with no state change or retained by the hook; it is never refunded.
    function _roundingToZeroControl() internal {
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 hookFace = IERC20(face).balanceOf(hook);
        vm.prank(user);
        try quad.depositSingle(face, 1, user, 0, block.timestamp + 1 hours) returns (uint256) {
            assertEq(userFace - IERC20(face).balanceOf(user), 1, "dust taken, not refunded");
        } catch {
            assertEq(IERC20(face).balanceOf(user), userFace, "rejected dust leaves the caller untouched");
            assertEq(IERC20(face).balanceOf(hook), hookFace, "rejected dust leaves the hook untouched");
        }
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public virtual {
        _seed();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 amountIn = _legUnits(otherIdx, 1);
        _mintFor(other, rowEoa, amountIn);
        vm.prank(rowEoa);
        tin.transfer(hook, amountIn);
        uint256 hookInBefore = tin.balanceOf(hook);
        uint256 outBefore = tout.balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeIn(hook).exchangeIn(tin, amountIn, tout, 0, rowEoa, true, block.timestamp + 1 hours);
        assertEq(tin.balanceOf(hook), hookInBefore, "no state change on reject");
        assertEq(tout.balanceOf(rowEoa), outBefore, "no output on reject");
    }

    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public virtual {
        _seed();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 wantOut = _f(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(needIn, 0);
        uint256 fatMax = needIn * 3;
        _mintFor(other, address(this), fatMax);
        tin.approve(address(rowCaller), fatMax);
        uint256 callerOutBefore = tout.balanceOf(address(rowCaller));
        uint256 seBefore = _hookSeShares();
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (tin, fatMax, tout, wantOut, address(rowCaller), true, block.timestamp + 1 hours)
        );
        uint256 used = abi.decode(rowCaller.consumePretransfer(tin, address(this), hook, fatMax, data), (uint256));
        assertGt(used, 0);
        assertLe(used, fatMax, "used within the bounded credit");
        assertEq(tout.balanceOf(address(rowCaller)) - callerOutBefore, wantOut, "exact output delivered");
        assertEq(tin.balanceOf(address(rowCaller)), fatMax - used, "refund is credit - used");
        assertEq(tin.balanceOf(address(this)), 0, "payer spent fatMax");
        assertLt(_hookSeShares(), seBefore, "SE shares burned only for the delivered face");
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public virtual {
        _seed();
        IERC20 tin = IERC20(other);
        IERC20 tout = IERC20(face);
        uint256 wantOut = _f(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        uint256 fatMax = needIn * 3;
        _mintFor(other, user, fatMax);
        vm.startPrank(user);
        tin.approve(hook, fatMax);
        uint256 outBefore = tout.balanceOf(user);
        uint256 inBefore = tin.balanceOf(user);
        uint256 used =
            IStandardExchangeOut(hook).exchangeOut(tin, fatMax, tout, wantOut, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(used, needIn, "pulls quoted used");
        assertEq(inBefore - tin.balanceOf(user), needIn, "only used pulled");
        assertEq(tout.balanceOf(user) - outBefore, wantOut, "exact output");
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public virtual {
        _seed();
        uint256[4] memory resting;
        for (uint256 i; i < 4; ++i) {
            resting[i] = IERC20(fxs[i].faceToken()).balanceOf(hook);
        }
        uint256 uFace = IERC20(face).balanceOf(user);
        uint256 uOther = IERC20(other).balanceOf(user);

        _swapExactIn(face, other, _f(1));
        assertGt(IERC20(other).balanceOf(user), uOther, "exact-in face->other paid");
        uOther = IERC20(other).balanceOf(user);
        uFace = IERC20(face).balanceOf(user);

        _swapExactIn(other, face, _legUnits(otherIdx, 1));
        assertGt(IERC20(face).balanceOf(user), uFace, "exact-in other->face paid");
        uFace = IERC20(face).balanceOf(user);
        uOther = IERC20(other).balanceOf(user);

        uint256 quoteOut = quad.previewSwapExactIn(face, other, _f(1));
        _swapExactOut(face, other, quoteOut / 2);
        assertEq(IERC20(other).balanceOf(user) - uOther, quoteOut / 2, "exact-out face->other delivers the request");
        uFace = IERC20(face).balanceOf(user);

        _swapExactOut(other, face, _f(1) / 2);
        assertEq(IERC20(face).balanceOf(user) - uFace, _f(1) / 2, "exact-out other->face delivers the request");

        for (uint256 i; i < 4; ++i) {
            assertApproxEqAbs(
                IERC20(fxs[i].faceToken()).balanceOf(hook),
                resting[i],
                _residualTolerance(),
                "no operation-created face residual on a buffered leg (rounding dust retained, D6)"
            );
        }
    }

    function test_row_seFailure_rollsBack() public virtual {
        _seed();
        if (!fx.operativeRevertReachable()) {
            _seFailureNotReachableControl();
            return;
        }
        fx.armOperativeRevert();
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 userOther = IERC20(other).balanceOf(user);
        uint256 seShares = _hookSeShares();
        uint256 booked = fx.seBooked();
        uint256 supply = IERC20(hook).totalSupply();
        uint256[] memory amounts = _amounts(_f(10), 10);
        bytes memory expected = rejectBytes;
        vm.prank(user);
        vm.expectRevert(expected);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(IERC20(face).balanceOf(user), userFace, "face untouched");
        assertEq(IERC20(other).balanceOf(user), userOther, "other untouched");
        assertEq(_hookSeShares(), seShares, "SE shares untouched");
        assertEq(fx.seBooked(), booked, "SE books untouched");
        assertEq(IERC20(hook).totalSupply(), supply, "no LP minted");
        fx.disarmOperativeRevert();
        (uint256 shares,) = _joinAll(_f(10), 10);
        assertGt(shares, 0, "positive control after the dependency recovers");
    }

    /// @dev Families whose buffering route makes no dependency call (Lido: WETH→SE credits the
    ///      sleeve only): there is no operative failure to inject on this route, so the control is
    ///      that buffering completes and the SE's local book grows by the buffered input.
    function _seFailureNotReachableControl() internal {
        uint256 bookedBefore = fx.seBooked();
        (uint256 shares,) = _joinAll(_f(10), 10);
        assertGt(shares, 0, "buffering completes");
        assertGt(fx.seBooked(), bookedBefore, "buffering credits the SE's local book; no dependency call on this route");
    }

    function test_row_previewMatchesExecution() public virtual {
        uint256 shares = _seed();
        _assertJoinUnbalancedPreview();
        _assertDepositSinglePreview();
        _assertWithdrawSinglePreview(shares / 10);
        _assertSwapPreview();
    }

    function _assertJoinUnbalancedPreview() internal {
        uint256[] memory amounts = _amounts(_f(10), 3);
        uint256 pShares = quad.previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 gotShares = quad.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(gotShares, pShares, "joinUnbalanced preview == execution");
        assertGt(gotShares, 0, "joinUnbalanced minted");
    }

    function _assertDepositSinglePreview() internal {
        uint256 amountIn = _f(5);
        uint256 pShares = quad.previewDepositSingle(face, amountIn);
        vm.prank(user);
        uint256 gotShares = quad.depositSingle(face, amountIn, user, 0, block.timestamp + 1 hours);
        assertEq(gotShares, pShares, "depositSingle preview == execution");
    }

    function _assertWithdrawSinglePreview(uint256 burn) internal {
        uint256 pOut = quad.previewWithdrawSingle(face, burn);
        uint256 before = IERC20(face).balanceOf(user);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(face, burn, user, 0, block.timestamp + 1 hours);
        assertEq(out, pOut, "withdrawSingle preview == execution");
        assertEq(IERC20(face).balanceOf(user) - before, out, "withdraw delivered the returned amount");
    }

    function _assertSwapPreview() internal {
        uint256 pSwap = quad.previewSwapExactIn(face, other, _f(1));
        uint256 oBefore = IERC20(other).balanceOf(user);
        _swapExactIn(face, other, _f(1));
        assertEq(IERC20(other).balanceOf(user) - oBefore, pSwap, "swap preview == execution");
    }

    function test_row_ammCallerFundSeparation() public virtual {
        if (!fx.isAmm()) {
            emit log("not an AMM family: D33 fund-separation control not applicable");
            return;
        }
        _seed();
        uint256 reservedFace = IBasicVault(seUT).reserveOfToken(face);
        address ot = fx.otherToken();
        uint256 amt = 10 * (10 ** uint256(IERC20Metadata_decimals(ot)));
        fx.fundOther(rowBob, amt);
        vm.startPrank(rowBob);
        IERC20(ot).approve(seUT, amt);
        IStandardExchangeIn(seUT).exchangeIn(IERC20(ot), amt, IERC20(seUT), 0, rowBob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(
            IBasicVault(seUT).reserveOfToken(face), reservedFace, "reserved face leftover unchanged by an other-token caller"
        );
    }

    function IERC20Metadata_decimals(address token) internal view returns (uint8 d) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok && ret.length == 32, "decimals");
        d = abi.decode(ret, (uint8));
    }
}
