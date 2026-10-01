// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
 * @notice D20 / R10.3 row behavior for the Balancer quad stable buffer hook (open item 1 PRD §6).
 *         A concrete row supplies the SE fixture through `_newFixture()`, which is called once per
 *         SE leg (M4): every one of the four legs is faced on its own fixture's face token and bound
 *         to that fixture's SE. The hook is redeployed through its real package, registry and hook
 *         factory (`_deployHookWithArgs`) with tokens sorted ascending as the package requires.
 * @dev `_seLegCount()` defaults to all four legs (M4). A row may lower it, in which case the
 *      remaining legs are the TestBase's raw 18-decimal test tokens. The "leg under test" is the
 *      lowest-address SE leg; `other` is a raw leg when one exists, else the next SE leg.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior is
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
{
    uint256 internal constant LEGS = 4;

    /// @dev Per sorted leg. `fxs[i]` is the zero address on a raw leg.
    SeMatrixFixture[] internal fxs;
    address[] internal legTokens;
    address[] internal legSes;
    uint8[] internal legDecs;

    /// @dev Leg under test (lowest-address SE leg).
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
    uint8 internal faceDec;
    bytes internal rejectBytes;

    function _newFixture() internal virtual returns (SeMatrixFixture);

    /// @dev Face residual the PoolManager swap row tolerates on a buffered leg: rounding dust (D6).
    ///      Rows for an SE family with a recorded over-delivery finding widen it and say why.
    function _residualTolerance() internal view virtual returns (uint256) {
        return 10;
    }

    /// @notice Number of legs bound to the SE family under test (M4: all four by default).
    function _seLegCount() internal view virtual returns (uint256) {
        return LEGS;
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
        _buildLegs();
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");

        _deployHookWithArgs(_rowPkgArgs());
        _setUsageFee(0);
        _setDexFee(0);
        _fundLegs();
    }

    /* ------------------------------ leg setup ----------------------------- */

    /// @dev Create one fixture per SE leg, fill raw legs from the TestBase tokens, sort by token
    ///      address (package requires ascending tokens) and pick the leg under test.
    function _buildLegs() internal {
        uint256 seLegs = _seLegCount();
        require(seLegs >= 1 && seLegs <= LEGS, "seLegCount");
        SimpleMintableERC20[4] memory raw = [token0, token1, token2, token3];
        SeMatrixFixture[] memory f = new SeMatrixFixture[](LEGS);
        address[] memory t = new address[](LEGS);
        for (uint256 i; i < LEGS; ++i) {
            if (i < seLegs) {
                f[i] = _newFixture();
                t[i] = f[i].faceToken();
            } else {
                t[i] = address(raw[i]);
            }
        }
        for (uint256 i; i < LEGS; ++i) {
            for (uint256 j = i + 1; j < LEGS; ++j) {
                if (t[j] < t[i]) {
                    (t[i], t[j]) = (t[j], t[i]);
                    (f[i], f[j]) = (f[j], f[i]);
                }
            }
        }
        bool facePicked;
        bool otherIsRaw;
        for (uint256 i; i < LEGS; ++i) {
            fxs.push(f[i]);
            legTokens.push(t[i]);
            if (address(f[i]) != address(0)) {
                legSes.push(f[i].se());
                legDecs.push(f[i].faceDecimals());
                if (!facePicked) {
                    facePicked = true;
                    faceIdx = i;
                }
            } else {
                legSes.push(address(0));
                legDecs.push(18);
                if (!otherIsRaw) {
                    otherIsRaw = true;
                    otherIdx = i;
                }
            }
        }
        if (!otherIsRaw) otherIdx = faceIdx == 0 ? 1 : 0;
        fx = fxs[faceIdx];
        face = legTokens[faceIdx];
        seUT = legSes[faceIdx];
        other = legTokens[otherIdx];
        faceDec = legDecs[faceIdx];
        // A9 / A10: per-leg SE address and face decimals for the matrix evidence (parsed from the -vv log).
        emit log_named_address("matrix.se0", seUT);
        emit log_named_uint("matrix.faceDecimals0", faceDec);
        rejectBytes = fx.rejectBytes();
    }

    function _rowPkgArgs()
        internal
        
        returns (IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory)
    {
        address[4] memory toks;
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < LEGS; ++i) {
            toks[i] = legTokens[i];
            ses[i] = legSes[i];
        }
        // D60: every buffered leg carries a StandardExchangeRateProvider quoting one share into the face token.
        rps = RateProviderFixtureLib.providersFor4(create3Factory, diamondPackageFactory, toks, ses);
        return _pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP);
    }

    function _fundLegs() internal {
        for (uint256 i; i < LEGS; ++i) {
            if (address(fxs[i]) == address(0)) {
                _fundAndApprove(SimpleMintableERC20(legTokens[i]));
                continue;
            }
            fxs[i].fund(user, _legAmt(i, 1_000_000));
            vm.startPrank(user);
            IERC20(legTokens[i]).approve(hook, type(uint256).max);
            IERC20(legTokens[i]).approve(address(swapRouter), type(uint256).max);
            vm.stopPrank();
        }
    }

    /* ------------------------------- helpers ------------------------------ */

    function _f(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(faceDec));
    }

    function _legAmt(uint256 legIdx, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(legDecs[legIdx]));
    }

    function _legIndex(address token) internal view returns (uint256) {
        for (uint256 i; i < LEGS; ++i) {
            if (legTokens[i] == token) return i;
        }
        revert("leg");
    }

    function _mintFor(address token, address to, uint256 amount) internal {
        uint256 i = _legIndex(token);
        if (address(fxs[i]) != address(0)) fxs[i].fund(to, amount);
        else SimpleMintableERC20(token).mint(to, amount);
    }

    /// @dev `faceAmt` raw face units on the leg under test; `otherHuman` human units on every other leg.
    function _amounts(uint256 faceAmt, uint256 otherHuman) internal view returns (uint256[] memory a) {
        a = new uint256[](LEGS);
        for (uint256 i; i < LEGS; ++i) {
            a[i] = i == faceIdx ? faceAmt : _legAmt(i, otherHuman);
        }
    }

    function _joinAll(uint256 faceAmt, uint256 otherHuman) internal returns (uint256 shares, uint256 usedFace) {
        uint256[] memory amounts = _amounts(faceAmt, otherHuman);
        uint256[] memory used;
        vm.prank(user);
        (shares, used) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        usedFace = used[faceIdx];
    }

    function _seed() internal returns (uint256 shares) {
        (shares,) = _joinAll(_f(100), 100);
    }

    function _hookSeShares() internal view returns (uint256) {
        return IERC20(seUT).balanceOf(hook);
    }

    /// @dev Hook face balance on every buffered leg (buffer-first resting credit).
    function _hookFaceBalances() internal view returns (uint256[] memory b) {
        b = new uint256[](LEGS);
        for (uint256 i; i < LEGS; ++i) {
            if (legSes[i] != address(0)) b[i] = IERC20(legTokens[i]).balanceOf(hook);
        }
    }

    /* ------------------------------ §6 rows ------------------------------- */

    function test_row_bind_deploysThroughPackage() public virtual {
        assertEq(quad.numTokens(), LEGS, "four legs");
        for (uint256 i; i < LEGS; ++i) {
            assertEq(quad.token(i), legTokens[i], "face token on the leg");
            if (address(fxs[i]) != address(0)) {
                assertEq(quad.standardExchange(i), legSes[i], "SE bound on the leg");
                assertTrue(quad.isBuffered(i), "SE leg is buffered");
                assertGt(
                    IStandardExchangeIn(legSes[i]).previewExchangeIn(
                        IERC20(legTokens[i]), _legAmt(i, 1), IERC20(legSes[i])
                    ),
                    0,
                    "SE quotes its face"
                );
            } else {
                assertEq(quad.standardExchange(i), address(0), "raw leg has no SE");
                assertFalse(quad.isBuffered(i), "raw leg is not buffered");
            }
        }
        assertEq(quad.standardExchange(faceIdx), seUT, "SE under test on the face leg");
        _assertAllDoorsLive();
        assertGt(_seed(), 0, "first mint through the package-deployed hook");
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
        uint256 amountIn = _legAmt(otherIdx, 1);
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
        uint256[] memory resting = _hookFaceBalances();
        uint256 uFace = IERC20(face).balanceOf(user);
        uint256 uOther = IERC20(other).balanceOf(user);
        uint256 oneOther = _legAmt(otherIdx, 1);

        _swapExactIn(face, other, _f(1));
        assertGt(IERC20(other).balanceOf(user), uOther, "exact-in face->other paid");
        uOther = IERC20(other).balanceOf(user);
        uFace = IERC20(face).balanceOf(user);

        _swapExactIn(other, face, oneOther);
        assertGt(IERC20(face).balanceOf(user), uFace, "exact-in other->face paid");
        uFace = IERC20(face).balanceOf(user);
        uOther = IERC20(other).balanceOf(user);

        uint256 quoteOut = quad.previewSwapExactIn(face, other, _f(1));
        _swapExactOut(face, other, quoteOut / 2);
        assertEq(IERC20(other).balanceOf(user) - uOther, quoteOut / 2, "exact-out face->other delivers the request");
        uFace = IERC20(face).balanceOf(user);

        _swapExactOut(other, face, _f(1) / 2);
        assertEq(IERC20(face).balanceOf(user) - uFace, _f(1) / 2, "exact-out other->face delivers the request");

        uint256[] memory closing = _hookFaceBalances();
        for (uint256 i; i < LEGS; ++i) {
            if (legSes[i] == address(0)) continue;
            assertApproxEqAbs(closing[i], resting[i], _residualTolerance(), "no operation-created face residual on a buffered leg");
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
        uint256[] memory amounts = _amounts(_f(10), 10);
        (uint256 pShares, uint256[] memory pUsed) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 gotShares, uint256[] memory used) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(gotShares, pShares, "join preview == execution");
        assertEq(used[faceIdx], pUsed[faceIdx], "join used face preview == execution");
        assertEq(used[otherIdx], pUsed[otherIdx], "join used other preview == execution");

        uint256 burn = shares / 10;
        uint256 pOut = quad.previewWithdrawSingle(face, burn);
        uint256 before = IERC20(face).balanceOf(user);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(face, burn, user, 0, block.timestamp + 1 hours);
        assertEq(out, pOut, "withdraw preview == execution");
        assertEq(IERC20(face).balanceOf(user) - before, out, "withdraw delivered the returned amount");

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
        uint256 amt = 10 * (10 ** uint256(_erc20Decimals(ot)));
        fx.fundOther(rowBob, amt);
        vm.startPrank(rowBob);
        IERC20(ot).approve(seUT, amt);
        IStandardExchangeIn(seUT).exchangeIn(IERC20(ot), amt, IERC20(seUT), 0, rowBob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(
            IBasicVault(seUT).reserveOfToken(face), reservedFace, "reserved face leftover unchanged by an other-token caller"
        );
    }

    function _erc20Decimals(address token) internal view returns (uint8 d) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok && ret.length == 32, "decimals");
        d = abi.decode(ret, (uint8));
    }
}
