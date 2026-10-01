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
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPairPoolLib.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
 * @notice D20 / R10.3 row behavior for the single-CP buffer hook (open item 1 PRD §6), the
 *         production DETF reserve hook and the host of the M13 heavy-family rows. A concrete row
 *         supplies the SE fixture through `_newFixture()`; the hook is redeployed through its real
 *         package, the vault registry and the hook factory with the fixture's face token as
 *         `pairToken` and the fixture's SE bound to that leg (M3). `rawToken` stays the base's raw
 *         18-decimal test token.
 * @dev The base's `hook`, `single` and `poolKey` are rebound to the row hook; the base's
 *      `pairToken`, `pairProtocolVault` and `se` are left untouched so retained family tests that
 *      redeploy their own hook keep working. Row helpers below never touch base tokens except
 *      `rawToken`.
 */
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior is
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook
{
    SeMatrixFixture internal fx;
    address internal face;
    address internal raw;
    address internal seUT;
    bool internal faceIsCurrency0;
    WrapperExactOutRouter internal swapRouter;
    AtomicPretransferCaller internal rowCaller;
    address internal rowEoa;
    address internal rowBob;
    /// @dev Cached so helpers never make an external call between a `vm.prank` and its target.
    uint8 internal faceDec;
    uint256 internal seedUnits;
    bytes internal rejectBytes;

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
        seedUnits = fx.seedFaceUnits();
        rejectBytes = fx.rejectBytes();
        raw = address(rawToken);
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        swapRouter = new WrapperExactOutRouter(pm);

        _deployRowHook(_rowPkgArgs());

        fx.fund(user, _f(1_000_000));
        rawToken.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        rawToken.approve(hook, type(uint256).max);
        rawToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /* ------------------------------ deployment ---------------------------- */

    /// @dev Family PkgArgs with the fixture face on the SE leg; decimals recomputed the way the
    ///      base's `_defaultPkgArgs` does (HookPkgArgsDecimalsLib).
    function _rowPkgArgs() internal returns (IPkg.PkgArgs memory) {
        return IPkg.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange: seUT,
            pairToken: face,
            rawToken: raw,
            pairTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(face),
            rawTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(raw),
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner(),
            rateProvider: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seUT, face) // D60
        });
    }

    /// @dev Same inline path as the base `setUp`: package -> registry -> hook factory, then the
    ///      staged door open + finalize and the product pool key.
    function _deployRowHook(IPkg.PkgArgs memory args) internal {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook, args.rawToken, args.pairToken);
        single = IHook(hook);
        _bindProductPoolKey();
        faceIsCurrency0 = single.currency0() == args.pairToken;
    }

    /* ------------------------------- helpers ------------------------------ */

    function _f(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec));
    }

    function _mintFor(address token, address to, uint256 amount) internal {
        if (token == face) fx.fund(to, amount);
        else SimpleMintableERC20(token).mint(to, amount);
    }

    /// @dev Pool-order amounts for `deposit(amount0, amount1, ...)`.
    function _ordered(uint256 faceAmt, uint256 rawAmt) internal view returns (uint256 a0, uint256 a1) {
        if (faceIsCurrency0) return (faceAmt, rawAmt);
        return (rawAmt, faceAmt);
    }

    function _joinBoth(uint256 faceAmt, uint256 rawAmt) internal returns (uint256 lp, uint256 usedFace) {
        (uint256 a0, uint256 a1) = _ordered(faceAmt, rawAmt);
        vm.prank(user);
        (uint256 lpOut, uint256 used0, uint256 used1) = single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        lp = lpOut;
        usedFace = faceIsCurrency0 ? used0 : used1;
    }

    function _seed() internal returns (uint256 lp) {
        (lp,) = _joinBoth(_f(seedUnits), seedUnits * 1 ether);
    }

    function _hookSeShares() internal view returns (uint256) {
        return IERC20(seUT).balanceOf(hook);
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    /// @dev Real PoolManager exact-in swap through the repository's `WrapperExactOutRouter` on the
    ///      product pool key (currency-sorted, so `zeroForOne == tokenIn < tokenOut`).
    function _swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) internal {
        bool zeroForOne = tokenIn < tokenOut;
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
        });
        vm.prank(user);
        swapRouter.swapExactIn(poolKey, params, "");
    }

    /// @dev Exact-out: the router settles the maximum first, then refunds the unused input.
    function _swapExactOut(address tokenIn, address tokenOut, uint256 amountOut) internal {
        bool zeroForOne = tokenIn < tokenOut;
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountOut),
            sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
        });
        uint256 maximum = single.previewSwapExactOut(tokenIn, tokenOut, amountOut);
        vm.prank(user);
        swapRouter.swapExactOut(poolKey, params, maximum, "");
    }

    /* ------------------------------ §6 rows ------------------------------- */

    function test_row_bind_deploysThroughPackage() public virtual {
        assertEq(single.standardExchange(), seUT, "SE bound on the pair leg");
        assertEq(single.pairToken(), face, "face token on the pair leg");
        assertEq(single.rawToken(), raw, "raw leg unchanged");
        assertEq(single.standardExchangeOf(face), seUT, "leg view reports the SE");
        assertEq(single.standardExchangeOf(raw), address(0), "raw leg has no SE");
        assertTrue(_registry().isVault(hook), "registered through the vault registry");
        assertTrue(PairPoolLib.isPoolLive(pm, poolKey), "product door live");
        assertGt(
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), _f(1), IERC20(seUT)), 0, "SE quotes the face"
        );
        assertGt(_seed(), 0, "first mint through the package-deployed hook");
        assertTrue(single.isLive(), "live after the first mint");
        assertGt(_hookSeShares(), 0, "hook holds SE shares after buffering");
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
        (, uint256 usedFace) = _joinBoth(_f(1), 1 ether);
        assertGt(usedFace, 0, "join used face");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "joiner pays used face; resting face is not the joiner's refund");
        assertGt(_hookSeShares(), seBefore, "buffer-first: SE shares owned by the hook");
        assertLe(IERC20(face).balanceOf(hook), DUST, "resting face is rebuffered, never paid to the joiner");
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
        (, uint256 usedFace) = _joinBoth(_f(50), 50 ether);
        assertGt(usedFace, allow, "join used more face than the dependency could take");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "no refund of the unconsumed part");
        uint256 booked = fx.seBooked() - bookedBefore;
        assertGe(booked, usedFace - allow, "SE booked the remainder above capacity");
        assertLe(booked, usedFace, "booked remainder never exceeds what was used");
        assertGt(_hookSeShares(), seBefore, "hook still receives SE shares for the booked input");
        fx.openCapacity();
        uint256 bookedAfter = fx.seBooked();
        _joinBoth(_f(1), 1 ether);
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
        try single.depositSingle(face, 1, user, 0, block.timestamp + 1 hours) returns (uint256) {
            assertEq(userFace - IERC20(face).balanceOf(user), 1, "dust taken, not refunded");
        } catch {
            assertEq(IERC20(face).balanceOf(user), userFace, "rejected dust leaves the caller untouched");
            assertEq(IERC20(face).balanceOf(hook), hookFace, "rejected dust leaves the hook untouched");
        }
    }

    function test_row_hookSwap_exactIn_eoaPretransferRejected() public virtual {
        _seed();
        IERC20 tin = IERC20(raw);
        IERC20 tout = IERC20(face);
        uint256 amountIn = 1 ether;
        _mintFor(raw, rowEoa, amountIn);
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
        IERC20 tin = IERC20(raw);
        IERC20 tout = IERC20(face);
        uint256 wantOut = _f(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(needIn, 0);
        uint256 fatMax = needIn * 3;
        _mintFor(raw, address(this), fatMax);
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
        IERC20 tin = IERC20(raw);
        IERC20 tout = IERC20(face);
        uint256 wantOut = _f(1);
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        uint256 fatMax = needIn * 3;
        _mintFor(raw, user, fatMax);
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
        // Free face on this hook is refund dust only (PRD D86); the seed leaves at most MAX_DUST_WEI.
        assertLe(IERC20(face).balanceOf(hook), DUST, "opening resting face is dust only");
        uint256 uFace = IERC20(face).balanceOf(user);
        uint256 uRaw = IERC20(raw).balanceOf(user);

        _swapExactIn(face, raw, _f(1));
        assertGt(IERC20(raw).balanceOf(user), uRaw, "exact-in face->raw paid");
        uRaw = IERC20(raw).balanceOf(user);
        uFace = IERC20(face).balanceOf(user);

        _swapExactIn(raw, face, 1 ether);
        assertGt(IERC20(face).balanceOf(user), uFace, "exact-in raw->face paid");
        uFace = IERC20(face).balanceOf(user);
        uRaw = IERC20(raw).balanceOf(user);

        uint256 quoteOut = single.previewSwapExactIn(face, raw, _f(1));
        _swapExactOut(face, raw, quoteOut / 2);
        assertEq(IERC20(raw).balanceOf(user) - uRaw, quoteOut / 2, "exact-out face->raw delivers the request");
        uFace = IERC20(face).balanceOf(user);
        uRaw = IERC20(raw).balanceOf(user);

        _swapExactOut(raw, face, _f(1) / 2);
        assertEq(IERC20(face).balanceOf(user) - uFace, _f(1) / 2, "exact-out raw->face delivers the request");

        assertLe(
            IERC20(face).balanceOf(hook), DUST, "no operation-created face residual on the buffered leg beyond MAX_DUST_WEI"
        );
    }

    function test_row_seFailure_rollsBack() public virtual {
        _seed();
        if (!fx.operativeRevertReachable()) {
            _seFailureNotReachableControl();
            return;
        }
        fx.armOperativeRevert();
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 userRaw = IERC20(raw).balanceOf(user);
        uint256 seShares = _hookSeShares();
        uint256 booked = fx.seBooked();
        uint256 supply = IERC20(hook).totalSupply();
        (uint256 a0, uint256 a1) = _ordered(_f(10), 10 ether);
        bytes memory expected = rejectBytes;
        vm.prank(user);
        vm.expectRevert(expected);
        single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertEq(IERC20(face).balanceOf(user), userFace, "face untouched");
        assertEq(IERC20(raw).balanceOf(user), userRaw, "raw untouched");
        assertEq(_hookSeShares(), seShares, "SE shares untouched");
        assertEq(fx.seBooked(), booked, "SE books untouched");
        assertEq(IERC20(hook).totalSupply(), supply, "no LP minted");
        fx.disarmOperativeRevert();
        (uint256 lp,) = _joinBoth(_f(10), 10 ether);
        assertGt(lp, 0, "positive control after the dependency recovers");
    }

    /// @dev Families whose buffering route makes no dependency call (Lido: WETH→SE credits the
    ///      sleeve only): there is no operative failure to inject on this route, so the control is
    ///      that buffering completes and the SE's local book grows by the buffered input.
    function _seFailureNotReachableControl() internal {
        uint256 bookedBefore = fx.seBooked();
        (uint256 lp,) = _joinBoth(_f(10), 1 ether);
        assertGt(lp, 0, "buffering completes");
        assertGt(fx.seBooked(), bookedBefore, "buffering credits the SE's local book; no dependency call on this route");
    }

    function test_row_previewMatchesExecution() public virtual {
        uint256 lp = _seed();
        (uint256 a0, uint256 a1) = _ordered(_f(10), 10 ether);
        (uint256 pLp, uint256 pUsed0, uint256 pUsed1) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 gotLp, uint256 used0, uint256 used1) = single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertEq(used0, pUsed0, "deposit used0 preview == execution");
        assertEq(used1, pUsed1, "deposit used1 preview == execution");
        // Preview books the leg with a fresh buffer quote; execution books the SE claim delta. The
        // family's gold suite allows 2% here (Liquidity.t.sol); this row holds it to 1e-6 relative.
        assertApproxEqRel(gotLp, pLp, 1e12, "deposit LP preview == execution");

        uint256 burn = lp / 10;
        uint256 pOut = single.previewWithdrawSingle(burn, face);
        uint256 before = IERC20(face).balanceOf(user);
        vm.prank(user);
        uint256 out = single.withdrawSingle(burn, face, user, 0, block.timestamp + 1 hours);
        assertEq(out, pOut, "withdrawSingle(face) preview == execution");
        assertEq(IERC20(face).balanceOf(user) - before, out, "withdraw delivered the returned amount");

        uint256 probe = _previewSwapProbe();
        if (probe == 0) {
            emit log("swap control skipped: the row pins it to a recorded finding (see its test_BLOCKED_* test)");
            return;
        }
        uint256 pSwap = single.previewSwapExactIn(face, raw, probe);
        uint256 rBefore = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, probe);
        assertEq(IERC20(raw).balanceOf(user) - rBefore, pSwap, "swap preview == execution");
    }

    /// @dev Face amount the preview row swaps after its deposit and withdraw. A row whose SE cannot take the
    ///      buffer at that point (a recorded finding) overrides it to 0 and pins the control to the finding.
    function _previewSwapProbe() internal view virtual returns (uint256) {
        return _f(1);
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
        assertGe(IBasicVault(seUT).reserveOfToken(face), reservedFace, "reserved face leftover not consumed by an other-token caller (its own dust may add)");
    }

    function IERC20Metadata_decimals(address token) internal view returns (uint8 d) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok && ret.length == 32, "decimals");
        d = abi.decode(ret, (uint8));
    }
}
