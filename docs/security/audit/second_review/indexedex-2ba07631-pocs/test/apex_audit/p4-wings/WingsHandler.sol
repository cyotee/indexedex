// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as IWings} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Q} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";
import {WingsAdversary, WingsPushRouter, IJitObserver} from "./WingsAdversary.sol";

/// @notice Stateful handler for the UpperLowerWings vault pair (wings0 = target token0, wings1 = target token1,
///         same hookless V4 pool). Honest actions run only in CLEAN states (pool at fair price p0, no adversary
///         liquidity). Adversary actions are atomic: manipulate -> (vault-touching non-share action) -> restore.
///
/// QUARANTINE (known confirmed findings, so the fuzzer hunts new bugs):
///  - wings-spot-nav (JIT/spot NAV): adversary never holds shares and never deposits/redeems in a manipulated
///    state; honest deposit/redeem only at p0 with baseline depth. `unsafeJitDepositRedeem` is NOT targeted.
///  - wings-forced-dump: every honest share op is first probed in a reverting frame; if the vault itself emitted
///    a PoolManager Swap (only `_swapDeficit` swaps on the redeem path), the op is STILL EXECUTED and the
///    redeemer-side no-free-value check + all conservation/valuation invariants still apply; only the
///    remaining-holder NAV/share checks (the finding itself) are skipped. The independent arb then restores p0 and
///    the staying-holder fair-mark loss is metered (dumpMaxLossBps), never asserted.
///  - R1/R2 (p4-discovered, NOT p3-confirmed; PoCs in WingsRebalanceBackrun/WingsRebalanceSandwich): metered only.
///  - wings-quote-step-cap-dos: no dust/1-wei ticks are ever created (adversary L >= 1e15, <= 1 extra range at a
///    time, spacing 60); any QuoteWorkExceeded is counted as quarantined, never as a liveness break.
contract WingsHandler is Test, IJitObserver {
    using StateLibrary for IPoolManager;

    error ProbeResult(bool ok, bool dumped, bytes err);

    bytes32 internal constant SWAP_SIG = keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)");
    uint160 public constant P0 = uint160(1) << 96;
    uint256 internal constant TOL_ABS = 1000;

    IPoolManager public pool;
    PoolKey internal key;
    PoolId internal id;
    ERC20PermitMintableStub public token0;
    ERC20PermitMintableStub public token1;
    IWings[2] public vaults;
    Actor public arb;
    WingsAdversary public adv;
    WingsPushRouter public router;
    address[3] public users;
    address public anchor;

    // ---- ghosts ----
    bytes4[] public selectorList;
    mapping(bytes4 => uint256) public attempts;
    mapping(bytes4 => uint256) public successes;
    mapping(bytes4 => uint256) public quarantined;
    uint256 public violations;
    string public firstViolation;
    uint256 public violationA;
    uint256 public violationB;
    uint256[2][2] public excess;        // [vault][token] unbooked balance (donations) ghost
    uint256 public advInitial;
    uint256 public advAcceptedLoss;     // sum of liquidation-value losses the vault itself accepted on adversary rebalances
    uint256 public advRebalanceCap;     // sum of the vault's designed rebalance loss caps (1% of progress) on adversary rebalances
    uint256 internal actionCap;         // same, within the current adversary action
    uint256 public advAllowance;        // sum of per-action allowed adversary profit
    uint256 public r1Count;             // clean-rebalance back-runs whose profit exceeded the designed cap (finding R1)
    uint256 public r1MaxExcess;
    uint256 public r2Count;             // price-pushed rebalances beyond max(cap, clean baseline) (finding R2)
    uint256 public r2MaxExcess;
    uint256 public maxGriefBps;
    uint256 public quarantinedDump;
    uint256 public quarantinedQuoteWork;
    uint256 public advRebalanceOk;
    uint256 public honestValueIn;       // ghost: target units paid by honest actors
    uint256 public honestValueOut;      // ghost: target units received by honest actors
    uint256[2] internal vClean;         // per-vault V before the current JIT unlock
    uint256[2] internal vStage0;
    // ---- audit-added ghosts (non-vacuity of rebalance paths, dump path metering) ----
    mapping(bytes4 => uint256) public noop;   // rebalance-type calls where no rebalance actually landed
    uint256 internal actionRbOk;               // rebalances landed within the current adversary action
    uint256 public advRbNoProgress;
    uint256 public advRbLossExceeded;
    uint256 public advRbOther;
    uint256 public kNoProgress;
    uint256 public kOther;
    uint256 public dumpExecuted;              // dump-path honest ops executed (partial checks)
    uint256 public dumpMaxLossBps;            // metered staying-holder fair-mark loss on dump path (finding wings-forced-dump)
    int256 public dumpArbPnL;                 // arb PnL restoring p0 after dumps (leakage, metered)
    uint256 public advQuarantinedProfit;      // profit admitted only because of R1/R2 quarantine
    bytes public firstOtherRevert;

    constructor(
        IPoolManager pool_, PoolKey memory key_, ERC20PermitMintableStub t0_, ERC20PermitMintableStub t1_, IWings w0_, IWings w1_
    ) {
        pool = pool_; key = key_; id = key_.toId(); token0 = t0_; token1 = t1_;
        vaults[0] = w0_; vaults[1] = w1_;
        arb = new Actor(pool_, address(this));
        adv = new WingsAdversary(pool_, key_, address(this));
        router = new WingsPushRouter();
        token0.mint(address(arb), 1e27); token1.mint(address(arb), 1e27);
        token0.mint(address(adv), 1e24); token1.mint(address(adv), 1e24);
        advInitial = 2e24;
        users[0] = makeAddr("alice"); users[1] = makeAddr("bob"); users[2] = makeAddr("carol");
        anchor = makeAddr("anchor");
        for (uint256 u; u < 3; ++u) _approveAll(users[u]);
        _approveAll(anchor);
    }

    function _approveAll(address who_) internal {
        vm.startPrank(who_);
        token0.approve(address(vaults[0]), type(uint256).max); token1.approve(address(vaults[0]), type(uint256).max);
        token0.approve(address(vaults[1]), type(uint256).max); token1.approve(address(vaults[1]), type(uint256).max);
        vm.stopPrank();
    }

    function registerSelectors(bytes4[] memory s_) external { for (uint256 i; i < s_.length; ++i) selectorList.push(s_[i]); }
    function selectorCount() external view returns (uint256) { return selectorList.length; }

    // =====================================================================================================
    // setup helpers (called by the test in setUp)
    // =====================================================================================================
    function seed(uint256 amount_) external {
        for (uint8 vi; vi < 2; ++vi) {
            IERC20 t = _target(vi);
            ERC20PermitMintableStub(address(t)).mint(anchor, amount_);
            vm.prank(anchor);IStandardExchangeIn(address(vaults[vi])).exchangeIn(t, amount_, IERC20(address(vaults[vi])), 0, anchor, false, block.timestamp);
        }
        for (uint256 r; r < 4; ++r) {
            for (uint8 vi; vi < 2; ++vi) { try Rebalance(address(vaults[vi])).rebalance(0, block.timestamp) returns (uint256) {} catch {} }
            _arbToFair();
        }
        _arbToFair();
    }

    // =====================================================================================================
    // HONEST actions (clean state in, clean state out)
    // =====================================================================================================
    struct H { bytes4 sel; address caller; address callee; bytes data; uint8 vi; bool deposit; address payer; address holder; }
    struct Snap { uint256 v; uint256 s; uint256 tok; uint256 shares; bool ok; }

    function h_deposit(uint256 u_, uint256 v_, uint256 amt_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 amt = bound(amt_, 1e9, 5e16);
        ERC20PermitMintableStub(address(_target(vi))).mint(u, amt);
        _runHonest(H(msg.sig, u, address(vaults[vi]), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (_target(vi), amt, IERC20(address(vaults[vi])), 0, u, false, block.timestamp)), vi, true, u, u));
    }

    function h_redeem(uint256 u_, uint256 v_, uint256 bps_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 sh = IERC20(address(vaults[vi])).balanceOf(u) * bound(bps_, 1, 10_000) / 10_000;
        if (sh == 0) { _seedUser(u, vi); sh = IERC20(address(vaults[vi])).balanceOf(u) / 2; }
        if (sh == 0) return;
        _runHonest(H(msg.sig, u, address(vaults[vi]), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(vaults[vi])), sh, _target(vi), 0, u, false, block.timestamp)), vi, false, u, u));
    }

    function h_depositExactShares(uint256 u_, uint256 v_, uint256 shares_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 sharesOut = bound(shares_, 1e9, 5e16);
        uint256 need;
        try IStandardExchangeOut(address(vaults[vi])).previewExchangeOut(_target(vi), IERC20(address(vaults[vi])), sharesOut) returns (uint256 n) {
            need = n;
        } catch (bytes memory e) { _classifyPreview(msg.sig, e); return; }
        ERC20PermitMintableStub(address(_target(vi))).mint(u, need);
        _runHonest(H(msg.sig, u, address(vaults[vi]), abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (_target(vi), need, IERC20(address(vaults[vi])), sharesOut, u, false, block.timestamp)), vi, true, u, u));
    }

    function h_redeemExactAssets(uint256 u_, uint256 v_, uint256 bps_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 sh = IERC20(address(vaults[vi])).balanceOf(u);
        if (sh == 0) { _seedUser(u, vi); sh = IERC20(address(vaults[vi])).balanceOf(u); }
        if (sh == 0) return;
        uint256 ent;try IStandardExchangeIn(address(vaults[vi])).previewExchangeIn(IERC20(address(vaults[vi])), sh, _target(vi)) returns (uint256 e, uint256) {
            ent = e;
        } catch (bytes memory e) { _classifyPreview(msg.sig, e); return; }
        uint256 out = ent * bound(bps_, 1, 9_990) / 10_000;
        if (out == 0) return;
        _runHonest(H(msg.sig, u, address(vaults[vi]), abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(vaults[vi])), sh, _target(vi), out, u, false, block.timestamp)), vi, false, u, u));
    }

    function h_syDeposit(uint256 u_, uint256 v_, uint256 amt_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 amt = bound(amt_, 1e9, 5e16);
        ERC20PermitMintableStub(address(_target(vi))).mint(u, amt);
        _runHonest(H(msg.sig, u, address(vaults[vi]), abi.encodeWithSignature("deposit(address,address,uint256,uint256)",
            u, address(_target(vi)), amt, uint256(0)), vi, true, u, u));
    }

    function h_syRedeem(uint256 u_, uint256 v_, uint256 bps_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 sh = IERC20(address(vaults[vi])).balanceOf(u) * bound(bps_, 1, 10_000) / 10_000;
        if (sh == 0) { _seedUser(u, vi); sh = IERC20(address(vaults[vi])).balanceOf(u) / 3; }
        if (sh == 0) return;
        _runHonest(H(msg.sig, u, address(vaults[vi]), abi.encodeWithSignature("redeem(address,uint256,address,uint256,bool)",
            u, sh, address(_target(vi)), uint256(0), false), vi, false, u, u));
    }

    function h_routerPushedDeposit(uint256 u_, uint256 v_, uint256 amt_) external {
        uint8 vi = uint8(v_ % 2); address u = users[u_ % 3];
        uint256 amt = bound(amt_, 1e9, 5e16);
        ERC20PermitMintableStub(address(_target(vi))).mint(address(router), amt);
        _runHonest(H(msg.sig, u, address(router), abi.encodeCall(WingsPushRouter.pushDeposit,
            (address(vaults[vi]), _target(vi), amt, u)), vi, true, address(router), u));
    }

    /// @notice Honest keeper rebalance in a clean state, followed by an independent arbitrageur restoring p0.
    function k_rebalance(uint256 v_) external {
        uint8 vi = uint8(v_ % 2);
        ++attempts[msg.sig];
        try Rebalance(address(vaults[vi])).rebalance(0, block.timestamp) returns (uint256) { ++successes[msg.sig]; }
        catch (bytes memory e) {
            bytes4 es = _sel(e);
            if (_isQuoteWork(e)) { ++quarantined[msg.sig]; ++quarantinedQuoteWork; }
            else if (es == Rebalance.NoRebalanceProgress.selector) { ++noop[msg.sig]; ++kNoProgress; }
            else if (es == bytes4(0x4e487b71)) _fail(string.concat("keeper rebalance PANIC at clean state ", vm.toString(e)), vi, 0);
            else { ++kOther; if (firstOtherRevert.length == 0) firstOtherRevert = e; }
        }
        _arbToFair();
    }

    function warp(uint256 dt_) external {
        ++attempts[msg.sig];
        vm.warp(block.timestamp + bound(dt_, 1, 3 days));
        vm.roll(block.number + 1);
        ++successes[msg.sig];
    }

    // =====================================================================================================
    // ADVERSARY actions (atomic; adversary never holds shares)
    // =====================================================================================================
    struct AdvSnap { uint256[2] markNum; uint256[2] supply; int256 pnl; int256 baseProfit; uint256 baseLoss; bool r1; bool r2; }

    /// @dev Counterfactual baseline: the SAME vault rebalanced at the clean price and back-run (no manipulation),
    ///      evaluated inside a snapshot and reverted. Manipulated actions are only flagged if they extract more
    ///      than max(designed cap, clean baseline) -- the clean-rebalance excess is finding R1 (quarantined here).
    function _baseline(uint8 vi_) internal returns (int256 prof_, uint256 loss_) {
        uint256 snap = vm.snapshotState();
        int256 p0 = advPnL(); uint256 m0 = _markSum();
        _advRebalance(vi_);
        _advRestore();
        prof_ = advPnL() - p0;
        uint256 m1 = _markSum();
        loss_ = m0 > m1 ? m0 - m1 : 0;
        vm.revertToState(snap);
    }

    function _markSum() internal view returns (uint256 m_) {
        for (uint8 vi; vi < 2; ++vi) { (uint256 a0, uint256 a1,) = inventory(vi); m_ += a0 + a1; }
    }

    function a_swapRoundTrip(bool zf_, uint256 amt_) external {
        ++attempts[msg.sig];
        AdvSnap memory b = _advBegin();
        adv.swap(zf_, bound(amt_, 1e13, 4e17), zf_ ? 4295128740 : 1461446703485210103287273052203988822378723970341);
        _advRestore();
        _advEnd(b, msg.sig);
    }

    /// @notice Push price, call permissionless rebalance on the moved pool (H2 rebalance path), back-run to p0.
    function a_swapRebalanceRestore(uint256 v_, bool zf_, uint256 amt_, uint8 n_) external {
        ++attempts[msg.sig];
        uint8 vi = uint8(v_ % 2);
        (int256 bp, uint256 bl) = _baseline(vi);
        AdvSnap memory b = _advBegin();
        b.baseProfit = bp; b.baseLoss = bl;
        b.r2 = true; // finding R2 (price-pushed rebalance sells pending target cash) is quarantined, metered only
        adv.swap(zf_, bound(amt_, 1e13, 4e17), zf_ ? 4295128740 : 1461446703485210103287273052203988822378723970341);
        uint256 n = bound(n_, 1, 3);
        for (uint256 i; i < n; ++i) _advRebalance(vi);
        _advRestore();
        _advEndRb(b, msg.sig);
    }

    /// @notice Rebalance at the clean fair price, adversary back-runs the vault's own swap.
    function a_rebalanceBackrun(uint256 v_) external {
        ++attempts[msg.sig];
        uint8 vi = uint8(v_ % 2);
        AdvSnap memory b = _advBegin();
        b.r1 = true; // finding R1 (clean-state rebalance back-run beyond the designed cap) is quarantined, metered only
        _advRebalance(vi);
        _advRestore();
        _advEndRb(b, msg.sig);
    }

    /// @notice Add liquidity (settled, own capital), optionally push price, rebalance against the altered depth,
    ///         restore price, remove liquidity.
    function a_jitSwapRebalanceRestore(uint256 v_, uint256 range_, uint256 l_, bool zf_, uint256 amt_) external {
        ++attempts[msg.sig];
        uint8 vi = uint8(v_ % 2);
        (int24 lo, int24 up) = _range(range_);
        uint256 l = bound(l_, 1e15, 1e19);
        (int256 bp, uint256 bl) = _baseline(vi);
        AdvSnap memory b = _advBegin();
        b.baseProfit = bp; b.baseLoss = bl;
        adv.modify(lo, up, int256(l));
        b.r2 = amt_ % 4 != 0; // push present -> R2 path (quarantined); JIT-only stays strict
        if (amt_ % 4 != 0) adv.swap(zf_, bound(amt_, 1e13, 4e17), zf_ ? 4295128740 : 1461446703485210103287273052203988822378723970341);
        _advRebalance(vi);
        _advRestore();
        adv.modify(lo, up, -int256(l));
        _advEndRb(b, msg.sig);
    }

    /// @notice In the adversary's own unlock: JIT depth + price move, observing both vaults' valuation (no share ops).
    function a_inUnlockView(uint256 range_, uint256 l_, bool zf_, uint256 amt_) external {
        ++attempts[msg.sig];
        (int24 lo, int24 up) = _range(range_);
        uint256 l = bound(l_, 1e15, 1e19);
        uint256 amt = amt_ % 5 == 0 ? 0 : bound(amt_, 1e13, 4e17);
        AdvSnap memory b = _advBegin();
        for (uint8 vi; vi < 2; ++vi) vClean[vi] = _value(vi);
        adv.jitView(lo, up, l, zf_, amt, P0);
        _advEnd(b, msg.sig);
    }

    function a_donate(uint256 v_, bool token0_, uint256 amt_) external {
        ++attempts[msg.sig];
        uint8 vi = uint8(v_ % 2);
        uint256 amt = bound(amt_, 1, 1e16);
        AdvSnap memory b = _advBegin();
        vm.prank(address(adv));
        (token0_ ? IERC20(address(token0)) : IERC20(address(token1))).transfer(address(vaults[vi]), amt);
        excess[vi][token0_ ? 0 : 1] += amt;
        _advEnd(b, msg.sig);
    }

    // ---- in-unlock observer ----
    function onJit(uint8 stage_) external {
        require(msg.sender == address(adv), "observer");
        for (uint8 vi; vi < 2; ++vi) {
            (uint8 code, uint256 x, uint256 y) = valuationCheck(vi);
            if (code == 2) { ++quarantinedQuoteWork; continue; }
            if (code != 0) { _fail(string.concat("valuation-in-unlock code ", vm.toString(code), " stage ", vm.toString(stage_)), x, y); continue; }
            uint256 v = _value(vi);
            if (stage_ == 0) {
                vStage0[vi] = v;
                // valuation monotone in external depth: adding liquidity at unchanged price cannot cut V
                if (v + _tol(v) < vClean[vi]) _fail("V decreased after external liquidity ADD at same price", vClean[vi], v);
            } else if (stage_ == 2) {
                // swap round trip back to the same price/depth: owned positions are path independent + fees
                if (v + _tol(v) < vStage0[vi]) _fail("V decreased after in-unlock round trip to same price/depth", vStage0[vi], v);
            }
        }
    }

    // =====================================================================================================
    // views used by invariants
    // =====================================================================================================
    /// @return code 0 ok, 1 quote reverted (unexpected), 2 QuoteWorkExceeded (known), 3 target total mismatch,
    ///         4 opposing total mismatch, 5 proceeds above spot value, 6 repo/manager position mismatch
    function valuationCheck(uint8 vi_) public view returns (uint8 code, uint256 x, uint256 y) {
        IWings v = vaults[vi_];
        (uint256 a0, uint256 a1, bool posOk) = inventory(vi_);
        if (!posOk) return (6, 0, 0);
        Q.Result memory r;
        try v.liquidationValue() returns (Q.Result memory rr) { r = rr; }
        catch (bytes memory e) { return (_isQuoteWork(e) ? 2 : 1, 0, 0); }
        bool t0 = vi_ == 0;
        uint256 tT = t0 ? a0 : a1;
        uint256 oT = t0 ? a1 : a0;
        if (_absDiff(r.value - r.proceeds, tT) > 2) return (3, r.value - r.proceeds, tT);
        if (_absDiff(r.sold + r.unsold, oT) > 2) return (4, r.sold + r.unsold, oT);
        (uint160 sp,,,) = pool.getSlot0(id);
        uint256 bound_ = t0 ? FullMath.mulDiv(FullMath.mulDiv(r.sold, 1 << 96, sp), 1 << 96, sp)
            : FullMath.mulDiv(FullMath.mulDiv(r.sold, sp, 1 << 96), sp, 1 << 96);
        if (r.proceeds > bound_ + 2) return (5, r.proceeds, bound_);
        return (0, 0, 0);
    }

    /// @notice Independent inventory: booked locals + manager-reported positions at spot + uncollected fees.
    function inventory(uint8 vi_) public view returns (uint256 a0, uint256 a1, bool posOk) {
        (a0, a1) = vaults[vi_].localReserves();
        posOk = true;
        for (uint8 i; i < 3; ++i) {
            (uint256 x0, uint256 x1, bool ok) = _positionInventory(vaults[vi_], i);
            a0 += x0; a1 += x1;
            if (!ok) posOk = false;
        }
    }

    function _positionInventory(IWings v_, uint8 i_) internal view returns (uint256 x0, uint256 x1, bool ok) {
        ok = true;
        (int24 lo, int24 up, uint128 liq, bytes32 salt) = v_.position(i_);
        if (liq == 0 && lo == 0 && up == 0) return (0, 0, true);
        (uint128 actual, uint256 l0, uint256 l1) = pool.getPositionInfo(id, address(v_), lo, up, salt);
        if (actual != liq) ok = false;
        if (actual == 0) return (0, 0, ok);
        (uint160 sp,,,) = pool.getSlot0(id);
        Types.Principal memory p = Inventory.principal(sp, lo, up, actual, false);
        (uint256 g0, uint256 g1) = pool.getFeeGrowthInside(id, lo, up);
        x0 = p.amount0 + Inventory.earnedFee(actual, g0, l0);
        x1 = p.amount1 + Inventory.earnedFee(actual, g1, l1);
    }

    function conservationCheck(uint8 vi_) public view returns (bool ok, string memory why) {
        IWings v = vaults[vi_];
        (uint256 l0, uint256 l1) = v.localReserves();
        if (token0.balanceOf(address(v)) != l0 + excess[vi_][0]) return (false, "token0 balance != local0 + donations");
        if (token1.balanceOf(address(v)) != l1 + excess[vi_][1]) return (false, "token1 balance != local1 + donations");
        IERC20 s = IERC20(address(v));
        uint256 sum = s.balanceOf(anchor) + s.balanceOf(address(v)) + s.balanceOf(address(router)) + s.balanceOf(address(adv));
        for (uint256 u; u < 3; ++u) sum += s.balanceOf(users[u]);
        if (sum != s.totalSupply()) return (false, "share balances != totalSupply");
        if (s.balanceOf(address(adv)) != 0) return (false, "adversary holds shares");
        if (s.balanceOf(anchor) == 0) return (false, "anchor lost shares");
        return (true, "");
    }

    function advPnL() public view returns (int256) {
        return int256(token0.balanceOf(address(adv)) + token1.balanceOf(address(adv))) - int256(advInitial);
    }
    function advTolerance() public view returns (uint256) { return advAllowance + TOL_ABS; }

    function isClean() public view returns (bool) {
        (uint160 p,,,) = pool.getSlot0(id);
        (uint128 a,,) = pool.getPositionInfo(id, address(adv), -887220, 887220, adv.JIT_SALT());
        return p == P0 && a == 0;
    }

    function logStats() external view {
        console2.log("=== per-selector attempts / successes / quarantined ===");
        uint256 ta; uint256 ts;
        for (uint256 i; i < selectorList.length; ++i) {
            bytes4 s = selectorList[i];
            console2.log(string.concat(vm.toString(abi.encodePacked(s)), " att/succ/quar/noop ", vm.toString(attempts[s]), "/", vm.toString(successes[s]), "/", string.concat(vm.toString(quarantined[s]), "/", vm.toString(noop[s]))));
            ta += attempts[s]; ts += successes[s];
        }
        console2.log("TOTAL attempts/successes", ta, ts);
        console2.log("quarantined dump / quoteWork", quarantinedDump, quarantinedQuoteWork);
        console2.log("adv rebalances ok", advRebalanceOk);
        console2.log("adv PnL (raw @p0)"); console2.logInt(advPnL());
        console2.log("adv accepted liq-loss / designed-cap tolerance", advAcceptedLoss, advTolerance());
        console2.log("max grief bps", maxGriefBps);
        console2.log("R1 (quarantined) count / max profit-over-cap", r1Count, r1MaxExcess);
        console2.log("R2 (quarantined) count / max profit-over-baseline", r2Count, r2MaxExcess);
        console2.log("honest in / out", honestValueIn, honestValueOut);
        console2.log("violations", violations);
        console2.log("adv rebalance fails noProgress/lossExceeded/other", advRbNoProgress, advRbLossExceeded, advRbOther);
        console2.log("keeper rebalance noProgress/other", kNoProgress, kOther);
        console2.log("dump-path executed / max staying fair-loss bps", dumpExecuted, dumpMaxLossBps);
        console2.log("dump arb PnL"); console2.logInt(dumpArbPnL);
        console2.log("adv profit admitted only by R1/R2 quarantine", advQuarantinedProfit);
        if (firstOtherRevert.length != 0) console2.logBytes(firstOtherRevert);
    }

    function statsLine() external view returns (string memory line) {
        uint256 ta; uint256 ts;
        for (uint256 i; i < selectorList.length; ++i) {
            bytes4 s = selectorList[i];
            line = string.concat(line, vm.toString(abi.encodePacked(s)), ":", vm.toString(attempts[s]), "/", vm.toString(successes[s]), "/", vm.toString(quarantined[s]), "/", vm.toString(noop[s]), " ");
            ta += attempts[s]; ts += successes[s];
        }
        line = string.concat(line, "| total ", vm.toString(ta), "/", vm.toString(ts), " dumpQ ", vm.toString(quarantinedDump),
            " qwQ ", vm.toString(quarantinedQuoteWork), " advRb ", vm.toString(advRebalanceOk));
        line = string.concat(line, " advPnL ", vm.toString(advPnL()), " tol ", vm.toString(advTolerance()), " grief ", vm.toString(maxGriefBps));
        line = string.concat(line, " r1 ", vm.toString(r1Count), "/", vm.toString(r1MaxExcess), " r2 ", vm.toString(r2Count), "/", vm.toString(r2MaxExcess));
        line = string.concat(line, " viol ", vm.toString(violations));
        line = string.concat(line, " | noop kRb/aSRR/aRB/aJIT ", vm.toString(noop[this.k_rebalance.selector]), "/", vm.toString(noop[this.a_swapRebalanceRestore.selector]), "/", vm.toString(noop[this.a_rebalanceBackrun.selector]));
        line = string.concat(line, "/", vm.toString(noop[this.a_jitSwapRebalanceRestore.selector]), " advRbFail np/lossEx/other ", vm.toString(advRbNoProgress), "/", vm.toString(advRbLossExceeded), "/", vm.toString(advRbOther));
        line = string.concat(line, " kFail np/other ", vm.toString(kNoProgress), "/", vm.toString(kOther), " dumpExec ", vm.toString(dumpExecuted), " dumpLossBps ", vm.toString(dumpMaxLossBps));
        line = string.concat(line, " dumpArbPnL ", vm.toString(dumpArbPnL), " advQProfit ", vm.toString(advQuarantinedProfit));
    }

    /// @notice worst selector success ratio (x100) among selectors with >= minAtt_ attempts, and that selector
    function worstSelector(uint256 minAtt_) external view returns (uint256 pct, bytes4 sel) {
        pct = 100;
        for (uint256 i; i < selectorList.length; ++i) {
            bytes4 s = selectorList[i];
            if (attempts[s] < minAtt_) continue;
            uint256 p = successes[s] * 100 / attempts[s];
            if (p < pct) { pct = p; sel = s; }
        }
    }

    function totals() external view returns (uint256 ta, uint256 ts) {
        for (uint256 i; i < selectorList.length; ++i) { ta += attempts[selectorList[i]]; ts += successes[selectorList[i]]; }
    }

    // =====================================================================================================
    // UNSAFE (known finding; NOT a fuzz target) -- for the sanity test only
    // =====================================================================================================
    function UNSAFE_jitDepositRedeemInUnlock(uint256 deposit_, uint256 l_) external {
        adv.unsafeJitDepositRedeem(address(vaults[0]), deposit_, l_);
    }

    // =====================================================================================================
    // internals
    // =====================================================================================================
    function _runHonest(H memory h_) internal {
        ++attempts[h_.sel];
        if (!isClean()) { _fail("honest op entered non-clean state", 0, 0); return; }
        (bool ok, bool dumped, bytes memory err) = _probe(h_);
        if (!ok) {
            if (_isQuoteWork(err)) { ++quarantined[h_.sel]; ++quarantinedQuoteWork; return; }
            _fail(string.concat("LIVENESS honest op reverted, err=", vm.toString(err)), uint256(uint32(h_.sel)), h_.vi);
            return;
        }
        Snap memory b = _snap(h_);
        uint256 mB = _mark(h_.vi);
        vm.prank(h_.caller);
        (bool s,) = h_.callee.call(h_.data);
        if (!s) { _fail("probe/real divergence", 0, 0); return; }
        Snap memory a = _snap(h_);
        if (dumped) {
            // known finding wings-forced-dump: execute anyway, keep redeemer-side + global checks, meter staying loss
            ++quarantined[h_.sel]; ++quarantinedDump; ++dumpExecuted;
            if (h_.deposit) _fail("vault swapped on a DEPOSIT path (outside known redeem-dump finding)", 0, 0);
            _checkRedeemer(b, a);
            int256 arb0 = _arbRaw();
            _arbToFair();
            dumpArbPnL += _arbRaw() - arb0;
            uint256 mA = _mark(h_.vi);
            uint256 fairEnt = b.s == 0 ? 0 : FullMath.mulDiv(mB, a.s, b.s);
            if (fairEnt > mA && fairEnt != 0) {
                uint256 bps = (fairEnt - mA) * 10_000 / fairEnt;
                if (bps > dumpMaxLossBps) dumpMaxLossBps = bps;
            }
            if (!isClean()) _fail("arb could not restore p0 after dump", 0, 0);
            ++successes[h_.sel];
            return;
        }
        if (!isClean()) _fail("honest op moved price (non-dump path)", 0, 0);
        _checkHonest(h_, b, a);
        _checkFair(h_, b, a, mB, _mark(h_.vi));
        ++successes[h_.sel];
    }

    /// @dev Independent fair-mark (inventory at p0) checks, NOT relying on the vault's own liquidation quote.
    ///      Deposit priced at V <= M: depositor fair worth <= paid * M_b / V_b (the designed haircut), else dilution.
    ///      Non-dump redeem paid <= burned*V_b/S_b <= burned*M_b/S_b: remaining fair mark/share cannot fall.
    function _checkFair(H memory h_, Snap memory b_, Snap memory a_, uint256 mB_, uint256 mA_) internal {
        if (!b_.ok || !a_.ok || a_.s == 0 || b_.s == 0 || b_.v == 0) return;
        if (h_.deposit) {
            uint256 paid = b_.tok - a_.tok;
            uint256 minted = a_.shares - b_.shares;
            uint256 worth = FullMath.mulDiv(minted, mA_, a_.s);
            uint256 cap = FullMath.mulDiv(paid, mB_, b_.v);
            if (worth > cap + _tol(mA_)) _fail("FAIR: depositor fair worth exceeds paid * M/V haircut bound", worth, cap);
        } else {
            uint256 lhs = mA_ * b_.s;
            uint256 rhs = mB_ * a_.s;
            if (rhs > lhs && (rhs - lhs) / b_.s > _tol(mA_)) _fail("FAIR: remaining holders' fair mark/share fell on non-dump redeem", mB_ * 1e18 / b_.s, mA_ * 1e18 / a_.s);
        }
    }

    function _checkRedeemer(Snap memory b_, Snap memory a_) internal {
        if (!b_.ok) { _fail("quote unavailable before dump-path redeem", 0, 0); return; }
        uint256 got = a_.tok - b_.tok;
        uint256 burned = b_.shares - a_.shares;
        honestValueOut += got;
        uint256 ent = FullMath.mulDiv(burned, b_.v, b_.s);
        if (got > ent + _tol(b_.v)) _fail("dump-path redeemer received more than pre-op NAV entitlement", got, ent);
    }

    function _mark(uint8 vi_) internal view returns (uint256) { (uint256 a0, uint256 a1,) = inventory(vi_); return a0 + a1; }
    function _arbRaw() internal view returns (int256) { return int256(token0.balanceOf(address(arb)) + token1.balanceOf(address(arb))); }
    function _sel(bytes memory e_) internal pure returns (bytes4 s_) { if (e_.length >= 4) assembly { s_ := mload(add(e_, 32)) } }

    function probe(address caller_, address callee_, bytes calldata data_, address vault_) external {
        require(msg.sender == address(this), "probe");
        vm.recordLogs();
        vm.prank(caller_);
        (bool ok, bytes memory ret) = callee_.call(data_);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool dumped;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pool) && logs[i].topics.length > 2 && logs[i].topics[0] == SWAP_SIG
                && address(uint160(uint256(logs[i].topics[2]))) == vault_) dumped = true;
        }
        revert ProbeResult(ok, dumped, ok ? bytes("") : ret);
    }

    function _probe(H memory h_) internal returns (bool ok, bool dumped, bytes memory err) {
        try this.probe(h_.caller, h_.callee, h_.data, address(vaults[h_.vi])) {
            revert("probe did not revert");
        } catch (bytes memory data) {
            bytes4 sel;
            assembly { sel := mload(add(data, 32)) }
            require(sel == ProbeResult.selector, "probe: unexpected");
            bytes memory body = new bytes(data.length - 4);
            for (uint256 i; i < body.length; ++i) body[i] = data[i + 4];
            (ok, dumped, err) = abi.decode(body, (bool, bool, bytes));
        }
    }

    function _snap(H memory h_) internal view returns (Snap memory s_) {
        IERC20 sh = IERC20(address(vaults[h_.vi]));
        s_.s = sh.totalSupply();
        s_.tok = _target(h_.vi).balanceOf(h_.payer);
        s_.shares = sh.balanceOf(h_.holder);
        try vaults[h_.vi].liquidationValue() returns (Q.Result memory r) { s_.v = r.value; s_.ok = true; } catch {}
    }

    function _checkHonest(H memory h_, Snap memory b_, Snap memory a_) internal {
        if (!b_.ok || !a_.ok) { _fail("quote unavailable around honest op", 0, 0); return; }
        if (h_.deposit) {
            uint256 paid = b_.tok - a_.tok;
            uint256 minted = a_.shares - b_.shares;
            honestValueIn += paid;
            uint256 worth = FullMath.mulDiv(minted, a_.v, a_.s);
            if (worth > paid + _tol(a_.v)) _fail("depositor received more NAV than paid", worth, paid);
        } else {
            uint256 got = a_.tok - b_.tok;
            uint256 burned = b_.shares - a_.shares;
            honestValueOut += got;
            uint256 ent = FullMath.mulDiv(burned, b_.v, b_.s);
            if (got > ent + _tol(b_.v)) _fail("redeemer received more than pre-op NAV entitlement", got, ent);
        }
        if (a_.s != 0) {
            uint256 lhs = a_.v * b_.s;
            uint256 rhs = b_.v * a_.s;
            if (rhs > lhs && (rhs - lhs) / b_.s > _tol(a_.v)) _fail("NAV/share decreased for remaining holders", b_.v * 1e18 / b_.s, a_.v * 1e18 / a_.s);
        }
    }

    function _advBegin() internal returns (AdvSnap memory b_) {
        actionCap = 0;
        actionRbOk = 0;
        b_.pnl = advPnL();
        for (uint8 vi; vi < 2; ++vi) {
            (uint256 a0, uint256 a1,) = inventory(vi);
            b_.markNum[vi] = a0 + a1; // at p0 (= 2^96) raw token0 == raw token1
            b_.supply[vi] = IERC20(address(vaults[vi])).totalSupply();
        }
    }

    function _advEnd(AdvSnap memory b_, bytes4 sel_) internal {
        if (!isClean()) { _fail("adversary action left non-clean state", 0, 0); return; }
        uint256 before_; uint256 after_;
        for (uint8 vi; vi < 2; ++vi) {
            (uint256 a0, uint256 a1,) = inventory(vi);
            uint256 m = a0 + a1;
            before_ += b_.markNum[vi]; after_ += m;
            if (m < b_.markNum[vi] && b_.markNum[vi] != 0) {
                uint256 bps = (b_.markNum[vi] - m) * 10_000 / b_.markNum[vi];
                if (bps > maxGriefBps) maxGriefBps = bps;
            }
            (uint8 code, uint256 x, uint256 y) = valuationCheck(vi);
            if (code == 2) ++quarantinedQuoteWork;
            else if (code != 0) _fail(string.concat("valuation code ", vm.toString(code)), x, y);
        }
        _advJudge(b_, before_ > after_ ? before_ - after_ : 0, before_);
        ++successes[sel_];
    }

    /// @dev Rebalance-type adversary action: only counts as a success if at least one rebalance actually landed.
    function _advEndRb(AdvSnap memory b_, bytes4 sel_) internal {
        bool landed = actionRbOk != 0;
        _advEnd(b_, sel_);
        if (!landed) { --successes[sel_]; ++noop[sel_]; }
    }

    function _advJudge(AdvSnap memory b_, uint256 loss_, uint256 mark_) internal {
        int256 profit = advPnL() - b_.pnl;
        uint256 tol = TOL_ABS + mark_ / 1e6; // 1 ppm of combined fair TVL per action: covers JIT fee capture of the vault swap (benign V4 MEV)
        int256 allowedP = int256(actionCap) > b_.baseProfit ? int256(actionCap) : b_.baseProfit;
        uint256 allowedL = actionCap > b_.baseLoss ? actionCap : b_.baseLoss;
        if (b_.r1) {
            if (profit > int256(actionCap)) {
                ++r1Count;
                if (uint256(profit) - actionCap > r1MaxExcess) r1MaxExcess = uint256(profit) - actionCap;
                advQuarantinedProfit += uint256(profit - (int256(actionCap) > b_.baseProfit ? int256(actionCap) : b_.baseProfit > 0 ? b_.baseProfit : int256(0)));
                allowedP = profit;
            }
            if (loss_ > allowedL) allowedL = loss_;
        }
        if (b_.r2 && (profit > allowedP + int256(tol) || loss_ > allowedL + tol)) {
            ++r2Count;
            if (profit > allowedP && uint256(profit - allowedP) > r2MaxExcess) r2MaxExcess = uint256(profit - allowedP);
            if (profit > allowedP) { advQuarantinedProfit += uint256(profit - (allowedP > 0 ? allowedP : int256(0))); allowedP = profit; }
            if (loss_ > allowedL) allowedL = loss_;
        }
        if (profit > allowedP + int256(tol)) _fail("ADV extraction beyond max(rebalance cap, clean baseline)", uint256(profit), uint256(allowedP > 0 ? allowedP : int256(0)));
        if (loss_ > allowedL + tol) _fail("ADV action: vault fair-mark loss beyond max(rebalance cap, clean baseline)", loss_, allowedL);
        if (allowedP > 0) advAllowance += uint256(allowedP);
    }

    /// @dev Adversary-triggered rebalance. Records the vault's DESIGNED loss cap (RebalanceTarget._validate:
    ///      1% of progress, progress = sleeve-deficit reduction + before*(coreAfter-coreBefore)/coreAfter).
    function _advRebalance(uint8 vi_) internal {
        uint256 before_;
        try vaults[vi_].liquidationValue() returns (Q.Result memory r) { before_ = r.value; } catch { return; }
        (,, uint128 coreBefore,) = vaults[vi_].position(0);
        uint256 defBefore = _deficit(vi_);
        vm.prank(address(adv));
        try Rebalance(address(vaults[vi_])).rebalance(0, block.timestamp) returns (uint256 after_) {
            ++advRebalanceOk;
            if (after_ < before_) advAcceptedLoss += before_ - after_;
            (,, uint128 coreAfter,) = vaults[vi_].position(0);
            uint256 defAfter = _deficit(vi_);
            uint256 progress = defBefore > defAfter ? defBefore - defAfter : 0;
            if (coreAfter > coreBefore) progress += FullMath.mulDiv(before_, coreAfter - coreBefore, coreAfter);
            if (progress > before_) progress = before_;
            advRebalanceCap += progress / 100;
            actionCap += progress / 100;
            ++actionRbOk;
        } catch (bytes memory e) {
            bytes4 es = _sel(e);
            if (_isQuoteWork(e)) ++quarantinedQuoteWork;
            else if (es == Rebalance.NoRebalanceProgress.selector) ++advRbNoProgress;
            else if (es == Rebalance.RebalanceLossExceeded.selector) ++advRbLossExceeded;
            else if (es == bytes4(0x4e487b71)) _fail(string.concat("adversary-triggered rebalance PANIC ", vm.toString(e)), vi_, 0);
            else { ++advRbOther; if (firstOtherRevert.length == 0) firstOtherRevert = e; }
        }
    }

    function _deficit(uint8 vi_) internal view returns (uint256) {
        IWings v = vaults[vi_];
        (uint256 l0, uint256 l1) = v.localReserves();
        uint256 local = vi_ == 0 ? l0 : l1;
        uint256 tgt = local;
        (uint160 sp,,,) = pool.getSlot0(id);
        for (uint8 i; i < 3; ++i) {
            (int24 lo, int24 up, uint128 liq,) = v.position(i);
            if (liq == 0) continue;
            Types.Principal memory p = Inventory.principal(sp, lo, up, liq, false);
            tgt += vi_ == 0 ? p.amount0 : p.amount1;
        }
        uint256 floor_ = FullMath.mulDiv(tgt, 0.2e18, 1.2e18);
        if (floor_ == 0) floor_ = 1;
        return floor_ > local ? floor_ - local : 0;
    }

    function _advRestore() internal {
        (uint160 p,,,) = pool.getSlot0(id);
        if (p != P0) adv.swap(p > P0, 1e24, P0);
    }

    function _arbToFair() internal {
        (uint160 p,,,) = pool.getSlot0(id);
        if (p != P0) arb.swapTo(key, p > P0, 1e26, P0);
    }

    function _seedUser(address u_, uint8 vi_) internal {
        uint256 amt = 1e15;
        ERC20PermitMintableStub(address(_target(vi_))).mint(u_, amt);
        vm.prank(u_);try IStandardExchangeIn(address(vaults[vi_])).exchangeIn(_target(vi_), amt, IERC20(address(vaults[vi_])), 0, u_, false, block.timestamp)
            returns (uint256, uint256) { honestValueIn += amt; } catch {}
    }

    function _range(uint256 r_) internal pure returns (int24 lo, int24 up) {
        uint256 kind = r_ % 3;
        int24 w = int24(int256(bound(r_ >> 8, 1, 50)));
        if (kind == 0) return (-887220, 887220);
        if (kind == 1) return (-60 * w, 60 * w);
        int24 off = int24(int256(bound(r_ >> 16, 0, 40))) - 20;
        return (60 * off, 60 * (off + w));
    }

    function _value(uint8 vi_) internal view returns (uint256 v_) {
        try vaults[vi_].liquidationValue() returns (Q.Result memory r) { v_ = r.value; } catch {}
    }

    function _target(uint8 vi_) internal view returns (IERC20) { return vi_ == 0 ? IERC20(address(token0)) : IERC20(address(token1)); }
    function _tol(uint256 v_) internal pure returns (uint256) { return TOL_ABS + v_ / 1e12; }
    function _absDiff(uint256 a_, uint256 b_) internal pure returns (uint256) { return a_ > b_ ? a_ - b_ : b_ - a_; }

    function _isQuoteWork(bytes memory e_) internal pure returns (bool) {
        if (e_.length < 4) return false;
        bytes4 s;
        assembly { s := mload(add(e_, 32)) }
        return s == Q.QuoteWorkExceeded.selector;
    }

    function _classifyPreview(bytes4 sel_, bytes memory e_) internal {
        ++attempts[sel_];
        if (_isQuoteWork(e_)) { ++quarantined[sel_]; ++quarantinedQuoteWork; return; }
        _fail(string.concat("LIVENESS preview reverted, err=", vm.toString(e_)), uint256(uint32(sel_)), 0);
    }

    function _fail(string memory why_, uint256 a_, uint256 b_) internal {
        ++violations;
        console2.log("VIOLATION:", why_, a_, b_);
        if (violations == 1) { firstViolation = why_; violationA = a_; violationB = b_; }
    }
}
