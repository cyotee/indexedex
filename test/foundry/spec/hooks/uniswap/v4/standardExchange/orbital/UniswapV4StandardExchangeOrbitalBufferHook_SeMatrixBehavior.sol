// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
 * @notice D20 / R10.3 row behavior for the orbital buffer hook (open item 1 PRD §6). A concrete
 *         row supplies the SE fixture through `_newFixture()`, which is called once per SE leg
 *         (M4: three legs, three fixture instances, three SEs of the family under test). The hook
 *         is redeployed through its real package, registry and hook factory with each fixture's
 *         face token on its leg and that fixture's SE bound to the leg (M3). Every leg is buffered.
 * @dev Hook-swap rows use `tokenIn = face1` (leg 1) and `tokenOut = face0` (leg 0). The
 *      "non-identity buffered leg" residual assertion is on the face token of the leg being
 *      swapped into. The base's `_swapExactIn` / `_swapExactOut` helpers build the pool key from
 *      `hook` and spacing 60 through `_poolKeyFor`, so they work unchanged on the fixture faces.
 */
abstract contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    SeMatrixFixture internal fx0;
    SeMatrixFixture internal fx1;
    SeMatrixFixture internal fx2;
    address internal face0;
    address internal face1;
    address internal face2;
    address internal seUT0;
    address internal seUT1;
    address internal seUT2;
    AtomicPretransferCaller internal rowCaller;
    address internal rowEoa;
    address internal rowBob;
    /// @dev Cached so helpers never make an external call between a `vm.prank` and its target.
    uint8 internal faceDec0;
    uint8 internal faceDec1;
    uint8 internal faceDec2;
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
        fx0 = _newFixture();
        fx1 = _newFixture();
        fx2 = _newFixture();
        face0 = fx0.faceToken();
        face1 = fx1.faceToken();
        face2 = fx2.faceToken();
        seUT0 = fx0.se();
        seUT1 = fx1.se();
        seUT2 = fx2.se();
        faceDec0 = fx0.faceDecimals();
        faceDec1 = fx1.faceDecimals();
        faceDec2 = fx2.faceDecimals();
        // A9 / A10: per-leg SE addresses and face decimals for the matrix evidence (parsed from the -vv log).
        emit log_named_address("matrix.se0", seUT0);
        emit log_named_uint("matrix.faceDecimals0", faceDec0);
        emit log_named_address("matrix.se1", seUT1);
        emit log_named_uint("matrix.faceDecimals1", faceDec1);
        emit log_named_address("matrix.se2", seUT2);
        emit log_named_uint("matrix.faceDecimals2", faceDec2);
        rejectBytes = fx0.rejectBytes();
        require(face0 != face1 && face1 != face2 && face0 != face2, "matrix faces distinct");
        require(seUT0 != seUT1 && seUT1 != seUT2 && seUT0 != seUT2, "matrix SEs distinct");
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");

        _deployRowHook(_rowPkgArgs());
        _setUsageFee(0);
        _setDexFee(0);

        fx0.fund(user, _f0(1_000_000));
        fx1.fund(user, _f1(1_000_000));
        fx2.fund(user, _f2(1_000_000));
        vm.startPrank(user);
        IERC20(face0).approve(hook, type(uint256).max);
        IERC20(face1).approve(hook, type(uint256).max);
        IERC20(face2).approve(hook, type(uint256).max);
        IERC20(face0).approve(address(swapRouter), type(uint256).max);
        IERC20(face1).approve(address(swapRouter), type(uint256).max);
        IERC20(face2).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /* ----------------------------- deployment ----------------------------- */

    /// @dev Three-leg PkgArgs: each fixture's face on its leg, that fixture's SE bound to the leg.
    function _rowPkgArgs()
        internal
        
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory a)
    {
        a = _defaultPkgArgs();
        a.token0 = face0;
        a.token1 = face1;
        a.token2 = face2;
        a.decimals0 = faceDec0;
        a.decimals1 = faceDec1;
        a.decimals2 = faceDec2;
        a.se0 = seUT0;
        a.se1 = seUT1;
        a.se2 = seUT2;
        // D60: every buffered leg carries a StandardExchangeRateProvider quoting one share into the face token.
        a.rp0 = RateProviderFixtureLib.providerFor(create3Factory, diamondPackageFactory, seUT0, face0);
        a.rp1 = RateProviderFixtureLib.providerFor(create3Factory, diamondPackageFactory, seUT1, face1);
        a.rp2 = RateProviderFixtureLib.providerFor(create3Factory, diamondPackageFactory, seUT2, face2);
    }

    /// @dev Family inline deploy pattern (TestBase `_deployHookWithArgs` binds doors on the base
    ///      tokens, so the row opens the three product doors on the fixture faces instead).
    function _deployRowHook(IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args) internal {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook, face0, face1, face2);
        orbital = IUniswapV4StandardExchangeOrbitalBufferHook(hook);
        int24 spacing = 60;
        poolKey01 = PairPoolLib.pairKey(face0, face1, spacing, IHooks(hook));
        poolKey12 = PairPoolLib.pairKey(face1, face2, spacing, IHooks(hook));
        poolKey02 = PairPoolLib.pairKey(face0, face2, spacing, IHooks(hook));
    }

    /* ------------------------------- helpers ------------------------------ */

    function _f0(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec0));
    }

    function _f1(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec1));
    }

    function _f2(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec2));
    }

    function _mintFor(address token, address to, uint256 amount) internal {
        if (token == face0) fx0.fund(to, amount);
        else if (token == face1) fx1.fund(to, amount);
        else if (token == face2) fx2.fund(to, amount);
        else revert("not a matrix face");
    }

    /// @dev `addLiquidity` on all three legs as `user`; returns shares and the used face0.
    function _addAll(uint256 a0, uint256 a1, uint256 a2) internal returns (uint256 shares, uint256 used0) {
        (shares, used0,,) = _addLiquidity(a0, a1, a2);
    }

    function _seed() internal returns (uint256 shares) {
        (shares,) = _addAll(_f0(100), _f1(100), _f2(100));
    }

    function _hookSeShares(uint8 leg) internal view returns (uint256) {
        address se = leg == 0 ? seUT0 : (leg == 1 ? seUT1 : seUT2);
        return IERC20(se).balanceOf(hook);
    }

    function _hookFace(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(hook);
    }

    /// @dev Exact-out through the real PoolManager; `maxAmountIn` is the hook's quote plus a 1%
    ///      cushion the router refunds unused (Apex008 pattern with a decimal-safe cushion).
    function _swapOut(address tokenIn, address tokenOut, uint256 amountOut) internal {
        uint256 maxIn = orbital.previewSwapExactOut(tokenIn, tokenOut, amountOut);
        _swapExactOut(tokenIn, tokenOut, amountOut, maxIn + maxIn / 100 + 1);
    }

    /* ------------------------------ §6 rows ------------------------------- */

    function test_row_bind_deploysThroughPackage() public virtual {
        assertEq(orbital.token0(), face0, "face0 on leg 0");
        assertEq(orbital.token1(), face1, "face1 on leg 1");
        assertEq(orbital.token2(), face2, "face2 on leg 2");
        assertEq(orbital.standardExchange(0), seUT0, "SE bound on leg 0");
        assertEq(orbital.standardExchange(1), seUT1, "SE bound on leg 1");
        assertEq(orbital.standardExchange(2), seUT2, "SE bound on leg 2");
        assertTrue(orbital.isBuffered(0), "leg 0 is buffered");
        assertTrue(orbital.isBuffered(1), "leg 1 is buffered");
        assertTrue(orbital.isBuffered(2), "leg 2 is buffered");
        _assertThreeProductDoorsLive();
        assertGt(IStandardExchangeIn(seUT0).previewExchangeIn(IERC20(face0), _f0(1), IERC20(seUT0)), 0, "SE0 quotes face0");
        assertGt(IStandardExchangeIn(seUT1).previewExchangeIn(IERC20(face1), _f1(1), IERC20(seUT1)), 0, "SE1 quotes face1");
        assertGt(IStandardExchangeIn(seUT2).previewExchangeIn(IERC20(face2), _f2(1), IERC20(seUT2)), 0, "SE2 quotes face2");
        assertGt(_seed(), 0, "first mint through the package-deployed hook");
        assertGt(_hookSeShares(0), 0, "hook holds SE0 shares after buffering");
        assertGt(_hookSeShares(1), 0, "hook holds SE1 shares after buffering");
        assertGt(_hookSeShares(2), 0, "hook holds SE2 shares after buffering");
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public virtual {
        _seed();
        address donor = makeAddr("donor");
        uint256 donation = _f0(500);
        fx0.fund(donor, donation);
        vm.prank(donor);
        IERC20(face0).transfer(hook, donation);
        uint256 hookFaceBefore = _hookFace(face0);
        uint256 userFace = IERC20(face0).balanceOf(user);
        uint256 seBefore = _hookSeShares(0);
        (, uint256 used0) = _addAll(_f0(1), _f1(1), _f2(1));
        assertGt(used0, 0, "join used face0");
        assertEq(userFace - IERC20(face0).balanceOf(user), used0, "joiner pays used face; resting face is not the joiner's refund");
        assertEq(_hookFace(face0), hookFaceBefore, "resting face stays on the hook");
        assertGt(_hookSeShares(0), seBefore, "buffer-first: SE shares owned by the hook");
    }

    function test_row_partialConsumption_bookedNotRefunded() public virtual {
        _seed();
        if (!fx0.hasPartialCase()) {
            _roundingToZeroControl();
            return;
        }
        _partialConsumptionRow();
    }

    function _partialConsumptionRow() internal {
        uint256 allow = _f0(10);
        fx0.limitCapacity(allow);
        uint256 bookedBefore = fx0.seBooked();
        uint256 hookFaceBefore = _hookFace(face0);
        uint256 userFace = IERC20(face0).balanceOf(user);
        uint256 seBefore = _hookSeShares(0);
        (, uint256 used0) = _addAll(_f0(50), _f1(50), _f2(50));
        assertGt(used0, allow, "join used more face than the dependency could take");
        assertEq(userFace - IERC20(face0).balanceOf(user), used0, "no refund of the unconsumed part");
        uint256 booked = fx0.seBooked() - bookedBefore;
        assertGe(booked, used0 - allow, "SE booked the remainder above capacity");
        assertLe(booked, used0, "booked remainder never exceeds what was used");
        assertGt(_hookSeShares(0), seBefore, "hook still receives SE shares for the booked input");
        assertApproxEqAbs(_hookFace(face0), hookFaceBefore, _residualTolerance(), "no operation-created face residual on the non-identity leg");
        fx0.openCapacity();
        uint256 bookedAfter = fx0.seBooked();
        _addAll(_f0(1), _f1(1), _f2(1));
        if (fx0.sweepsOnNextInvest()) {
            assertLt(fx0.seBooked(), bookedAfter, "next investing operation sweeps the booked remainder");
        } else {
            assertGe(fx0.seBooked(), bookedAfter, "sleeve-only family: booked credit is retained, never refunded");
        }
    }

    /// @dev Families with no leftover case: a dust deposit that rounds to zero SE output is either
    ///      rejected with no state change or retained by the hook; it is never refunded.
    function _roundingToZeroControl() internal {
        uint256 userFace = IERC20(face0).balanceOf(user);
        uint256 hookFace = _hookFace(face0);
        vm.prank(user);
        try orbital.depositSingle(face0, 1, user, 0, block.timestamp + 1 hours, "") returns (uint256) {
            assertEq(userFace - IERC20(face0).balanceOf(user), 1, "dust taken, not refunded");
        } catch {
            assertEq(IERC20(face0).balanceOf(user), userFace, "rejected dust leaves the caller untouched");
            assertEq(_hookFace(face0), hookFace, "rejected dust leaves the hook untouched");
        }
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public virtual {
        _seed();
        IERC20 tin = IERC20(face1);
        IERC20 tout = IERC20(face0);
        uint256 amountIn = _f1(1);
        _mintFor(face1, rowEoa, amountIn);
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

    /// @dev F1 fixed 2026-09-21: `_securePull` / `_pullExactOutInput` now measure the pretransfer credit
    ///      with `_unbookedBalance` (the dual hook's rule), so a contract that pretransfers into a
    ///      BUFFERED input leg is credited `min(unbooked, maxAmountIn)` and refunded `credit - used` (D15).
    ///      Red record: run 5 (`review-20260921/hook-se-matrix-run-5.log`) asserted
    ///      `TransferDeltaInsufficient(needIn, 0)` on this body for all 12 orbital rows.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public virtual {
        _seed();
        IERC20 tin = IERC20(face1);
        IERC20 tout = IERC20(face0);
        uint256 wantOut = _f0(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(needIn, 0);
        uint256 fatMax = needIn * 3;
        _mintFor(face1, address(this), fatMax);
        tin.approve(address(rowCaller), fatMax);
        uint256 callerOutBefore = tout.balanceOf(address(rowCaller));
        uint256 seBefore = _hookSeShares(0);
        uint256 used = _pretransferExactOut(tin, tout, fatMax, wantOut);
        assertGt(used, 0);
        assertLe(used, fatMax, "used within the bounded credit");
        assertEq(tout.balanceOf(address(rowCaller)) - callerOutBefore, wantOut, "exact output delivered");
        assertEq(tin.balanceOf(address(rowCaller)), fatMax - used, "refund is credit - used");
        assertEq(tin.balanceOf(address(this)), 0, "payer spent fatMax");
        assertLt(_hookSeShares(0), seBefore, "SE shares burned only for the delivered face");
    }

    /// @dev Contract-path pretransfer (M8): `rowCaller` pulls `credit` of `tin` from this test,
    ///      transfers it to the hook and calls `exchangeOut(..., true)` in the same transaction.
    function _pretransferExactOut(IERC20 tin, IERC20 tout, uint256 credit, uint256 wantOut)
        internal
        returns (uint256 used)
    {
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (tin, credit, tout, wantOut, address(rowCaller), true, block.timestamp + 1 hours)
        );
        used = abi.decode(rowCaller.consumePretransfer(tin, address(this), hook, credit, data), (uint256));
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public virtual {
        _seed();
        IERC20 tin = IERC20(face1);
        IERC20 tout = IERC20(face0);
        uint256 wantOut = _f0(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        uint256 fatMax = needIn * 3;
        _mintFor(face1, user, fatMax);
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
        uint256 resting0 = _hookFace(face0);
        uint256 resting1 = _hookFace(face1);
        uint256 uFace0 = IERC20(face0).balanceOf(user);
        uint256 uFace1 = IERC20(face1).balanceOf(user);

        _swapExactIn(face0, face1, _f0(1));
        assertGt(IERC20(face1).balanceOf(user), uFace1, "exact-in face0->face1 paid");
        assertApproxEqAbs(_hookFace(face1), resting1, _residualTolerance(), "exact-in: no face residual on the leg swapped into (face1)");
        uFace1 = IERC20(face1).balanceOf(user);
        uFace0 = IERC20(face0).balanceOf(user);

        _swapExactIn(face1, face0, _f1(1));
        assertGt(IERC20(face0).balanceOf(user), uFace0, "exact-in face1->face0 paid");
        assertApproxEqAbs(_hookFace(face0), resting0, _residualTolerance(), "exact-in: no face residual on the leg swapped into (face0)");
        uFace0 = IERC20(face0).balanceOf(user);
        uFace1 = IERC20(face1).balanceOf(user);

        uint256 quoteOut = orbital.previewSwapExactIn(face0, face1, _f0(1));
        _swapOut(face0, face1, quoteOut / 2);
        assertEq(IERC20(face1).balanceOf(user) - uFace1, quoteOut / 2, "exact-out face0->face1 delivers the request");
        assertApproxEqAbs(_hookFace(face1), resting1, _residualTolerance(), "exact-out: no face residual on the leg swapped into (face1)");
        uFace0 = IERC20(face0).balanceOf(user);

        _swapOut(face1, face0, _f0(1) / 2);
        assertEq(IERC20(face0).balanceOf(user) - uFace0, _f0(1) / 2, "exact-out face1->face0 delivers the request");
        assertApproxEqAbs(_hookFace(face0), resting0, _residualTolerance(), "exact-out: no face residual on the leg swapped into (face0)");

        assertApproxEqAbs(_hookFace(face0), resting0, _residualTolerance(), "no operation-created face0 residual");
        assertApproxEqAbs(_hookFace(face1), resting1, _residualTolerance(), "no operation-created face1 residual");
    }

    function test_row_seFailure_rollsBack() public virtual {
        _seed();
        if (!fx0.operativeRevertReachable()) {
            _seFailureNotReachableControl();
            return;
        }
        fx0.armOperativeRevert();
        _seFailureRow();
        fx0.disarmOperativeRevert();
        (uint256 shares,) = _addAll(_f0(10), _f1(10), _f2(10));
        assertGt(shares, 0, "positive control after the dependency recovers");
    }

    /// @dev Balances, books and LP supply captured before a rejected operation (one memory pointer
    ///      on the stack so the seven-argument `addLiquidity` call site stays within limits).
    struct Snap {
        uint256[3] userFace;
        uint256[3] hookSe;
        uint256 booked;
        uint256 supply;
    }

    function _snap() internal view returns (Snap memory s) {
        s.userFace[0] = IERC20(face0).balanceOf(user);
        s.userFace[1] = IERC20(face1).balanceOf(user);
        s.userFace[2] = IERC20(face2).balanceOf(user);
        s.hookSe[0] = _hookSeShares(0);
        s.hookSe[1] = _hookSeShares(1);
        s.hookSe[2] = _hookSeShares(2);
        s.booked = fx0.seBooked();
        s.supply = IERC20(hook).totalSupply();
    }

    function _assertUnchanged(Snap memory s) internal view {
        assertEq(IERC20(face0).balanceOf(user), s.userFace[0], "face0 untouched");
        assertEq(IERC20(face1).balanceOf(user), s.userFace[1], "face1 untouched");
        assertEq(IERC20(face2).balanceOf(user), s.userFace[2], "face2 untouched");
        assertEq(_hookSeShares(0), s.hookSe[0], "SE0 shares untouched");
        assertEq(_hookSeShares(1), s.hookSe[1], "SE1 shares untouched");
        assertEq(_hookSeShares(2), s.hookSe[2], "SE2 shares untouched");
        assertEq(fx0.seBooked(), s.booked, "SE books untouched");
        assertEq(IERC20(hook).totalSupply(), s.supply, "no LP minted");
    }

    function _seFailureRow() internal {
        Snap memory s = _snap();
        uint256 a0 = _f0(10);
        uint256 a1 = _f1(10);
        uint256 a2 = _f2(10);
        bytes memory expected = rejectBytes;
        vm.prank(user);
        vm.expectRevert(expected);
        orbital.addLiquidity(a0, a1, a2, user, 0, block.timestamp + 1 hours, "");
        _assertUnchanged(s);
    }

    /// @dev Families whose buffering route makes no dependency call (Lido: WETH→SE credits the
    ///      sleeve only): there is no operative failure to inject on this route, so the control is
    ///      that buffering completes and the SE's local book grows by the buffered input.
    function _seFailureNotReachableControl() internal {
        uint256 bookedBefore = fx0.seBooked();
        (uint256 shares,) = _addAll(_f0(10), _f1(10), _f2(10));
        assertGt(shares, 0, "buffering completes");
        assertGt(fx0.seBooked(), bookedBefore, "buffering credits the SE's local book; no dependency call on this route");
    }

    function test_row_previewMatchesExecution() public virtual {
        uint256 shares = _seed();
        _previewAddRow();
        _previewDepositSingleRow();
        _previewRemoveRow(shares / 10);
        _previewSwapRow();
    }

    function _previewAddRow() internal {
        uint256 a0 = _f0(10);
        uint256 a1 = _f1(10);
        uint256 a2 = _f2(10);
        (uint256 pShares, uint256 p0, uint256 p1, uint256 p2) = orbital.previewAddLiquidity(a0, a1, a2);
        (uint256 eShares, uint256 e0, uint256 e1, uint256 e2) = _addLiquidity(a0, a1, a2);
        assertEq(eShares, pShares, "add preview == execution (shares)");
        assertEq(e0, p0, "add used face0 preview == execution");
        assertEq(e1, p1, "add used face1 preview == execution");
        assertEq(e2, p2, "add used face2 preview == execution");
    }

    function _previewDepositSingleRow() internal {
        uint256 amt = _f0(1);
        uint256 pShares = orbital.previewDepositSingle(face0, amt);
        vm.prank(user);
        uint256 got = orbital.depositSingle(face0, amt, user, 0, block.timestamp + 1 hours, "");
        assertEq(got, pShares, "depositSingle preview == execution");
    }

    function _previewRemoveRow(uint256 burn) internal {
        (uint256 p0, uint256 p1, uint256 p2) = orbital.previewRemoveLiquidity(burn);
        uint256 before0 = IERC20(face0).balanceOf(user);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) = orbital.removeLiquidity(burn, user, 0, 0, 0, block.timestamp + 1 hours);
        assertEq(a0, p0, "remove preview == execution (face0)");
        assertEq(a1, p1, "remove preview == execution (face1)");
        assertEq(a2, p2, "remove preview == execution (face2)");
        assertEq(IERC20(face0).balanceOf(user) - before0, a0, "remove delivered the returned face0");
    }

    function _previewSwapRow() internal {
        uint256 pSwap = orbital.previewSwapExactIn(face0, face1, _f0(1));
        uint256 oBefore = IERC20(face1).balanceOf(user);
        _swapExactIn(face0, face1, _f0(1));
        assertEq(IERC20(face1).balanceOf(user) - oBefore, pSwap, "swap preview == execution");
    }

    function test_row_ammCallerFundSeparation() public virtual {
        if (!fx0.isAmm()) {
            emit log("not an AMM family: D33 fund-separation control not applicable");
            return;
        }
        _seed();
        uint256 reservedFace = IBasicVault(seUT0).reserveOfToken(face0);
        address ot = fx0.otherToken();
        uint256 amt = 10 * (10 ** uint256(IERC20Metadata_decimals(ot)));
        fx0.fundOther(rowBob, amt);
        vm.startPrank(rowBob);
        IERC20(ot).approve(seUT0, amt);
        IStandardExchangeIn(seUT0).exchangeIn(IERC20(ot), amt, IERC20(seUT0), 0, rowBob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGe(IBasicVault(seUT0).reserveOfToken(face0), reservedFace, "reserved face leftover not consumed by an other-token caller (its own dust may add)");
    }

    function IERC20Metadata_decimals(address token) internal view returns (uint8 d) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok && ret.length == 32, "decimals");
        d = abi.decode(ret, (uint8));
    }
}
