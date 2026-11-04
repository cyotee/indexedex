// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook as HBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {Actor, IFSV} from "./FSDumpSandwich.t.sol";

/// DUMP-AT-EXTERNAL-SPOT: sandwich an honest single-sided idle redeem of a V4 FullSpread hookless vault.
contract FSDumpSandwichPonsTest is Acceptance {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    uint160 constant P0 = uint160(1 << 96);
    int24 lo; int24 hi; bytes32 salt;
    Actor atk; Actor victim; Actor lp1;

    function _feeTier() internal pure virtual returns (uint24) { return 0; } // Pons: LP fee 0, hook fee + creator tax
    function _extLiquidity() internal pure virtual returns (uint128) { return 1_000e18; }

    function setUp() public virtual override {
        HBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, 60, IHooks(address(ponsHook)));
        ponsHook.registerPool(poolKey, address(token1), address(this), address(this), _creatorTaxBps(), false, ponsHook.currentFeePolicy());
        poolManager.initialize(poolKey, P0);
        _seedPool(_extLiquidity());
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        _bootstrap(); // LP0 = this, 1000/1000
        _findPos(vm.getRecordedLogs());
        atk = new Actor(poolManager, poolKey, address(vault));
        victim = new Actor(poolManager, poolKey, address(vault));
        lp1 = new Actor(poolManager, poolKey, address(vault));
        token0.transfer(address(atk), 1e27); token1.transfer(address(atk), 1e27);
        token0.transfer(address(victim), 1e24); token1.transfer(address(victim), 1e24);
        token0.transfer(address(lp1), 1e24); token1.transfer(address(lp1), 1e24);
        _dualDeposit(lp1, 1_000e18);    // another honest passive LP
        _dualDeposit(victim, 500e18);   // honest victim position (~1/6 of supply)
    }

    function _findPos(Vm.Log[] memory logs) internal {
        bytes32 sig = keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(poolManager) && logs[i].topics[0] == sig
                && address(uint160(uint256(logs[i].topics[2]))) == address(vault)) {
                (lo, hi,, salt) = abi.decode(logs[i].data, (int24, int24, int256, bytes32));
            }
        }
    }

    function _dualDeposit(Actor who, uint256 amt) internal {
        (uint256 T0, uint256 T1) = _backing();
        uint256 a0 = amt * T0 / (T0 + T1); uint256 a1 = amt - a0;
        who.call(abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (_tokens(), _amounts(a0, a1), IERC20(address(vault)), 0, address(who), false, block.timestamp)));
    }

    function _price() internal view returns (uint160 sp) { (sp,,,) = poolManager.getSlot0(poolKey.toId()); }
    function _liq() internal view returns (uint128 l) { (l,,) = poolManager.getPositionInfo(poolKey.toId(), address(vault), lo, hi, salt); }

    function _backing() internal view returns (uint256 b0, uint256 b1) {
        (uint256 d0, uint256 d1) = IFSV(address(vault)).deployedReserve();
        (uint128 liq, uint256 l0, uint256 l1) = poolManager.getPositionInfo(poolKey.toId(), address(vault), lo, hi, salt);
        (uint256 g0, uint256 g1) = poolManager.getFeeGrowthInside(poolKey.toId(), lo, hi);
        uint256 e0; uint256 e1;
        unchecked { e0 = FullMath.mulDiv(g0 - l0, liq, 1 << 128); e1 = FullMath.mulDiv(g1 - l1, liq, 1 << 128); }
        b0 = token0.balanceOf(address(vault)) + d0 + e0;
        b1 = token1.balanceOf(address(vault)) + d1 + e1;
    }
    /// NAV at fair price P0 (1 t0 = 1 t1); only called with slot0 == P0
    function _nav() internal view returns (uint256) { (uint256 b0, uint256 b1) = _backing(); return b0 + b1; }
    function _pps() internal view returns (uint256) { return _nav() * 1e18 / IERC20(address(vault)).totalSupply(); }
    function _bal(address a) internal view returns (uint256) { return token0.balanceOf(a) + token1.balanceOf(a); }

    struct R { bool ok; uint256 out; int256 atkPnl; uint256 pps; uint128 liqBefore; uint128 liqAfter; uint160 spAfterVictim; }

    /// front-run (attacker tx 1: push sqrtP to P0*m/1000), honest redeem to token0 with minOut, back-run (attacker tx 2: restore P0)
    function _run(uint256 m, uint256 minOut, uint256 shares, bool z) internal returns (R memory r) {
        uint256 a0 = _bal(address(atk));
        if (m != 1000) atk.swapTo(uint160(uint256(P0) * m / 1000));
        r.liqBefore = _liq();
        uint256 vb = z ? token0.balanceOf(address(victim)) : token1.balanceOf(address(victim));
        try victim.call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(vault)), shares, z ? token0 : token1, minOut, address(victim), false, block.timestamp))) {
            r.ok = true;
        } catch {}
        r.out = (z ? token0.balanceOf(address(victim)) : token1.balanceOf(address(victim))) - vb;
        r.liqAfter = _liq();
        r.spAfterVictim = _price();
        atk.swapTo(P0); // attacker restores to fair price (also back-runs any vault placement)
        r.atkPnl = int256(_bal(address(atk))) - int256(a0);
        r.pps = _pps();
    }

    // sweep state (storage, keeps the stack shallow)
    uint256 sShares; uint256 sLp0Sh; uint256 sPv; uint256 bOut; int256 bAtk; uint256 bPps; uint256 prePps; int256 worstAbsLp = type(int256).max; uint256 griefCases;
    int256 bestInc = type(int256).min; uint256 bestLoss; int256 worstLp = type(int256).max;

    function _case(uint256 slip, uint256 m) internal {
        uint256 minOut = slip >= 10_000 ? 0 : sPv * (10_000 - slip) / 10_000;
        uint256 snap = vm.snapshotState();
        R memory r = _run(m, minOut, sShares, true);
        vm.revertToState(snap);
        string memory tag = string.concat("slip ", vm.toString(slip), " m ", vm.toString(m));
        if (!r.ok) {
            console2.log(string.concat(tag, " REVERT (victim protected by minOut); attacker cost"));
            console2.logInt(r.atkPnl - bAtk);
            return;
        }
        int256 inc = r.atkPnl - bAtk;
        int256 vloss = int256(bOut) - int256(r.out);
        int256 lp = (int256(r.pps) - int256(bPps)) * int256(sLp0Sh) / 1e18;
        int256 absLp = (int256(r.pps) - int256(prePps)) * int256(sLp0Sh) / 1e18;
        console2.log(string.concat(tag, " OK | sandwich PnL vs baseline arb / victim extra loss / LP0 delta vs baseline / LP0 delta vs PRE-OP"));
        console2.logInt(inc); console2.logInt(vloss); console2.logInt(lp); console2.logInt(absLp);
        if (absLp < worstAbsLp) worstAbsLp = absLp;
        if (absLp < 0) griefCases++;
        if (inc > bestInc) { bestInc = inc; bestLoss = uint256(vloss > 0 ? vloss : int256(0)); }
        if (lp < worstLp) worstLp = lp;
        // whenever the attacker profits, the profit never exceeds what the victim gave up (bounded by minOut)
        // whenever the attacker profits: victim loss stays inside the victim's own minOut slack, and remaining
        // holders' NAV/share never falls below its pre-op level (they only forgo part of the baseline gain)
        if (inc > 0) {
            assertLe(uint256(vloss > 0 ? vloss : int256(0)), bOut - minOut + 1, "victim loss beyond own minOut");
            assertGe(r.pps + 1, prePps, "remaining holders lose NAV/share in a profitable sandwich");
        }
    }

    function test_sandwichHonestRedeem() public {
        sShares = IERC20(address(vault)).balanceOf(address(victim));
        sLp0Sh = IERC20(address(vault)).balanceOf(address(this));
        console2.log("fee tier / victim shares / supply", uint256(_feeTier()), sShares, IERC20(address(vault)).totalSupply());
        console2.log("NAV@P0 / victim fair value", _nav(), sShares * _nav() / IERC20(address(vault)).totalSupply());
        prePps = _pps();(sPv,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(vault)), sShares, token0);
        uint256 snap = vm.snapshotState();
        R memory b = _run(1000, 0, sShares, true); // baseline: honest redeem, attacker only back-runs (plain arb)
        vm.revertToState(snap);
        bOut = b.out; bAtk = b.atkPnl; bPps = b.pps;
        console2.log("BASELINE victim out / preview", b.out, sPv);
        console2.log("  baseline back-run arb PnL (not attributable to the sandwich)");
        console2.logInt(b.atkPnl);
        uint16[4] memory slips = [uint16(50), 100, 300, 10_000];
        uint16[14] memory ms = [uint16(800), 900, 950, 990, 998, 1002, 1005, 1010, 1020, 1030, 1050, 1080, 1120, 1200];
        for (uint256 j; j < slips.length; ++j) for (uint256 i; i < ms.length; ++i) _case(slips[j], ms[i]);
        console2.log("BEST sandwich PnL / victim extra loss at that point", bestLoss);
        console2.logInt(bestInc);
        console2.log("WORST remaining-LP0 delta vs baseline (1000 shares, ~2000 NAV)");
        console2.logInt(worstLp);
        console2.log("WORST LP0 delta vs PRE-OP / #cases with absolute LP0 loss");
        console2.logInt(worstAbsLp);
        console2.log(griefCases);
        console2.log("baseline LP0 delta vs pre-op");
        console2.logInt((int256(bPps) - int256(prePps)) * int256(sLp0Sh) / 1e18);
    }
}

