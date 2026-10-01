// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    TestBase_UniswapV4DualSEBCPHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

/**
 * @title UniswapV4DualSEBCPHook_SeMatrixBehavior
 * @notice D20 / R10.3 row behavior for the dual SE buffer constant-product hook (open item 1 PRD
 *         §6). A concrete row supplies the SE fixture through `_newFixture()`, which is called once
 *         per SE leg (M4): leg 0 (`standardExchange0` / `token0`) is the leg under test for the
 *         single-leg controls, leg 1 (`standardExchange1` / `token1`) binds a second instance of the
 *         same family. The hook is redeployed through its real package, registry and hook factory
 *         (`DualFactory.findMineNonce` + `deployHook`, then the staged product door and
 *         `_bindProductPoolKey`) with both fixture face tokens and both fixture SEs (M3).
 */
abstract contract UniswapV4DualSEBCPHook_SeMatrixBehavior is TestBase_UniswapV4DualSEBCPHook {
    /// @dev Leg 0 fixture: the leg under test.
    SeMatrixFixture internal fx;
    /// @dev Leg 1 fixture: second instance of the same family (M4).
    SeMatrixFixture internal fx1;
    address internal face;
    address internal other;
    address internal seUT;
    address internal seUT1;
    /// @dev True when `face` is the pool's currency0.
    bool internal faceIsC0;
    WrapperExactOutRouter internal swapRouter;
    AtomicPretransferCaller internal rowCaller;
    address internal rowEoa;
    address internal rowBob;
    /// @dev Cached so helpers never make an external call between a `vm.prank` and its target.
    uint8 internal faceDec;
    uint8 internal otherDec;
    bytes internal rejectBytes;

    function _newFixture() internal virtual returns (SeMatrixFixture);

    /// @dev Face residual the PoolManager swap row tolerates on a buffered leg: rounding dust (D6).
    ///      Rows for an SE family with a recorded over-delivery finding widen it and say why.
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
        fx = _newFixture();
        fx1 = _newFixture();
        face = fx.faceToken();
        other = fx1.faceToken();
        seUT = fx.se();
        seUT1 = fx1.se();
        faceDec = fx.faceDecimals();
        otherDec = fx1.faceDecimals();
        // A9 / A10: per-leg SE addresses and face decimals for the matrix evidence (parsed from the -vv log).
        emit log_named_address("matrix.se0", seUT);
        emit log_named_uint("matrix.faceDecimals0", faceDec);
        emit log_named_address("matrix.se1", seUT1);
        emit log_named_uint("matrix.faceDecimals1", otherDec);
        rejectBytes = fx.rejectBytes();
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        swapRouter = new WrapperExactOutRouter(pm);

        _deployRowHook();

        fx.fund(user, _f(1_000_000));
        fx1.fund(user, _o(1_000_000));
        vm.startPrank(user);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        IERC20(other).approve(hook, type(uint256).max);
        IERC20(other).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev Package → registry → hook factory, then the S42 product door and the live pool key.
    function _deployRowHook() internal {
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange0: seUT,
                token0: face,
                standardExchange1: seUT1,
                token1: other,
                rateProvider0: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seUT, face), // D60
                rateProvider1: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seUT1, other) // D60
            });
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = DualFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook, face, other);
        dual = IDualHook(hook);
        _bindProductPoolKey();
        faceIsC0 = dual.currency0() == face;
    }

    /* ------------------------------- helpers ------------------------------ */

    function _f(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec));
    }

    function _o(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(otherDec));
    }

    function _mintFor(address token, address to, uint256 amount) internal {
        if (token == face) fx.fund(to, amount);
        else fx1.fund(to, amount);
    }

    /// @dev Map (face, other) amounts onto the pool's (currency0, currency1) order.
    function _c(uint256 faceAmt, uint256 otherAmt) internal view returns (uint256 a0, uint256 a1) {
        if (faceIsC0) {
            a0 = faceAmt;
            a1 = otherAmt;
        } else {
            a0 = otherAmt;
            a1 = faceAmt;
        }
    }

    /// @dev Map (currency0, currency1) results back onto (face, other).
    function _fo(uint256 v0, uint256 v1) internal view returns (uint256 faceV, uint256 otherV) {
        if (faceIsC0) {
            faceV = v0;
            otherV = v1;
        } else {
            faceV = v1;
            otherV = v0;
        }
    }

    function _zfo(address tokenIn) internal view returns (bool) {
        return (tokenIn == face) == faceIsC0;
    }

    function _depositFaces(uint256 faceAmt, uint256 otherAmt)
        internal
        returns (uint256 lp, uint256 usedFace, uint256 usedOther)
    {
        (uint256 a0, uint256 a1) = _c(faceAmt, otherAmt);
        vm.prank(user);
        (uint256 lpOut, uint256 u0, uint256 u1) = dual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        lp = lpOut;
        (usedFace, usedOther) = _fo(u0, u1);
    }

    function _seed() internal returns (uint256 lp) {
        (lp,,) = _depositFaces(_f(100), _o(100));
    }

    function _hookSeShares() internal view returns (uint256) {
        return IERC20(seUT).balanceOf(hook);
    }

    function _previewIn(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        return dual.previewSwapExactIn(_zfo(tokenIn), amountIn);
    }

    function _swapExactIn(address tokenIn, uint256 amountIn) internal {
        bool zeroForOne = _zfo(tokenIn);
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        swapRouter.swapExactIn(poolKey, params, "");
    }

    function _swapExactOut(address tokenIn, uint256 amountOut) internal {
        bool zeroForOne = _zfo(tokenIn);
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountOut),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        // This router settles the maximum before swapping, then refunds the unused input.
        uint256 maximum = dual.previewSwapExactOut(zeroForOne, amountOut);
        vm.prank(user);
        swapRouter.swapExactOut(poolKey, params, maximum, "");
    }

    /* ------------------------------ §6 rows ------------------------------- */

    function test_row_bind_deploysThroughPackage() public virtual {
        assertEq(dual.standardExchange0(), seUT, "SE bound on leg 0");
        assertEq(dual.token0(), face, "face token on leg 0");
        assertEq(dual.standardExchange1(), seUT1, "SE bound on leg 1 (M4)");
        assertEq(dual.token1(), other, "second face token on leg 1");
        assertEq(dual.standardExchangeOf(face), seUT, "leg view resolves leg 0 SE");
        assertEq(dual.standardExchangeOf(other), seUT1, "leg view resolves leg 1 SE");
        _assertVaultRegistered();
        assertGt(
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), _f(1), IERC20(seUT)), 0, "SE 0 quotes the face"
        );
        assertGt(
            IStandardExchangeIn(seUT1).previewExchangeIn(IERC20(other), _o(1), IERC20(seUT1)),
            0,
            "SE 1 quotes the second face"
        );
        assertGt(_seed(), 0, "first mint through the package-deployed hook");
        assertTrue(dual.isLive(), "product live once both claim supplies exist (first deposit)");
        assertGt(_hookSeShares(), 0, "hook holds leg 0 SE shares after buffering");
        assertGt(IERC20(seUT1).balanceOf(hook), 0, "hook holds leg 1 SE shares after buffering");
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
        (, uint256 usedFace,) = _depositFaces(_f(1), _o(1));
        assertGt(usedFace, 0, "deposit used face");
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
        (, uint256 usedFace,) = _depositFaces(_f(50), _o(50));
        assertGt(usedFace, allow, "deposit used more face than the dependency could take");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "no refund of the unconsumed part");
        uint256 booked = fx.seBooked() - bookedBefore;
        assertGe(booked, usedFace - allow, "SE booked the remainder above capacity");
        assertLe(booked, usedFace, "booked remainder never exceeds what was used");
        assertGt(_hookSeShares(), seBefore, "hook still receives SE shares for the booked input");
        fx.openCapacity();
        uint256 bookedAfter = fx.seBooked();
        _depositFaces(_f(1), _o(1));
        if (fx.sweepsOnNextInvest()) {
            assertLt(fx.seBooked(), bookedAfter, "next investing operation sweeps the booked remainder");
        } else {
            assertGe(fx.seBooked(), bookedAfter, "sleeve-only family: booked credit is retained, never refunded");
        }
    }

    /// @dev Families with no leftover case: a dust single-token deposit that rounds to zero SE
    ///      output is either rejected with no state change or retained by the hook; it is never
    ///      refunded.
    function _roundingToZeroControl() internal {
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 hookFace = IERC20(face).balanceOf(hook);
        vm.prank(user);
        try dual.depositSingle(face, 1, user, 0, block.timestamp + 1 hours) returns (uint256) {
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
        uint256 amountIn = _o(1);
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
        uint256 restingFace = IERC20(face).balanceOf(hook);
        uint256 restingOther = IERC20(other).balanceOf(hook);
        uint256 uFace = IERC20(face).balanceOf(user);
        uint256 uOther = IERC20(other).balanceOf(user);

        _swapExactIn(face, _f(1));
        assertGt(IERC20(other).balanceOf(user), uOther, "exact-in face->other paid");
        uOther = IERC20(other).balanceOf(user);
        uFace = IERC20(face).balanceOf(user);

        _swapExactIn(other, _o(1));
        assertGt(IERC20(face).balanceOf(user), uFace, "exact-in other->face paid");
        uFace = IERC20(face).balanceOf(user);
        uOther = IERC20(other).balanceOf(user);

        uint256 quoteOut = _previewIn(face, _f(1));
        _swapExactOut(face, quoteOut / 2);
        assertEq(IERC20(other).balanceOf(user) - uOther, quoteOut / 2, "exact-out face->other delivers the request");
        uFace = IERC20(face).balanceOf(user);
        uOther = IERC20(other).balanceOf(user);

        _swapExactOut(other, _f(1) / 2);
        assertEq(IERC20(face).balanceOf(user) - uFace, _f(1) / 2, "exact-out other->face delivers the request");

        assertApproxEqAbs(IERC20(face).balanceOf(hook), restingFace, _residualTolerance(), "no operation-created face residual on leg 0");
        assertApproxEqAbs(IERC20(other).balanceOf(hook), restingOther, _residualTolerance(), "no operation-created face residual on leg 1");
    }

    /// @dev Balances, books and supply captured around the failed operation (struct keeps the row
    ///      body under the stack limit without `via_ir`).
    struct RollbackSnap {
        uint256 userFace;
        uint256 userOther;
        uint256 seShares0;
        uint256 seShares1;
        uint256 booked;
        uint256 supply;
    }

    function _snapRollback() internal view returns (RollbackSnap memory s) {
        s.userFace = IERC20(face).balanceOf(user);
        s.userOther = IERC20(other).balanceOf(user);
        s.seShares0 = _hookSeShares();
        s.seShares1 = IERC20(seUT1).balanceOf(hook);
        s.booked = fx.seBooked();
        s.supply = IERC20(hook).totalSupply();
    }

    function test_row_seFailure_rollsBack() public virtual {
        _seed();
        if (!fx.operativeRevertReachable()) {
            _seFailureNotReachableControl();
            return;
        }
        fx.armOperativeRevert();
        RollbackSnap memory s = _snapRollback();
        (uint256 a0, uint256 a1) = _c(_f(10), _o(10));
        bytes memory expected = rejectBytes;
        vm.prank(user);
        vm.expectRevert(expected);
        dual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        RollbackSnap memory post = _snapRollback();
        assertEq(post.userFace, s.userFace, "face untouched");
        assertEq(post.userOther, s.userOther, "other untouched");
        assertEq(post.seShares0, s.seShares0, "leg 0 SE shares untouched");
        assertEq(post.seShares1, s.seShares1, "leg 1 SE shares untouched");
        assertEq(post.booked, s.booked, "SE books untouched");
        assertEq(post.supply, s.supply, "no LP minted");
        fx.disarmOperativeRevert();
        (uint256 lp,,) = _depositFaces(_f(10), _o(10));
        assertGt(lp, 0, "positive control after the dependency recovers");
    }

    /// @dev Families whose buffering route makes no dependency call (Lido: WETH→SE credits the
    ///      sleeve only): there is no operative failure to inject on this route, so the control is
    ///      that buffering completes and the SE's local book grows by the buffered input.
    function _seFailureNotReachableControl() internal {
        uint256 bookedBefore = fx.seBooked();
        (uint256 lp,,) = _depositFaces(_f(10), _o(10));
        assertGt(lp, 0, "buffering completes");
        assertGt(fx.seBooked(), bookedBefore, "buffering credits the SE's local book; no dependency call on this route");
    }

    function test_row_previewMatchesExecution() public virtual {
        uint256 lp = _seed();
        _assertDepositPreview();
        _assertWithdrawPreview(lp / 10);
        _assertSwapPreview();
    }

    function _assertDepositPreview() internal {
        (uint256 a0, uint256 a1) = _c(_f(10), _o(10));
        (uint256 pLp, uint256 pU0, uint256 pU1) = dual.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 gotLp, uint256 u0, uint256 u1) = dual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertEq(gotLp, pLp, "deposit preview == execution");
        assertEq(u0, pU0, "deposit used0 preview == execution");
        assertEq(u1, pU1, "deposit used1 preview == execution");
    }

    function _assertWithdrawPreview(uint256 burn) internal {
        (uint256 p0, uint256 p1) = dual.previewWithdraw(burn);
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256 otherBefore = IERC20(other).balanceOf(user);
        vm.prank(user);
        (uint256 o0, uint256 o1) = dual.withdraw(burn, user, 0, 0, block.timestamp + 1 hours);
        assertEq(o0, p0, "withdraw amount0 preview == execution");
        assertEq(o1, p1, "withdraw amount1 preview == execution");
        (uint256 outFace, uint256 outOther) = _fo(o0, o1);
        assertEq(IERC20(face).balanceOf(user) - faceBefore, outFace, "withdraw delivered the returned face");
        assertEq(IERC20(other).balanceOf(user) - otherBefore, outOther, "withdraw delivered the returned other");
    }

    /// @dev The family's own swap spec (`UniswapV4DualSEBCPHook_Swap.t.sol`) accepts `DUST` on the
    ///      PoolManager route; the same tolerance is used here.
    function _assertSwapPreview() internal {
        uint256 pSwap = _previewIn(face, _f(1));
        assertGt(pSwap, 0, "swap preview nonzero");
        uint256 oBefore = IERC20(other).balanceOf(user);
        _swapExactIn(face, _f(1));
        assertApproxEqAbs(IERC20(other).balanceOf(user) - oBefore, pSwap, DUST, "swap preview == execution");
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
