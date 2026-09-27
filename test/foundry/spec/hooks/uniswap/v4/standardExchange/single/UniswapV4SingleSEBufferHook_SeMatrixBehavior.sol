// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookPairPoolLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title UniswapV4SingleSEBufferHook_SeMatrixBehavior
 * @notice D20 / R10.3 row behavior for the non-CP single SE buffer hook (open item 1 PRD §6, WP0).
 *         A concrete row supplies the SE fixture through `_newFixture()`; the hook is redeployed
 *         through its real package, registry and hook factory with the fixture's face token as
 *         `pairToken` and the fixture's SE as `standardExchange` (M3). The hook has one SE leg and
 *         no raw leg, so the fixture is created once.
 *
 * @dev Surface adaptation. This hook is a pure wrap/unwrap hop: its only money entry point is the
 *      PoolManager swap (`beforeSwap` returns the full delta), and its product facet exposes
 *      `previewWrap / previewWrapExactOut / previewUnwrap / previewUnwrapExactOut` plus bindings
 *      (`UniswapV4SingleStandardExchangeBufferHookFacet.facetFuncs`). No `IStandardExchangeIn` /
 *      `IStandardExchangeOut` selector is cut on the diamond, so the §6 rows map as follows:
 *      - join / deposit = wrap (face -> SE shares) through `swapRouter` (`WrapperExactOutRouter`);
 *      - withdraw = unwrap (SE shares -> face) through the same router;
 *      - the "hook swap" pretransfer rows run against the PoolManager route: a pretransfer to
 *        the hook is never credited and never refunded, the router's settled max-in is the credit
 *        and its unused-credit return is the refund;
 *      - "SE shares owned by the hook" becomes "the hook retains no SE shares and no face; the
 *        swapper receives exactly the SE quote of the input it settled".
 *      The gold TestBase handles `pairToken`, `se`, `hook`, `buffer`, `poolKey` are rebound to the
 *      fixture so the base wrap/unwrap helpers (`_wrapExactIn`, `_unwrapExactIn`, `_wrapExactOut`,
 *      `_unwrapExactOut`, `_assertHookFlat*`) act on the row hook. The throwaway `protocolVault`
 *      from the gold setUp is cleared so no row can use it by accident.
 */
abstract contract UniswapV4SingleSEBufferHook_SeMatrixBehavior is TestBase_UniswapV4SingleStandardExchangeBufferHook {
    SeMatrixFixture internal fx;
    address internal face;
    address internal seUT;
    AtomicPretransferCaller internal rowCaller;
    address internal rowEoa;
    address internal rowBob;
    /// @dev Cached so helpers never make an external call between a `vm.prank` and its target.
    uint8 internal faceDec;
    bytes internal rejectBytes;

    /// @dev Locals for the exact-out contract-caller row (stack relief under legacy codegen).
    struct ExactOutCtx {
        uint256 wantOut;
        uint256 needIn;
        uint256 fatMax;
        uint256 credit;
        uint256 hookSeBefore;
        uint256 hookFaceBefore;
        uint256 supplyBefore;
        uint256 callerFaceBefore;
    }

    function _newFixture() internal virtual returns (SeMatrixFixture);

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
        face = fx.faceToken();
        seUT = fx.se();
        faceDec = fx.faceDecimals();
        // A9 / A10: per-leg SE address and face decimals for the matrix evidence (parsed from the -vv log).
        emit log_named_address("matrix.se0", seUT);
        emit log_named_uint("matrix.faceDecimals0", faceDec);
        rejectBytes = fx.rejectBytes();
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");

        // Rebind the gold handles onto the fixture: the face token is the hook's pairToken and the
        // fixture SE is the hook's standardExchange. The gold throwaway vault is not part of any row.
        pairToken = SimpleMintableERC20(face);
        se = seUT;
        protocolVault = IERC4626(address(0));
        _deployRowHook(_defaultPkgArgs());

        fx.fund(user, _f(1_000_000));
        vm.startPrank(user);
        IERC20(face).approve(seUT, type(uint256).max);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        // Seed SE shares for the unwrap routes (same as the gold setUp, on the fixture SE).
        IStandardExchangeIn(seUT).exchangeIn(IERC20(face), _f(200), IERC20(seUT), 0, user, false, block.timestamp);
        IERC20(seUT).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /* ------------------------------- helpers ------------------------------ */

    /// @dev Package -> registry -> hook factory, then the staged product door and finalize, then
    ///      the live product pool key. Same path as the gold setUp, on the given args.
    function _deployRowHook(IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args) internal {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook, args.pairToken, args.standardExchange);
        buffer = IHook(hook);
        _bindProductPoolKey();
    }

    function _f(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec));
    }

    function _faceOf(address who) internal view returns (uint256) {
        return IERC20(face).balanceOf(who);
    }

    function _seOf(address who) internal view returns (uint256) {
        return IERC20(seUT).balanceOf(who);
    }

    function _swapParams(bool wrap, int256 amountSpecified) internal view returns (SwapParams memory p, bool zfo) {
        zfo = wrap ? _isWrapZFO() : !_isWrapZFO();
        p = SwapParams({zeroForOne: zfo, amountSpecified: amountSpecified, sqrtPriceLimitX96: _sqrtLimit(zfo)});
    }

    /// @dev Exact-in swap by an arbitrary actor (the base helpers are bound to `user`).
    function _swapExactInAs(address who, bool wrap, uint256 amountIn) internal {
        (SwapParams memory p,) = _swapParams(wrap, -int256(amountIn));
        vm.prank(who);
        swapRouter.swapExactIn(poolKey, p, bytes(""));
    }

    function _exactOutCalldata(bool wrap, uint256 amountOut, uint256 maxIn) internal view returns (bytes memory) {
        (SwapParams memory p,) = _swapParams(wrap, int256(amountOut));
        return abi.encodeCall(swapRouter.swapExactOut, (poolKey, p, maxIn, bytes("")));
    }

    /// @dev The PoolManager wraps a `beforeSwap` revert as `WrappedError(hook, selector, reason, HookCallFailed)`
    ///      (`Hooks.callHook` -> `CustomRevert.bubbleUpAndRevertWith`); the router bubbles it unchanged.
    function _wrappedHookRevert(bytes memory reason) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            CustomRevert.WrappedError.selector,
            hook,
            IHooks.beforeSwap.selector,
            reason,
            abi.encodePacked(Hooks.HookCallFailed.selector)
        );
    }

    /// @dev Wrap face directly on the SE (exact-out) so `to` receives exactly `shares` SE shares.
    function _mintSeSharesTo(address to, uint256 shares) internal {
        uint256 faceMax = IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), shares);
        faceMax = faceMax + faceMax / 10 + 1;
        fx.fund(address(this), faceMax);
        IERC20(face).approve(seUT, faceMax);
        IStandardExchangeOut(seUT).exchangeOut(IERC20(face), faceMax, IERC20(seUT), shares, to, false, block.timestamp);
    }

    /* ------------------------------ §6 rows ------------------------------- */

    function test_row_bind_deploysThroughPackage() public virtual {
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
        assertGt(
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), _f(1), IERC20(seUT)), 0, "SE quotes the face"
        );
        assertGt(_wrapExactIn(_f(1)), 0, "first wrap through the package-deployed hook");
        _assertHookFlat();
    }

    /// @dev Wrap = buffer for this family. Resting face on the hook is never credited to a swapper
    ///      and never paid out: the swapper pays the full settled input and receives its SE quote.
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public virtual {
        address donor = makeAddr("donor");
        uint256 donation = _f(500);
        fx.fund(donor, donation);
        vm.prank(donor);
        IERC20(face).transfer(hook, donation);
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);
        uint256 preview = buffer.previewWrap(_f(1));
        uint256 seOut = _wrapExactIn(_f(1));
        assertEq(seOut, preview, "swapper receives the quote of its own input");
        assertEq(_seOf(user) - userSe, seOut, "SE shares delivered to the swapper");
        assertEq(userFace - _faceOf(user), _f(1), "swapper pays the full input; resting face is not its refund");
        assertEq(_faceOf(hook), donation, "resting face stays on the hook, not paid to the wrapper");
        assertEq(_seOf(hook), 0, "no SE shares minted from resting face");
    }

    function test_row_partialConsumption_bookedNotRefunded() public virtual {
        if (!fx.hasPartialCase()) {
            _roundingToZeroControl();
            return;
        }
        uint256 allow = _f(10);
        fx.limitCapacity(allow);
        uint256 bookedBefore = fx.seBooked();
        uint256 userFace = _faceOf(user);
        uint256 hookFace = _faceOf(hook);
        uint256 usedFace = _f(50);
        uint256 seOut = _wrapExactIn(usedFace);
        assertGt(seOut, 0, "wrap paid SE for the full credited input");
        assertGt(usedFace, allow, "wrap used more face than the dependency could take");
        assertEq(userFace - _faceOf(user), usedFace, "no refund of the unconsumed part");
        uint256 booked = fx.seBooked() - bookedBefore;
        assertGe(booked, usedFace - allow, "SE booked the remainder above capacity");
        assertLe(booked, usedFace, "booked remainder never exceeds what was used");
        assertApproxEqAbs(_faceOf(hook), hookFace, 10, "hook holds no operation-created face residual");
        assertEq(_seOf(hook), 0, "hook retains no SE shares");
        fx.openCapacity();
        uint256 bookedAfter = fx.seBooked();
        _wrapExactIn(_f(1));
        if (fx.sweepsOnNextInvest()) {
            assertLt(fx.seBooked(), bookedAfter, "next investing operation sweeps the booked remainder");
        } else {
            assertGe(fx.seBooked(), bookedAfter, "sleeve-only family: booked credit is retained, never refunded");
        }
    }

    /// @dev Families with no leftover case: a dust wrap that rounds to zero SE output is either
    ///      rejected with no state change or taken in full; it is never refunded and never left
    ///      on the hook.
    function _roundingToZeroControl() internal {
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);
        uint256 hookFace = _faceOf(hook);
        (SwapParams memory p,) = _swapParams(true, -int256(1));
        vm.prank(user);
        try swapRouter.swapExactIn(poolKey, p, bytes("")) {
            assertEq(userFace - _faceOf(user), 1, "dust taken, not refunded");
            uint256 seDec_ = fx.seDecimals();
            uint256 unitScale = seDec_ > faceDec ? 10 ** (seDec_ - faceDec) : 1;
            assertLe(_seOf(user) - userSe, unitScale, "dust yields at most one face-unit-equivalent of shares");
        } catch {
            assertEq(_faceOf(user), userFace, "rejected dust leaves the caller untouched");
            assertEq(_seOf(user), userSe, "rejected dust mints nothing");
        }
        assertEq(_faceOf(hook), hookFace, "dust never rests on the hook");
    }

    /// @dev No SE-like entry point exists on this diamond: `exchangeIn` is an unmatched selector
    ///      (`Proxy.NoTargetFor`). The only route is the PoolManager swap, which prices the input
    ///      the swapper settles; a face pretransfer to the hook is neither credited nor refunded.
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public virtual {
        uint256 amt = _f(1);
        fx.fund(rowEoa, amt * 2);
        vm.prank(rowEoa);
        IERC20(face).transfer(hook, amt);
        uint256 hookFace = _faceOf(hook);
        uint256 eoaSe = _seOf(rowEoa);
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(rowEoa);
        vm.expectRevert(abi.encodeWithSelector(Proxy.NoTargetFor.selector, IStandardExchangeIn.exchangeIn.selector));
        IStandardExchangeIn(hook).exchangeIn(IERC20(face), amt, IERC20(seUT), 0, rowEoa, true, deadline);
        assertEq(_faceOf(hook), hookFace, "no state change on reject");
        assertEq(_seOf(rowEoa), eoaSe, "no output on reject");

        vm.prank(rowEoa);
        IERC20(face).approve(address(swapRouter), amt);
        uint256 preview = buffer.previewWrap(amt);
        _swapExactInAs(rowEoa, true, amt);
        assertEq(_seOf(rowEoa) - eoaSe, preview, "output equals the quote of the settled input only");
        assertEq(_faceOf(rowEoa), 0, "EOA paid the settled input; the pretransfer bought nothing");
        assertEq(_faceOf(hook), hookFace, "pretransferred face is neither credited nor refunded");
    }

    /// @dev Contract caller (`AtomicPretransferCaller`) on the exact-out unwrap route: the router's
    ///      settled max-in is the credit; the hook takes exactly `needIn`; the router returns
    ///      `credit - used`; the SE burns only `needIn`. A separate SE-share pretransfer resting on
    ///      the hook is neither consumed nor refunded.
    ///      `c.needIn` sizes the funding (`fatMax`/`credit`), so it must be quoted before the mint.
    ///      The `used` assertion instead compares against `expectedIn`, re-quoted at the post-mint
    ///      pool state the swap actually executes against: `_mintSeSharesTo` adds ~`needIn`*4 of
    ///      single-token liquidity, which shifts a weighted/multipair pool's exact-out quote by
    ///      ~0.18% off the pre-mint `needIn` (a stale reference, not an SE preview/execution gap —
    ///      the hook `require(spent == seIn)` proves preview mirrors execution wei-for-wei at one
    ///      state). Stable/constant-product SEs move <0.1% under the same add, so they passed either
    ///      way; the re-quote makes the comparison like-for-like for every pool type.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public virtual {
        ExactOutCtx memory c;
        c.wantOut = _f(1);
        c.needIn = buffer.previewUnwrapExactOut(c.wantOut);
        assertGt(c.needIn, 0);
        c.fatMax = c.needIn * 3;
        c.credit = c.needIn;
        _mintSeSharesTo(address(this), c.fatMax + c.credit);

        // Resting pretransfer of SE shares by the contract caller.
        IERC20(seUT).transfer(address(rowCaller), c.credit);
        rowCaller.execute(seUT, abi.encodeCall(IERC20.transfer, (hook, c.credit)));
        c.hookSeBefore = _seOf(hook);
        c.hookFaceBefore = _faceOf(hook);
        assertGe(c.hookSeBefore, c.credit, "pretransfer rests on the hook");

        IERC20(seUT).approve(address(rowCaller), c.fatMax);
        c.supplyBefore = IERC20(seUT).totalSupply();
        c.callerFaceBefore = _faceOf(address(rowCaller));
        uint256 payerSeBefore = _seOf(address(this));
        // Re-quote at the current (post-mint) pool state — the exact state the swap runs against —
        // so `used` is compared like-for-like. No pool mutation happens between here and the swap.
        uint256 expectedIn = buffer.previewUnwrapExactOut(c.wantOut);
        rowCaller.consumePull(
            IERC20(seUT), address(this), address(swapRouter), c.fatMax, _exactOutCalldata(false, c.wantOut, c.fatMax)
        );

        assertEq(_faceOf(address(rowCaller)) - c.callerFaceBefore, c.wantOut, "exact output delivered");
        uint256 used = c.fatMax - _seOf(address(rowCaller));
        assertApproxEqRel(used, expectedIn, 1e15, "executed input within 0.1% of the preview (fee dilution / AMM rounding)");
        assertEq(_seOf(address(rowCaller)), c.fatMax - used, "refund is credit - used");
        assertEq(payerSeBefore - _seOf(address(this)), c.fatMax, "payer spent fatMax");
        assertLe(c.supplyBefore - IERC20(seUT).totalSupply(), used, "SE burned no more than what it used");
        assertEq(_seOf(hook), c.hookSeBefore, "resting pretransfer neither consumed nor refunded");
        assertApproxEqAbs(_faceOf(hook), c.hookFaceBefore, 10, "no face residual from the unwrap");
    }

    /// @dev Pull route: exact-out wrap with max-in equal to the quote pulls exactly `needIn` and
    ///      returns nothing.
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public virtual {
        uint256 wantOut = buffer.previewWrap(_f(1));
        assertGt(wantOut, 0);
        uint256 needIn = buffer.previewWrapExactOut(wantOut);
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);
        uint256 hookFace = _faceOf(hook);
        uint256 hookSe = _seOf(hook);
        uint256 spent = _wrapExactOut(wantOut);
        assertEq(spent, needIn, "pulls quoted used");
        assertEq(userFace - _faceOf(user), needIn, "only used pulled; no router credit left behind");
        assertEq(_seOf(user) - userSe, wantOut, "exact output");
        _assertHookFlatDelta(hookFace, hookSe);
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public virtual {
        uint256 restingFace = _faceOf(hook);
        uint256 restingSe = _seOf(hook);
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);

        uint256 seOut = _wrapExactIn(_f(1));
        assertEq(_seOf(user) - userSe, seOut, "exact-in wrap paid");
        userSe = _seOf(user);
        userFace = _faceOf(user);

        uint256 faceOut = _unwrapExactIn(seOut / 2);
        assertEq(_faceOf(user) - userFace, faceOut, "exact-in unwrap paid");
        userFace = _faceOf(user);
        userSe = _seOf(user);

        uint256 wantSe = buffer.previewWrap(_f(1)) / 2;
        _wrapExactOut(wantSe);
        assertEq(_seOf(user) - userSe, wantSe, "exact-out wrap delivers the request");
        userSe = _seOf(user);
        userFace = _faceOf(user);

        _unwrapExactOut(_f(1) / 2);
        assertEq(_faceOf(user) - userFace, _f(1) / 2, "exact-out unwrap delivers the request");

        _assertHookFlatDelta(restingFace, restingSe);
    }

    function test_row_seFailure_rollsBack() public virtual {
        if (!fx.operativeRevertReachable()) {
            _seFailureNotReachableControl();
            return;
        }
        fx.armOperativeRevert();
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);
        uint256 hookFace = _faceOf(hook);
        uint256 hookSe = _seOf(hook);
        uint256 pmFace = _faceOf(address(pm));
        uint256 booked = fx.seBooked();
        uint256 supply = IERC20(seUT).totalSupply();
        uint256 allowanceToSe = IERC20(face).allowance(hook, seUT);
        (SwapParams memory p,) = _swapParams(true, -int256(_f(10)));
        bytes memory expected = _wrappedHookRevert(rejectBytes);
        vm.prank(user);
        vm.expectRevert(expected);
        swapRouter.swapExactIn(poolKey, p, bytes(""));
        assertEq(_faceOf(user), userFace, "face untouched");
        assertEq(_seOf(user), userSe, "SE shares untouched");
        assertEq(_faceOf(hook), hookFace, "hook face untouched");
        assertEq(_seOf(hook), hookSe, "hook SE untouched");
        assertEq(_faceOf(address(pm)), pmFace, "PoolManager face untouched");
        assertEq(fx.seBooked(), booked, "SE books untouched");
        assertEq(IERC20(seUT).totalSupply(), supply, "no SE minted");
        assertEq(IERC20(face).allowance(hook, seUT), allowanceToSe, "hook allowance untouched");
        fx.disarmOperativeRevert();
        assertGt(_wrapExactIn(_f(10)), 0, "positive control after the dependency recovers");
    }

    /// @dev Hook previews are SE passthroughs; every route's preview equals its execution
    ///      (asserted inside the base helpers on the swap deltas).
    /// @dev Families whose buffering route makes no dependency call (Lido: WETH→SE credits the
    ///      sleeve only): there is no operative failure to inject on this route, so the control is
    ///      that buffering completes and the SE's local book grows by the buffered input.
    function _seFailureNotReachableControl() internal {
        uint256 bookedBefore = fx.seBooked();
        assertGt(_wrapExactIn(_f(10)), 0, "buffering completes");
        assertGt(fx.seBooked(), bookedBefore, "buffering credits the SE's local book; no dependency call on this route");
    }

    function test_row_previewMatchesExecution() public virtual {
        uint256 x = _f(3);
        assertEq(
            buffer.previewWrap(x),
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), x, IERC20(seUT)),
            "wrap preview is the SE quote"
        );
        uint256 seOut = _wrapExactIn(x);
        assertEq(
            buffer.previewUnwrap(seOut),
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), seOut, IERC20(face)),
            "unwrap preview is the SE quote"
        );
        _unwrapExactIn(seOut);
        uint256 wantSe = buffer.previewWrap(_f(1));
        assertEq(
            buffer.previewWrapExactOut(wantSe),
            IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), wantSe),
            "wrap exact-out preview is the SE quote"
        );
        _wrapExactOut(wantSe);
        assertEq(
            buffer.previewUnwrapExactOut(_f(1)),
            IStandardExchangeOut(seUT).previewExchangeOut(IERC20(seUT), IERC20(face), _f(1)),
            "unwrap exact-out preview is the SE quote"
        );
        _unwrapExactOut(_f(1));
        _assertHookFlat();
    }

    function test_row_ammCallerFundSeparation() public virtual {
        if (!fx.isAmm()) {
            emit log("not an AMM family: D33 fund-separation control not applicable");
            return;
        }
        _wrapExactIn(_f(10));
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
