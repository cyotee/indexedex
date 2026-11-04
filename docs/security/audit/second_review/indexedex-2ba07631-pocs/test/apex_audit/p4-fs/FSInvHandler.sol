// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";

interface IFSVault {
    function deployedReserve() external view returns (uint256, uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
    function localReserve(address) external view returns (uint256);
    function rebalanceLiquidReserve() external;
    function deposit(address receiver, address tokenIn, uint256 amount, uint256 minimum) external payable returns (uint256);
    function redeem(address receiver, uint256 shares, address tokenOut, uint256 minimum, bool internalBalance)
        external returns (uint256);
}

/// @notice Unprivileged actor contract (honest user, integrator-in-session, attacker or market).
/// All value it moves is its own. Can run a script inside its OWN PoolManager unlock:
/// [swap pool to moveTo] -> [staticcall preview] -> [vault call] -> [swap pool to restoreTo] -> settle.
contract FSActor is IUnlockCallback {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager public immutable pm;
    address public immutable handler;
    address public immutable vault;
    IERC20 public immutable t0;
    IERC20 public immutable t1;
    PoolKey internal key;

    constructor(IPoolManager pm_, PoolKey memory key_, address vault_, IERC20 t0_, IERC20 t1_) {
        pm = pm_; key = key_; vault = vault_; t0 = t0_; t1 = t1_; handler = msg.sender;
        t0_.approve(vault_, type(uint256).max);
        t1_.approve(vault_, type(uint256).max);
    }

    modifier onlyHandler() {
        require(msg.sender == handler, "actor: handler only");
        _;
    }

    function act(address target, bytes calldata data) external onlyHandler returns (bool ok, bytes memory ret) {
        (ok, ret) = target.call(data);
    }

    function give(IERC20 t, address to, uint256 amt) external onlyHandler {
        require(t.transfer(to, amt), "give");
    }

    /// mode 0: script; mode 1: PM.donate(a0,a1) to in-range LPs
    function session(uint160 moveTo, bytes calldata previewCall, bytes calldata vaultCall, uint160 restoreTo)
        external onlyHandler returns (bool ok, bytes memory pRet, bytes memory vRet)
    {
        try pm.unlock(abi.encode(uint8(0), abi.encode(moveTo, previewCall, vaultCall, restoreTo))) returns (bytes memory r) {
            (pRet, vRet) = abi.decode(r, (bytes, bytes));
            ok = true;
        } catch (bytes memory e) {
            vRet = e;
        }
    }

    function poolDonate(uint256 a0, uint256 a1) external onlyHandler returns (bool ok) {
        try pm.unlock(abi.encode(uint8(1), abi.encode(a0, a1))) { ok = true; } catch {}
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "actor: pm only");
        (uint8 mode, bytes memory payload) = abi.decode(data, (uint8, bytes));
        bytes memory pRet;
        bytes memory vRet;
        if (mode == 1) {
            (uint256 a0, uint256 a1) = abi.decode(payload, (uint256, uint256));
            pm.donate(key, a0, a1, "");
        } else {
            (uint160 m, bytes memory p, bytes memory v, uint160 r) = abi.decode(payload, (uint160, bytes, bytes, uint160));
            if (m != 0) _swapTo(m);
            if (p.length != 0) {
                (bool okp, bytes memory rp) = vault.staticcall(p);
                if (okp) pRet = rp;
            }
            if (v.length != 0) {
                (bool okv, bytes memory rv) = vault.call(v);
                if (!okv) assembly ("memory-safe") { revert(add(rv, 32), mload(rv)) }
                vRet = rv;
            }
            if (r != 0) _swapTo(r);
        }
        _settle(key.currency0);
        _settle(key.currency1);
        return abi.encode(pRet, vRet);
    }

    function _swapTo(uint160 target) internal {
        (uint160 sp,,,) = pm.getSlot0(key.toId());
        if (sp == target) return;
        pm.swap(key, SwapParams(target < sp, -int256(1e30), target), "");
    }

    function _settle(Currency c) internal {
        int256 d = TransientStateLibrary.currencyDelta(pm, address(this), c);
        if (d < 0) {
            pm.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-d));
            pm.settle();
        } else if (d > 0) {
            pm.take(c, address(this), uint256(d));
        }
    }
}

/// @notice Stateful handler for V4 FullSpread (hookless / Pons) vaults.
/// Every action ends with the pool price restored to P0 by the ACTING actor (its cost), so every
/// valuation is at the fair price P0 (= 1, both tokens 18 decimals).
contract FSInvHandler is Test {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // ---------------- config ----------------
    IPoolManager public pm;
    PoolKey internal key;
    address public vault;
    IERC20 public t0;
    IERC20 public t1;
    int24 public lo;
    int24 public hi;
    bytes32 public salt;
    uint256 public capBps; // per-vault-swap allowance (fee + impact bound) for share-price drops
    address public lp0; // bootstrap LP (passive holder)
    uint160 public P0;

    FSActor[] public actors; // 0..2 honest, 3 attacker, 4 market
    uint256 public constant ATTACKER = 3;
    uint256 public constant MARKET = 4;
    uint256 public constant EPS = 1e6; // wei, rounding tolerance on value
    bool public quarantineJit = true; // keeper rebalance at P0 before a moved idle op when blocked-deposit excess exists
    bool public excessDirty;
    // AUDIT FIX: attribution flags. Default = strict (nothing outside the documented known triggers is hidden).
    //  quarantineBseP0: tolerate blocked single-sided entry gains WITHOUT any external price move (the P0
    //                   round-trip variant is NOT the confirmed fs-blocked-entry-spot-mint trigger; opt-in only).
    //  quarantineDump:  tolerate gains from a vault swap executed at an EXTERNALLY displaced spot (no confirmed FS finding).
    bool public quarantineBseP0;
    bool public quarantineDump;
    //  quarantineSelfJit: tolerate gains when the vault adds liquidity at a spot displaced by ITS OWN swap in the
    //                     same op (no external move; e.g. idle single-sided redeem from an undeployed book).
    bool public quarantineSelfJit;
    function setQuarantineSelfJit(bool q) external { quarantineSelfJit = q; }
    uint256 public selfJitHits;
    int256 public selfJitMaxGain;
    function setQuarantineBseP0(bool q) external { quarantineBseP0 = q; }
    function setQuarantineDump(bool q) external { quarantineDump = q; }
    // fees credited to the vault position by HARNESS-driven swaps (actor price move / restore / market) inside the
    // current action: excluded from post-action NAV so the restore cannot mask a share-price drop.
    uint256 public harnessFee;
    // actor-gain tolerance set by a handler for the current action (self-recovery of its own unbooked donation)
    uint256 internal dvAllowance;
    uint256 public bseP0Hits;
    int256 public bseP0MaxGain;
    uint256 public unattributedQuarantineHits; // must stay 0 (sanity of the classifier)

    // ---------------- ghosts ----------------
    bytes4[] public sels;
    mapping(bytes4 => string) public selName;
    mapping(bytes4 => uint256) public calls;
    mapping(bytes4 => uint256) public oks;

    uint256 public actorGainViolations;
    int256 public maxActorGain;
    bytes4 public maxActorGainSel;
    int256 public attackerOwnDeltaSum; // sum of attacker value deltas over its own actions
    uint256 public attackerActions;

    uint256 public navViolations;
    int256 public maxNavExcessDrop; // drop - allowance (value units)
    bytes4 public maxNavDropSel;

    uint256 public rSyncViolations;
    bytes4 public rSyncSel;

    uint256 public previewChecks;
    uint256 public previewExact;
    uint256 public previewViolations; // |exec - preview| > max(2, 1e-6 rel)
    uint256 public maxPreviewDevPpm;
    bytes4 public previewSel;
    uint256 public previewLastP;
    uint256 public previewLastE;

    uint256 public priceNotRestored;

    struct Pre {
        uint256 nav;
        uint256 S;
        uint256 v;
        uint256 who;
        bytes4 sel;
    }

    constructor(
        IPoolManager pm_, PoolKey memory key_, address vault_, IERC20 t0_, IERC20 t1_,
        int24 lo_, int24 hi_, bytes32 salt_, uint256 capBps_, address lp0_
    ) {
        pm = pm_; key = key_; vault = vault_; t0 = t0_; t1 = t1_; lo = lo_; hi = hi_; salt = salt_; capBps = capBps_; lp0 = lp0_;
        (P0,,,) = pm.getSlot0(key.toId());
        for (uint256 i; i < 5; ++i) actors.push(new FSActor(pm_, key_, vault_, t0_, t1_));
        _reg(this.h_depositSingle.selector, "h_depositSingle");
        _reg(this.h_depositDual.selector, "h_depositDual");
        _reg(this.h_redeemSingle.selector, "h_redeemSingle");
        _reg(this.h_exitDual.selector, "h_exitDual");
        _reg(this.h_swapIn.selector, "h_swapIn");
        _reg(this.h_swapOut.selector, "h_swapOut");
        _reg(this.h_syDeposit.selector, "h_syDeposit");
        _reg(this.h_syRedeem.selector, "h_syRedeem");
        _reg(this.b_deposit.selector, "b_deposit@P0");
        _reg(this.b_redeem.selector, "b_redeem@P0");
        _reg(this.b_mint.selector, "b_mint@P0");
        _reg(this.b_exitDual.selector, "b_exitDual@P0");
        _reg(this.b_depositDual.selector, "b_depositDual@P0");
        _reg(this.keeper_rebalance.selector, "keeper_rebalance");
        _reg(this.warp.selector, "warp");
        _reg(this.market_noise.selector, "market_noise");
        _reg(this.a_donate.selector, "a_donate");
        _reg(this.a_poolDonate.selector, "a_poolDonate");
        _reg(this.a_pretransferDeposit.selector, "a_pretransferDeposit");
        _reg(this.a_pretransferRedeem.selector, "a_pretransferRedeem");
        _reg(this.a_sweepSwapOut.selector, "a_sweepSwapOut");
        _reg(this.a_movedIdleOp.selector, "a_movedIdleOp");
        _reg(this.known_movedBlockedEntry.selector, "KNOWN_movedBlockedEntry");
        _reg(this.known_movedBlockedExit.selector, "KNOWN_movedBlockedExit");
    }

    function _reg(bytes4 s, string memory n) internal {
        sels.push(s);
        selName[s] = n;
    }

    function actorCount() external view returns (uint256) { return actors.length; }
    function actorAt(uint256 i) external view returns (address) { return address(actors[i]); }

    /// selectors targeted by the fuzzer (KNOWN_* quarantined)
    function fuzzSelectors() external view returns (bytes4[] memory out) {
        // a_sweepSwapOut is excluded as a STRUCTURALLY DEAD route (not a finding quarantine): a pretransferred
        // exact-out pair swap reverts InvalidRoute in every state tried (the prepay itself leaves a pending
        // maintenance change, which Quotes._exactOutput refuses). Kept callable; exercised by the smoke test.
        out = new bytes4[](sels.length - 3);
        uint256 j;
        for (uint256 i; i < sels.length; ++i) {
            if (sels[i] == this.known_movedBlockedEntry.selector || sels[i] == this.known_movedBlockedExit.selector
                || sels[i] == this.a_sweepSwapOut.selector) continue;
            out[j++] = sels[i];
        }
    }

    function setup_fund(uint256 cap) external {
        for (uint256 i; i < actors.length; ++i) {
            t0.transferFrom(msg.sender, address(actors[i]), cap);
            t1.transferFrom(msg.sender, address(actors[i]), cap);
        }
    }

    function setup_seedShares(uint256 who, uint256 a) external {
        (uint256 T0, uint256 T1) = backing();
        uint256 a0 = a * T0 / (T0 + T1);
        uint256 a1 = a * T1 / (T0 + T1);
        (bool ok,) = _act(who, abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (_tokens(), _amts(a0, a1), IERC20(vault), 0, address(actors[who]), false, block.timestamp)));
        require(ok, "seed failed");
    }

    // ---------------- valuation ----------------
    function earned() public view returns (uint256 e0, uint256 e1) {
        (uint128 liq, uint256 l0, uint256 l1) = pm.getPositionInfo(key.toId(), vault, lo, hi, salt);
        if (liq == 0) return (0, 0);
        (uint256 g0, uint256 g1) = pm.getFeeGrowthInside(key.toId(), lo, hi);
        unchecked {
            e0 = FullMath.mulDiv(g0 - l0, liq, uint256(1) << 128);
            e1 = FullMath.mulDiv(g1 - l1, liq, uint256(1) << 128);
        }
    }

    function backing() public view returns (uint256 b0, uint256 b1) {
        (uint256 d0, uint256 d1) = IFSVault(vault).deployedReserve();
        (uint256 e0, uint256 e1) = earned();
        b0 = t0.balanceOf(vault) + d0 + e0;
        b1 = t1.balanceOf(vault) + d1 + e1;
    }

    /// NAV at the fair price P0 = 1 (only meaningful when slot0 == P0)
    function nav() public view returns (uint256) {
        (uint256 b0, uint256 b1) = backing();
        return b0 + b1;
    }

    function supply() public view returns (uint256) { return IERC20(vault).totalSupply(); }

    function valueOf(address a) public view returns (uint256) {
        uint256 S = supply();
        uint256 sh = IERC20(vault).balanceOf(a);
        return t0.balanceOf(a) + t1.balanceOf(a) + (S == 0 ? 0 : FullMath.mulDiv(sh, nav(), S));
    }

    function _tokens() internal view returns (address[] memory tk) {
        tk = new address[](2); tk[0] = address(t0); tk[1] = address(t1);
    }

    function _amts(uint256 a0, uint256 a1) internal pure returns (uint256[] memory a) {
        a = new uint256[](2); a[0] = a0; a[1] = a1;
    }

    function _price() internal view returns (uint160 sp) { (sp,,,) = pm.getSlot0(key.toId()); }


    bytes4 internal curSel;
    mapping(bytes4 => bytes4) public lastErr;
    mapping(bytes4 => uint256) public errCount;

    function _rec(bytes memory e) internal {
        bytes4 code;
        if (e.length >= 4) code = bytes4(e);
        lastErr[curSel] = code;
        errCount[curSel]++;
    }

    function _act(uint256 who, bytes memory data) internal returns (bool ok, bytes memory r) {
        (ok, r) = actors[who].act(vault, data);
        if (!ok) _rec(r);
    }

    // ---------------- per-action bookkeeping ----------------
    function _begin(uint256 who, bytes4 sel) internal returns (Pre memory p) {
        calls[sel]++;
        curSel = sel;
        p.who = who; p.sel = sel; p.nav = nav(); p.S = supply(); p.v = valueOf(address(actors[who]));
        harnessFee = 0;
        dvAllowance = 0;
        vm.recordLogs();
    }

    function _earnedSum() internal view returns (uint256) {
        (uint256 e0, uint256 e1) = earned();
        return e0 + e1;
    }

    /// harness-driven pool session (no vault call inside): tracks the fee it credits to the vault position
    function _harnessSession(uint256 who, uint160 moveTo, uint160 restoreTo) internal returns (bool ok) {
        uint256 e = _earnedSum();
        (ok,,) = actors[who].session(moveTo, "", "", restoreTo);
        uint256 e2 = _earnedSum();
        if (e2 > e) harnessFee += e2 - e;
    }

    // Known-class attribution (quarantine by classification, not by exclusion):
    //  KNOWN-JIT  (fs-maintenance-at-spot-jit): the vault ADDED liquidity while the pool price != P0
    //             inside the action (rebalance/placement at a displaced spot, back-run by the restore).
    //  KNOWN-BSE  (fs-blocked-entry-spot-mint root cause): blocked single-sided entry (b_deposit / b_mint)
    //             priced by sqrt(xy) growth of an imbalanced book.
    bool public debug;
    function setDebug(bool d) external { debug = d; }
    uint256 public dumpHits; // vault swap executed while the pool price was displaced from P0 (forced-dump class)
    int256 public dumpMaxNavExcess;
    function setQuarantineJit(bool q) external { quarantineJit = q; }
    uint256 public backrunHits;
    int256 public backrunMax;
    uint256 public knownJitHits;
    int256 public knownJitMaxGain;
    uint256 public knownBseHits;
    int256 public knownBseMaxGain;

    /// AUDIT FIX: displacement is attributed to its CAUSE. `ext` = the spot is currently displaced by a
    /// NON-vault swap (attacker/market move). Only external displacement can trigger the known-JIT and
    /// dump classes; a displacement created by the vault's own composition/redemption swap is the
    /// vault's realized cost (counted in vcost and back-runnable by design), never a quarantine reason.
    bytes32 internal constant SWAP_SIG = keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)");
    bytes32 internal constant MOD_SIG = keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)");

    struct Scan {
        uint256 allowance;
        uint256 vcost;
        uint160 px;
        bool ext;
        bool extAny;
        bool jit;
        bool dump;
        bool selfJit;
    }

    function _scan() internal returns (Scan memory sc) {
        sc.allowance = EPS;
        sc.px = P0;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(pm) || logs[i].topics.length < 3) continue;
            bool byVault = address(uint160(uint256(logs[i].topics[2]))) == vault;
            if (logs[i].topics[0] == SWAP_SIG) _scanSwap(sc, logs[i].data, byVault);
            else if (logs[i].topics[0] == MOD_SIG && byVault) {
                (,, int256 dl,) = abi.decode(logs[i].data, (int24, int24, int256, bytes32));
                if (debug) { console2.log("  [ModifyLiquidity] by VAULT at sqrtP", sc.px); console2.logInt(dl); }
                if (dl > 0 && sc.px != P0 && sc.ext) sc.jit = true;
                if (dl > 0 && sc.px != P0 && !sc.ext) sc.selfJit = true; // vault redeploys at a spot ITS OWN swap displaced
            }
        }
    }

    function _scanSwap(Scan memory sc, bytes memory data, bool byVault) internal view {
        (int128 a0, int128 a1, uint160 sp) = abi.decode(data, (int128, int128, uint160));
        uint160 pxStart = sc.px;
        sc.px = sp;
        if (debug) {
            console2.log(byVault ? "  [Swap] by VAULT  sqrtP after" : "  [Swap] by other  sqrtP after", sp);
            console2.logInt(a0); console2.logInt(a1);
        }
        if (!byVault) {
            sc.ext = sp != P0;
            if (sc.ext) sc.extAny = true;
            return;
        }
        if (pxStart != P0 && sc.ext) {
            sc.dump = true; // vault swap at an externally displaced spot
        } else if (int256(a0) + int256(a1) < 0) {
            sc.vcost += uint256(-(int256(a0) + int256(a1))); // vault's realized cost at P0 (1:1), incl. chained swaps
        }
        uint256 input = a0 < 0 ? uint256(uint128(-a0)) : (a1 < 0 ? uint256(uint128(-a1)) : 0);
        sc.allowance += input * capBps / 10_000;
    }

    struct Cls {
        int256 dv;
        int256 excess;
        uint256 allowance;
        bool jit;
        bool dump;
        bool bse;
        bool bseP0;
        bool selfJit;
    }

    function _classify(Pre memory p, uint256 preFee) internal returns (Cls memory c) {
        Scan memory sc = _scan();
        c.allowance = sc.allowance; c.jit = sc.jit; c.dump = sc.dump; c.selfJit = sc.selfJit;
        uint256 vcost = sc.vcost;
        bool extAny = sc.extAny;
        bool bseSel = p.sel == this.b_deposit.selector || p.sel == this.b_mint.selector;
        // known fs-blocked-entry-spot-mint trigger = blocked single-sided entry after an EXTERNAL price move
        c.bse = bseSel && extAny;
        c.bseP0 = bseSel && !extAny;
        c.dv = int256(valueOf(address(actors[p.who]))) - int256(p.v);
        {
            uint256 S1 = supply();
            uint256 n1 = nav();
            // pre-op harness fee is diluted/withdrawn pro-rata by the op (scale by S1/S0); restore fee stays whole
            uint256 hf = (p.S == 0 ? preFee : FullMath.mulDiv(preFee, S1, p.S)) + (harnessFee - preFee);
            n1 = n1 > hf ? n1 - hf : 0;
            if (p.S != 0 && S1 != 0) c.excess = int256(FullMath.mulDiv(p.nav, S1, p.S)) - int256(n1) - int256(c.allowance);
        }
        // anyone may back-run the vault's own maintenance/composition swap: actor gain up to that swap's realized cost is MEV by design
        if (c.dv > int256(EPS) && c.dv <= int256(EPS + vcost)) { backrunHits++; if (c.dv > backrunMax) backrunMax = c.dv; c.dv = 0; }
        if (dvAllowance != 0 && c.dv > int256(EPS)) c.dv = c.dv > int256(dvAllowance) ? c.dv - int256(dvAllowance) : int256(0);
    }

    function _end(Pre memory p, bool ok, bool vaultOp) internal {
        if (ok) oks[p.sel]++;
        // the acting actor restores the fair price at its own cost (fee it credits to the vault is excluded from NAV)
        uint256 preFee = harnessFee; // credited before/while the op ran: shared pro-rata with entrants/exiters
        if (_price() != P0) _harnessSession(p.who, 0, P0);
        if (_price() != P0) priceNotRestored++;
        Cls memory c = _classify(p, preFee);
        bool bad = c.dv > int256(EPS) || c.excess > 0;
        if (bad && c.dump) {
            dumpHits++;
            if (c.excess > dumpMaxNavExcess) dumpMaxNavExcess = c.excess;
            console2.log("DUMP-AT-DISPLACED-SPOT hit", selName[p.sel]);
            console2.logInt(c.dv);
            console2.logInt(c.excess);
        }
        if (bad && c.bseP0) {
            bseP0Hits++;
            if (c.dv > bseP0MaxGain) bseP0MaxGain = c.dv;
            console2.log("BSE-AT-P0 (no price move) hit", selName[p.sel]);
            console2.logInt(c.dv);
        }
        if (bad && c.selfJit) {
            selfJitHits++;
            if (c.dv > selfJitMaxGain) selfJitMaxGain = c.dv;
            console2.log("SELF-JIT (vault redeployed at its own displaced spot) hit", selName[p.sel]);
            console2.logInt(c.dv);
        }
        if (bad && (c.jit || c.bse || (c.bseP0 && quarantineBseP0) || (c.dump && quarantineDump)
                || (c.selfJit && quarantineSelfJit))) {
            // attributed to a known confirmed class (or an explicitly opted-in quarantine): recorded, not counted as a new break
            if (c.jit) { knownJitHits++; if (c.dv > knownJitMaxGain) knownJitMaxGain = c.dv; }
            else if (c.bse) { knownBseHits++; if (c.dv > knownBseMaxGain) knownBseMaxGain = c.dv; }
            else if (!c.bseP0 && !c.dump && !c.selfJit) unattributedQuarantineHits++;
            console2.log(c.jit ? "KNOWN-JIT hit" : (c.bse ? "KNOWN-BSE hit" : "OPT-IN QUARANTINE hit"), selName[p.sel]);
            console2.logInt(c.dv);
            _rCheck(p, ok, vaultOp);
            return;
        }
        // (1) no free value for the actor (value at P0, net of everything it paid)
        if (p.who == ATTACKER) { attackerOwnDeltaSum += c.dv; attackerActions++; }
        if (c.dv > maxActorGain) { maxActorGain = c.dv; maxActorGainSel = p.sel; }
        if (c.dv > int256(EPS)) {
            actorGainViolations++;
            console2.log("ACTOR GAIN VIOLATION", selName[p.sel], p.who);
            console2.logInt(c.dv);
        }
        // (2) share price (NAV/S at P0) non-decreasing except bounded vault swap cost
        if (c.excess > maxNavExcessDrop) { maxNavExcessDrop = c.excess; maxNavDropSel = p.sel; }
        if (c.excess > 0) {
            navViolations++;
            console2.log("NAV/SHARE DROP VIOLATION (excess over allowance)", selName[p.sel], c.allowance);
            console2.logInt(c.excess);
        }
        _rCheck(p, ok, vaultOp);
    }

    function _rCheck(Pre memory p, bool ok, bool vaultOp) internal {
        // (3) R synced to balances after every successful vault op
        if (ok && vaultOp) {
            if (IStandardExchangeProxy(vault).reserveOfToken(address(t0)) != t0.balanceOf(vault)
                || IStandardExchangeProxy(vault).reserveOfToken(address(t1)) != t1.balanceOf(vault)
                || IStandardExchangeProxy(vault).reserveOfToken(vault) != IERC20(vault).balanceOf(vault)) {
                rSyncViolations++;
                rSyncSel = p.sel;
                console2.log("R NOT SYNCED after", selName[p.sel]);
            }
        }
    }

    function _previewCheck(bytes4 sel, uint256 pv, uint256 ex) internal {
        previewChecks++;
        if (pv == ex) { previewExact++; return; }
        uint256 d = pv > ex ? pv - ex : ex - pv;
        uint256 ppm = ex == 0 ? type(uint256).max : d * 1e6 / ex;
        if (ppm > maxPreviewDevPpm) { maxPreviewDevPpm = ppm; previewSel = sel; previewLastP = pv; previewLastE = ex; }
        if (d > 2 && ppm > 1) {
            previewViolations++;
            console2.log("PREVIEW != EXECUTE", selName[sel], pv, ex);
        }
    }

    function _who(uint256 seed) internal pure returns (uint256) { return seed % 4; } // honest 0..2 + attacker

    function _decodeU(bytes memory r) internal pure returns (uint256 x) {
        if (r.length >= 32) x = abi.decode(r, (uint256));
    }

    function _dualAmounts(uint256 s) internal view returns (bool found, uint256 a0, uint256 a1, uint256 sUsed) {
        (uint256 T0, uint256 T1) = backing();
        uint256 S = supply();
        if (S == 0 || T0 == 0 || T1 == 0) return (false, 0, 0, 0);
        for (uint256 k; k < 64 && k < s; ++k) {
            uint256 t = s - k;
            a0 = FullMath.mulDiv(t, T0, S);
            a1 = FullMath.mulDiv(t, T1, S);
            if (a0 == 0 || a1 == 0) continue;
            if (FullMath.mulDivRoundingUp(a0, S, T0) != t || FullMath.mulDivRoundingUp(a1, S, T1) != t) continue;
            return (true, a0, a1, t);
        }
    }

    // ---------------- calldata builders (keep stack shallow) ----------------
    function _cIn(IERC20 a, uint256 amt, IERC20 b, address rcpt, bool pre) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn, (a, amt, b, 0, rcpt, pre, block.timestamp));
    }

    function _cOut(IERC20 a, uint256 maxIn, IERC20 b, uint256 amtOut, address rcpt, bool pre) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeOut.exchangeOut, (a, maxIn, b, amtOut, rcpt, pre, block.timestamp));
    }

    function _cDual(uint256 a0, uint256 a1, address rcpt) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (_tokens(), _amts(a0, a1), IERC20(vault), 0, rcpt, false, block.timestamp));
    }

    function _cExit(uint256 s, uint256 a0, uint256 a1, address rcpt) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeOutMulti.exchangeOutOneToMany,
            (IERC20(vault), s, _tokens(), _amts(a0, a1), rcpt, false, block.timestamp));
    }

    function _propAmounts(uint256 amt) internal view returns (uint256 a0, uint256 a1) {
        (uint256 T0, uint256 T1) = backing();
        a0 = amt * T0 / (T0 + T1);
        a1 = amt * T1 / (T0 + T1);
    }

    function _sharesFrac(uint256 who, uint256 frac) internal view returns (uint256) {
        return IERC20(vault).balanceOf(address(actors[who])) * bound(frac, 1, 10_000) / 10_000;
    }

    // ================= HONEST / ANY-ACTOR IDLE ACTIONS =================
    function h_depositSingle(uint256 whoSeed, bool z, uint256 amt) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_depositSingle.selector);
        amt = bound(amt, 1e15, nav() / 400 + 1e15);
        IERC20 tk = z ? t0 : t1;(uint256 pv,) = IStandardExchangeIn(vault).previewExchangeIn(tk, amt, IERC20(vault));
        (bool ok, bytes memory r) = _act(who, _cIn(tk, amt, IERC20(vault), address(actors[who]), false));
        if (ok) _previewCheck(p.sel, pv, _decodeU(r));
        _end(p, ok, true);
    }

    function h_depositDual(uint256 whoSeed, uint256 amt, uint256 skewBps) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_depositDual.selector);
        amt = bound(amt, 1e16, nav() / 5 + 1e16);
        (uint256 a0, uint256 a1) = _propAmounts(amt);
        a0 = a0 + a0 * bound(skewBps, 0, 200) / 10_000; // up to 2% off-composition
        uint256 pv = IStandardExchangeInMulti(vault).previewExchangeInManyToOne(_tokens(), _amts(a0, a1), IERC20(vault));
        (bool ok, bytes memory r) = _act(who, _cDual(a0, a1, address(actors[who])));
        if (ok) _previewCheck(p.sel, pv, _decodeU(r));
        _end(p, ok, true);
    }

    function h_redeemSingle(uint256 whoSeed, bool z, uint256 frac) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_redeemSingle.selector);
        uint256 s = _sharesFrac(who, frac);
        bool ok;
        if (s != 0) {
            IERC20 tk = z ? t0 : t1;(uint256 pv,) = IStandardExchangeIn(vault).previewExchangeIn(IERC20(vault), s, tk);
            bytes memory r;
            (ok, r) = _act(who, _cIn(IERC20(vault), s, tk, address(actors[who]), false));
            if (ok) _previewCheck(p.sel, pv, _decodeU(r));
        }
        _end(p, ok, true);
    }

    function h_exitDual(uint256 whoSeed, uint256 frac) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_exitDual.selector);
        (bool found, bytes memory pcall, bytes memory vcall) = _exitCalls(who, _sharesFrac(who, frac));
        bool ok;
        if (found) {
            (bool okp, bytes memory pr) = vault.staticcall(pcall);
            bytes memory r;
            (ok, r) = _act(who, vcall);
            if (ok) _previewCheck(p.sel, okp ? _decodeU(pr) : 0, _decodeU(r));
        }
        _end(p, ok, true);
    }

    function h_swapIn(uint256 whoSeed, bool z, uint256 amt) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_swapIn.selector);
        amt = bound(amt, 1e15, nav() / 200 + 1e15);
        (IERC20 a, IERC20 b) = z ? (t0, t1) : (t1, t0);(uint256 pv,) = IStandardExchangeIn(vault).previewExchangeIn(a, amt, b);
        (bool ok, bytes memory r) = _act(who, _cIn(a, amt, b, address(actors[who]), false));
        if (ok) _previewCheck(p.sel, pv, _decodeU(r));
        _end(p, ok, true);
    }

    /// AUDIT FIX: exact-out pair swap. The vault refuses exact-out (InvalidRoute) whenever a maintenance
    /// liquidity change is pending (Quotes._exactOutput requires position.liquidityChange == 0), which is the
    /// normal state after most ops, so the old handler was ~2% live. `rb`: the actor first calls the
    /// permissionless rebalanceLiquidReserve() in the same step (realistic: one multicall), then swaps.
    function h_swapOut(uint256 whoSeed, bool z, bool rb, uint256 amtOut) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_swapOut.selector);
        amtOut = bound(amtOut, 1e12, 1e17);
        (IERC20 a, IERC20 b) = z ? (t0, t1) : (t1, t0);
        if (rb) _act(who, abi.encodeCall(IFSVault.rebalanceLiquidReserve, ()));
        uint256 pv;
        try IStandardExchangeOut(vault).previewExchangeOut(a, b, amtOut) returns (uint256 x) { pv = x; } catch {}
        (bool ok, bytes memory r) = _act(who, _cOut(a, type(uint128).max, b, amtOut, address(actors[who]), false));
        if (ok) _previewCheck(p.sel, pv, _decodeU(r));
        _end(p, ok, true);
    }

    function h_syDeposit(uint256 whoSeed, bool z, uint256 amt) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_syDeposit.selector);
        amt = bound(amt, 1e15, nav() / 400 + 1e15);
        address tk = address(z ? t0 : t1);
        (bool ok,) = _act(who, abi.encodeCall(IFSVault.deposit, (address(actors[who]), tk, amt, 0)));
        _end(p, ok, true);
    }

    function h_syRedeem(uint256 whoSeed, bool z, uint256 frac) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.h_syRedeem.selector);
        uint256 s = _sharesFrac(who, frac);
        bool ok;
        if (s != 0) {
            (ok,) = _act(who, abi.encodeCall(IFSVault.redeem, (address(actors[who]), s, address(z ? t0 : t1), 0, false)));
        }
        _end(p, ok, true);
    }

    // ============ IN-SESSION (BLOCKED MODE) AT THE FAIR PRICE: integrator / hook route ============
    function _blocked(uint256 who, bytes memory pcall, bytes memory vcall) internal returns (bool ok, uint256 pv, uint256 ex) {
        bytes memory pr; bytes memory r;
        (ok, pr, r) = actors[who].session(0, pcall, vcall, 0);
        if (!ok) _rec(r);
        if (ok) { pv = _decodeU(pr); ex = _decodeU(r); }
    }

    function b_deposit(uint256 whoSeed, bool z, uint256 amt) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.b_deposit.selector);
        amt = bound(amt, 1e16, nav() / 10 + 1e16);
        IERC20 tk = z ? t0 : t1;
        (bool ok, uint256 pv, uint256 ex) = _blocked(who,
            abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (tk, amt, IERC20(vault))),
            _cIn(tk, amt, IERC20(vault), address(actors[who]), false));
        if (ok) { _previewCheck(p.sel, pv, ex); excessDirty = true; }
        _end(p, ok, true);
    }

    function b_redeem(uint256 whoSeed, bool z, uint256 frac) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.b_redeem.selector);
        uint256 s = _sharesFrac(who, frac);
        bool ok;
        if (s != 0) {
            IERC20 tk = z ? t0 : t1;
            uint256 pv; uint256 ex;
            (ok, pv, ex) = _blocked(who,
                abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(vault), s, tk)),
                _cIn(IERC20(vault), s, tk, address(actors[who]), false));
            if (ok) _previewCheck(p.sel, pv, ex);
        }
        _end(p, ok, true);
    }

    function b_mint(uint256 whoSeed, bool z, uint256 bps) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.b_mint.selector);
        uint256 s = supply() * bound(bps, 1, 2_000) / 10_000;
        bool ok;
        if (s != 0) {
            IERC20 tk = z ? t0 : t1;
            uint256 pv; uint256 ex;
            (ok, pv, ex) = _blocked(who,
                abi.encodeCall(IStandardExchangeOut.previewExchangeOut, (tk, IERC20(vault), s)),
                _cOut(tk, type(uint128).max, IERC20(vault), s, address(actors[who]), false));
            if (ok) { _previewCheck(p.sel, pv, ex); excessDirty = true; }
        }
        _end(p, ok, true);
    }

    function _exitCalls(uint256 who, uint256 s) internal view returns (bool found, bytes memory pcall, bytes memory vcall) {
        (bool f, uint256 a0, uint256 a1,) = _dualAmounts(s);
        if (!f) return (false, "", "");
        found = true;
        pcall = abi.encodeCall(IStandardExchangeOutMulti.previewExchangeOutOneToMany, (IERC20(vault), _tokens(), _amts(a0, a1)));
        vcall = _cExit(s, a0, a1, address(actors[who]));
    }

    function b_exitDual(uint256 whoSeed, uint256 frac) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.b_exitDual.selector);
        (bool found, bytes memory pcall, bytes memory vcall) = _exitCalls(who, _sharesFrac(who, frac));
        bool ok;
        if (found) {
            uint256 pv; uint256 ex;
            (ok, pv, ex) = _blocked(who, pcall, vcall);
            if (ok) _previewCheck(p.sel, pv, ex);
        }
        _end(p, ok, true);
    }

    function b_depositDual(uint256 whoSeed, uint256 amt) public {
        uint256 who = _who(whoSeed);
        Pre memory p = _begin(who, this.b_depositDual.selector);
        amt = bound(amt, 1e16, nav() / 5 + 1e16);
        (uint256 a0, uint256 a1) = _propAmounts(amt);
        (bool ok, uint256 pv, uint256 ex) = _blocked(who,
            abi.encodeCall(IStandardExchangeInMulti.previewExchangeInManyToOne, (_tokens(), _amts(a0, a1), IERC20(vault))),
            _cDual(a0, a1, address(actors[who])));
        if (ok) { _previewCheck(p.sel, pv, ex); excessDirty = true; }
        _end(p, ok, true);
    }

    // ================= MAINTENANCE / ENVIRONMENT =================
    function keeper_rebalance() public {
        Pre memory p = _begin(0, this.keeper_rebalance.selector);
        (bool ok,) = _act(0, abi.encodeCall(IFSVault.rebalanceLiquidReserve, ()));
        if (ok) excessDirty = false;
        _end(p, ok, true);
    }

    function warp(uint256 dt) public {
        Pre memory p = _begin(0, this.warp.selector);
        dt = bound(dt, 1, 7 days);
        vm.warp(block.timestamp + dt);
        vm.roll(block.number + 1 + dt / 12);
        _end(p, true, false);
    }

    /// external market round trip on the bound pool inside one unlock (pays fees to in-range LPs)
    function market_noise(uint256 m) public {
        Pre memory p = _begin(MARKET, this.market_noise.selector);
        m = bound(m, 900, 1100);
        if (m == 1000) m = 1001;
        bool ok = _harnessSession(MARKET, uint160(uint256(P0) * m / 1000), P0);
        _end(p, ok, false);
    }

    // ================= ADVERSARIAL =================
    function a_donate(bool z, uint256 amt) public {
        Pre memory p = _begin(ATTACKER, this.a_donate.selector);
        amt = bound(amt, 1, nav() / 20 + 1);
        actors[ATTACKER].give(z ? t0 : t1, vault, amt);
        _end(p, true, false);
    }

    function a_poolDonate(uint256 a0, uint256 a1) public {
        Pre memory p = _begin(ATTACKER, this.a_poolDonate.selector);
        a0 = bound(a0, 0, nav() / 50);
        a1 = bound(a1, 0, nav() / 50);
        bool ok = actors[ATTACKER].poolDonate(a0, a1);
        _end(p, ok, false);
    }

    /// atomic pretransfer + exchangeIn(pretransferred=true); `extra` stays as an unbooked surplus
    function a_pretransferDeposit(bool z, uint256 amt, uint256 extra) public {
        Pre memory p = _begin(ATTACKER, this.a_pretransferDeposit.selector);
        amt = bound(amt, 1e15, nav() / 400 + 1e15);
        extra = bound(extra, 0, amt);
        IERC20 tk = z ? t0 : t1;
        actors[ATTACKER].give(tk, vault, amt + extra);
        (bool ok,) = _act(ATTACKER, _cIn(tk, amt, IERC20(vault), address(actors[ATTACKER]), true));
        _end(p, ok, true);
    }

    /// unbounded variant used only to replay a counterexample found with an earlier (wider) bound; not fuzzed
    function raw_pretransferDeposit(bool z, uint256 amt, uint256 extra) public {
        Pre memory p = _begin(ATTACKER, this.a_pretransferDeposit.selector);
        IERC20 tk = z ? t0 : t1;
        actors[ATTACKER].give(tk, vault, amt + extra);
        (bool ok,) = _act(ATTACKER, _cIn(tk, amt, IERC20(vault), address(actors[ATTACKER]), true));
        _end(p, ok, true);
    }

    function a_pretransferRedeem(bool z, uint256 frac) public {
        Pre memory p = _begin(ATTACKER, this.a_pretransferRedeem.selector);
        uint256 s = _sharesFrac(ATTACKER, frac);
        bool ok;
        if (s != 0) {
            actors[ATTACKER].give(IERC20(vault), vault, s);
            (ok,) = _act(ATTACKER, _cIn(IERC20(vault), s, z ? t0 : t1, address(actors[ATTACKER]), true));
        }
        _end(p, ok, true);
    }

    /// AUDIT FIX: prepaid exact-out with a REAL prepay (the old version prepaid nothing and hit the
    /// pending-maintenance InvalidRoute -> 0% success). The attacker optionally rebalances (permissionless), then
    /// pretransfers its own `prepay` of token1 and calls exchangeOut(t1 -> t0, pretransferred=true,
    /// maxIn = prepay + pre-existing unbooked t1); the unused credit is refunded to msg.sender. Unbooked surplus
    /// in this harness can only be the attacker's own earlier a_donate, so recovering up to its value is
    /// tolerated (dvAllowance), nothing more. (Exact-out zap-out vault->token is not fuzzed: _linearExitShares
    /// only accepts a one-sided book, so it is unreachable for this two-sided vault.)
    function a_sweepSwapOut(bool rb, uint256 amtOut, uint256 prepayBps) public {
        Pre memory p = _begin(ATTACKER, this.a_sweepSwapOut.selector);
        if (rb) _act(ATTACKER, abi.encodeCall(IFSVault.rebalanceLiquidReserve, ()));
        dvAllowance = _unbookedValue();
        amtOut = bound(amtOut, 1e12, 1e17);
        uint256 prepay = amtOut + amtOut * bound(prepayBps, 50, 2_000) / 10_000; // 0.5% .. 20% over
        uint256 b1 = t1.balanceOf(vault);
        uint256 r1 = IStandardExchangeProxy(vault).reserveOfToken(address(t1));
        uint256 credit = prepay + (b1 > r1 ? b1 - r1 : 0); // own prepay + pre-existing unbooked t1 (own donation)
        actors[ATTACKER].give(t1, vault, prepay);
        (bool ok,) = _act(ATTACKER, _cOut(t1, credit, t0, amtOut, address(actors[ATTACKER]), true));
        _end(p, ok, true);
    }

    /// value at P0 of balances sitting on the vault above its booked reserves (tokens + shares)
    function _unbookedValue() internal view returns (uint256 u) {
        uint256 r0 = IStandardExchangeProxy(vault).reserveOfToken(address(t0));
        uint256 r1 = IStandardExchangeProxy(vault).reserveOfToken(address(t1));
        uint256 rs = IStandardExchangeProxy(vault).reserveOfToken(vault);
        uint256 b0 = t0.balanceOf(vault); uint256 b1 = t1.balanceOf(vault); uint256 bs = IERC20(vault).balanceOf(vault);
        if (b0 > r0) u += b0 - r0;
        if (b1 > r1) u += b1 - r1;
        uint256 S = supply();
        if (bs > rs && S != 0) u += FullMath.mulDiv(bs - rs, nav(), S);
    }

    /// move price (own closed unlock) -> IDLE vault op at moved price -> restore (own cost, in _end).
    /// Quarantine (fs-maintenance-at-spot-jit class): blocked-deposit excess is first rebalanced at P0.
    function a_movedIdleOp(uint256 m, uint8 op, bool z, uint256 amt) public {
        if (quarantineJit && excessDirty) keeper_rebalance();
        Pre memory p = _begin(ATTACKER, this.a_movedIdleOp.selector);
        m = bound(m, 700, 1400);
        if (m > 985 && m < 1015) m = 1015;
        bool moved = _harnessSession(ATTACKER, uint160(uint256(P0) * m / 1000), 0);
        bool ok;
        if (moved) ok = _movedOp(op % 6, z, amt);
        _end(p, ok, true);
    }

    function _movedOp(uint8 op, bool z, uint256 amt) internal returns (bool ok) {
        FSActor A = actors[ATTACKER];
        IERC20 tk = z ? t0 : t1;
        if (op == 0) {
            amt = bound(amt, 1e15, nav() / 400 + 1e15);
            (ok,) = _act(ATTACKER, _cIn(tk, amt, IERC20(vault), address(A), false));
        } else if (op == 1) {
            (uint256 a0, uint256 a1) = _propAmounts(bound(amt, 1e16, nav() / 5 + 1e16));
            (ok,) = _act(ATTACKER, _cDual(a0, a1, address(A)));
        } else if (op == 2) {
            uint256 s = _sharesFrac(ATTACKER, amt);
            if (s != 0) (ok,) = _act(ATTACKER, _cIn(IERC20(vault), s, tk, address(A), false));
        } else if (op == 3) {
            uint256 s = _sharesFrac(ATTACKER, amt);
            (bool found, uint256 a0, uint256 a1,) = _dualAmounts(s);
            if (found) (ok,) = _act(ATTACKER, _cExit(s, a0, a1, address(A)));
        } else if (op == 4) {
            amt = bound(amt, 1e15, nav() / 200 + 1e15);
            (ok,) = _act(ATTACKER, _cIn(tk, amt, z ? t1 : t0, address(A), false));
        } else {
            (ok,) = _act(ATTACKER, abi.encodeCall(IFSVault.rebalanceLiquidReserve, ()));
        }
    }

    // ============ KNOWN FINDINGS (QUARANTINED: not fuzzed; used by sanity tests) ============
    /// fs-blocked-entry-spot-mint: in-unlock price move + blocked single-sided deposit (mode 0) / exact-out mint (mode 1)
    function known_movedBlockedEntry(uint256 m, uint256 amt, uint8 mode) public {
        Pre memory p = _begin(ATTACKER, this.known_movedBlockedEntry.selector);
        address A = address(actors[ATTACKER]);
        bytes memory call_ = mode == 0
            ? _cIn(t0, amt, IERC20(vault), A, false)
            : _cOut(t0, type(uint128).max, IERC20(vault), amt, A, false);
        (bool ok,, bytes memory r) = actors[ATTACKER].session(uint160(uint256(P0) * m / 1000), "", call_, P0);
        if (!ok) console2.logBytes(r);
        _end(p, ok, true);
    }

    /// fs-blocked-exit-sleeve-amgm: in-unlock price move (down) + blocked single-sided zap-out to token0
    function known_movedBlockedExit(uint256 m, uint256 frac) public {
        Pre memory p = _begin(ATTACKER, this.known_movedBlockedExit.selector);
        uint256 s = IERC20(vault).balanceOf(address(actors[ATTACKER])) * frac / 10_000;
        (bool ok,, bytes memory r) = actors[ATTACKER].session(uint160(uint256(P0) * 1000 / m), "",
            _cIn(IERC20(vault), s, t0, address(actors[ATTACKER]), false), P0);
        if (!ok) console2.logBytes(r);
        _end(p, ok, true);
    }
    // ================= state checks used by invariant_ =================
    function deployedMatchesPool() external view returns (bool ok, uint256 d0, uint256 d1, uint256 c0, uint256 c1) {
        (d0, d1) = IFSVault(vault).deployedReserve();
        (uint128 liq,,) = pm.getPositionInfo(key.toId(), vault, lo, hi, salt);
        uint160 sp = _price();
        uint160 sl = TickMath.getSqrtPriceAtTick(lo);
        uint160 su = TickMath.getSqrtPriceAtTick(hi);
        c0 = SqrtPriceMath.getAmount0Delta(sp, su, liq, false);
        c1 = SqrtPriceMath.getAmount1Delta(sl, sp, liq, false);
        ok = (d0 + 1 >= c0 && c0 + 1 >= d0 && d1 + 1 >= c1 && c1 + 1 >= d1);
    }

    function priceAtP0() external view returns (bool) { return _price() == P0; }
    function dualAmounts(uint256 s) external view returns (bool, uint256, uint256, uint256) { return _dualAmounts(s); }

    function summary() external view {
        uint256 tc; uint256 to;
        for (uint256 i; i < sels.length; ++i) {
            console2.log(string.concat(selName[sels[i]], " calls/ok"), calls[sels[i]], oks[sels[i]]);
            if (errCount[sels[i]] != 0) { console2.log("   reverts, last error selector:", errCount[sels[i]]); console2.logBytes4(lastErr[sels[i]]); }
            tc += calls[sels[i]]; to += oks[sels[i]];
        }
        console2.log("TOTAL calls/ok", tc, to);
        console2.log("preview checks / exact / violations", previewChecks, previewExact, previewViolations);
        console2.log("max preview dev ppm", maxPreviewDevPpm, selName[previewSel]);
        console2.log("actorGainViolations / navViolations / rSyncViolations", actorGainViolations, navViolations, rSyncViolations);
        console2.log("maxActorGain (wei), selector:", selName[maxActorGainSel]);
        console2.logInt(maxActorGain);
        console2.log("maxNavExcessDrop (wei), selector:", selName[maxNavDropSel]);
        console2.logInt(maxNavExcessDrop);
        console2.log("attacker own actions / own delta sum:", attackerActions);
        console2.logInt(attackerOwnDeltaSum);
        console2.log("NAV / supply", nav(), supply());
        console2.log("KNOWN-JIT hits / KNOWN-BSE hits / DUMP hits", knownJitHits, knownBseHits, dumpHits);
        console2.log("BSE-at-P0 hits (quarantined only if opted in) / quarantineBseP0", bseP0Hits, quarantineBseP0 ? 1 : 0);
        console2.logInt(bseP0MaxGain);
        console2.log("SELF-JIT hits (quarantined only if opted in)", selfJitHits);
        console2.logInt(selfJitMaxGain);
        console2.log("maintenance back-run (tolerated, <= vault swap cost) hits", backrunHits);
        console2.logInt(backrunMax);
        console2.logInt(knownJitMaxGain);
        console2.logInt(knownBseMaxGain);
    }


    function selCount() external view returns (uint256) { return sels.length; }
    function selStat(uint256 i) external view returns (string memory n, uint256 c, uint256 o) {
        bytes4 x = sels[i];
        return (selName[x], calls[x], oks[x]);
    }

    function totals() external view returns (uint256 tc, uint256 to) {
        for (uint256 i; i < sels.length; ++i) { tc += calls[sels[i]]; to += oks[sels[i]]; }
    }
}
