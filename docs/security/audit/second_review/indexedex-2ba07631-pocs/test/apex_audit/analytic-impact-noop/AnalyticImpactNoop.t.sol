// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition as AC} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";

contract ExtLP is IUnlockCallback {
    IPoolManager pm; PoolKey key;
    constructor(IPoolManager pm_, PoolKey memory key_) { pm = pm_; key = key_; }
    function add(uint128 l) external { pm.unlock(abi.encode(l)); }
    function unlockCallback(bytes calldata d) external returns (bytes memory) {
        uint128 l = abi.decode(d, (uint128));
        (BalanceDelta delta,) = pm.modifyLiquidity(key, ModifyLiquidityParams(
            TickMath.minUsableTick(key.tickSpacing), TickMath.maxUsableTick(key.tickSpacing), int256(uint256(l)), bytes32(0)), "");
        _pay(key.currency0, delta.amount0()); _pay(key.currency1, delta.amount1());
        return "";
    }
    function _pay(Currency c, int128 d) internal {
        if (d < 0) { pm.sync(c); IERC20(Currency.unwrap(c)).transfer(address(pm), uint128(-d)); pm.settle(); }
    }
}

contract AnalyticImpactNoopTest is Acceptance {
    using PoolIdLibrary for *;

    function _price() internal view returns (uint160 p) {
        (p,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
    }

    function _plannedPrice(uint256 amount) internal returns (uint160 after_, uint256 shares) {
        (bytes memory snap,) = Transition(address(vault)).quoteState(address(token0), address(this));
        (bytes memory next,, uint256 s,) = Transition(address(vault)).quoteTransition(snap, Transition.Operation.DepositExactIn, amount);
        Common.InventoryQuote memory q = abi.decode(next, (Common.InventoryQuote));
        return (q.pool.sqrtPriceX96, s);
    }

    /// Composition whose swap moves price > 50 bps is quoted valid but execution reverts.
    /// token1 -> vault deposit (zeroForOne=false composition swap) at the project's default fixture
    /// (external full-range LP L = 1e6 units, vault bootstrapped 1000/1000, fee 0.30%).
    function test_impactCheckNoop_previewValid_executionReverts() public {
        _bootstrap();
        uint256 amount = 20_000 * unit1;
        uint160 before = _price();

        // 1) Planner (same call the vault makes in preview AND execution) certifies the plan.
        Types.Snapshot memory st = _state();
        Types.Plan memory plan = Planner._composition(st,
            Quotes.Params(poolManager, poolKey, st.position, false, 0, address(weth)), amount);
        bool within = Protection._priceWithin(before, plan.swap.sqrtPriceAfterX96, 50);
        console2.log("deposit amount (token1)", amount);
        console2.log("plan.valid", plan.valid);
        console2.log("plan.shares", plan.shares);
        console2.log("plan.swap.amountIn", plan.swap.amountIn);
        console2.log("slot0 sqrtP before", uint256(before));
        console2.log("planned sqrtP after", uint256(plan.swap.sqrtPriceAfterX96));
        console2.log("planned price move bps (approx)", _impactBps(before, plan.swap.sqrtPriceAfterX96));
        assertTrue(plan.valid, "_certify accepted the plan");
        assertFalse(within, "planned swap exceeds the 50bps IMPACT_BPS that _certify is supposed to enforce");

        // 2) Public preview returns those shares.
        (uint256 quote,) = vault.previewExchangeIn(token1, amount, IERC20(address(vault)));
        console2.log("previewExchangeIn shares", quote);
        assertEq(quote, plan.shares, "preview == certified plan");
        assertGt(quote, 0);

        // 3) Execution with the same inputs reverts at the real-slot0 re-check.
        uint256 bal1 = token1.balanceOf(address(this));
        uint256 supply = vault.totalSupply();
        vm.expectRevert(Common.PriceImpactExceeded.selector);vault.exchangeIn(token1, amount, IERC20(address(vault)), quote, address(this), false, block.timestamp);
        assertEq(token1.balanceOf(address(this)), bal1, "no funds moved");
        assertEq(vault.totalSupply(), supply, "no shares minted");
        assertEq(_price(), before, "pool untouched");
        _assertBooked();
        console2.log("RESULT: preview>0 but exchangeIn reverts PriceImpactExceeded; no value moved");
    }

    /// Control: sub-threshold composition, preview == execution.
    function test_control_smallDepositParity() public {
        _bootstrap();
        uint256 amount = 100 * unit0;
        uint160 before = _price();(uint256 quote,) = vault.previewExchangeIn(token0, amount, IERC20(address(vault)));
        (uint160 planned,) = _plannedPrice(amount);
        console2.log("small: preview", quote);
        console2.log("small: within 50bps", Protection._priceWithin(before, planned, 50));
        assertTrue(Protection._priceWithin(before, planned, 50));
        (uint256 exchangeAmountOut1,) = vault.exchangeIn(token0, amount, IERC20(address(vault)), quote, address(this), false, block.timestamp);
        assertEq(exchangeAmountOut1, quote);
    }


    function _bootstrapN(uint256 n) internal returns (uint256 shares_) {
        uint256[] memory amounts = _amounts(n * unit0, n * unit1);
        uint256 expected = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(_tokens(), amounts, IERC20(address(vault)));
        shares_ = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            _tokens(), amounts, IERC20(address(vault)), expected, address(this), false, block.timestamp);
    }

    function _probe(uint256 amount) internal {
        uint160 before = _price();(uint256 quote,) = vault.previewExchangeIn(token0, amount, IERC20(address(vault)));
        (uint160 planned,) = _plannedPrice(amount);
        uint256 snap = vm.snapshotState();
        (bool ok, bytes memory ret) = address(vault).call(abi.encodeWithSelector(vault.exchangeIn.selector,
            token0, amount, IERC20(address(vault)), quote, address(this), false, block.timestamp));
        vm.revertToState(snap);
        console2.log("amount(milli-units)", amount * 1000 / unit0);
        console2.log("  preview", quote);
        console2.log("  within50", Protection._priceWithin(before, planned, 50));
        console2.log("  exec ok", ok);
        if (!ok && ret.length >= 4) console2.logBytes4(bytes4(ret));
    }

    function test_sweepSmall() public {
        _bootstrap();
        uint256[8] memory s = [uint256(1), 2, 5, 10, 20, 50, 100, 500];
        for (uint256 i; i < s.length; ++i) _probe(s[i] * unit0);
    }

    function test_sweepBigVault() public {
        _bootstrapN(300_000);
        uint256[8] memory s = [uint256(1), 10, 100, 1_000, 3_000, 10_000, 30_000, 100_000];
        for (uint256 i; i < s.length; ++i) _probe(s[i] * unit0);
    }

    function _state() internal view returns (Types.Snapshot memory state) {
        (bytes memory snap,) = Transition(address(vault)).quoteState(address(token0), address(this));
        Common.InventoryQuote memory q = abi.decode(snap, (Common.InventoryQuote));
        state.idle = q.idle;
        state.book.free = [q.free0, q.free1];
        state.book.earned = [q.fees0, q.fees1];
        state.book.supply = q.supply;
        state.sleeveWad = q.sleeveWad;
        state.absoluteFloor = q.absoluteFloor;
        state.position = Types.PositionState(q.pool.sqrtPriceX96, TickMath.getSqrtPriceAtTick(q.lower),
            TickMath.getSqrtPriceAtTick(q.upper), q.pool.tick, q.lower, q.upper,
            q.positionLiquidity, q.pool.liquidity, q.liquidityDelta,
            q.lowerLiquidityGross, q.upperLiquidityGross, q.maxLiquidityPerTick);
        state.book.deployed = Inventory._amounts(state.position, state.position.liquidity, false);
    }

    function _diag(uint256 amount) internal view {
        Types.Snapshot memory st = _state();
        Quotes.Params memory params = Quotes.Params(poolManager, poolKey, st.position, true, 0, address(weth));
        AC.ProjectedPoolOverlay memory live;
        (Types.Plan memory plan,, AC.Failure f) = AC._plan(st, params, amount, live);
        Types.Snapshot memory st2 = _state();
        Types.Plan memory p2 = Planner._composition(st2, Quotes.Params(poolManager, poolKey, st2.position, true, 0, address(weth)), amount);
        console2.log("diag amount(units)", amount / unit0);
        console2.log("  analytic failure", uint256(f));
        console2.log("  analytic valid", plan.valid);
        console2.log("  analytic shares", plan.shares);
        console2.log("  swapIn", plan.swap.amountIn);
        console2.log("  planned within50", plan.swap.sqrtPriceAfterX96 == 0 ? true : Protection._priceWithin(st.position.sqrtPriceX96, plan.swap.sqrtPriceAfterX96, 50));
        console2.log("  composition valid/shares", p2.valid, p2.shares);
    }

    /// token0-input (zeroForOne) compositions: analytic Failure.Rejected(8) from the 1bp alignment check for >= ~700 units.
    function test_diag() public {
        _bootstrap();
        uint256[6] memory s = [uint256(100), 500, 700, 1_000, 3_000, 20_000];
        for (uint256 i; i < s.length; ++i) _diag(s[i] * unit0);
    }

    function _freshPool(uint128 extL) internal {
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 500, 10, IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1) << 96);
        if (extL != 0) {
            ExtLP lp = new ExtLP(poolManager, poolKey);
            token0.transfer(address(lp), 1e30); token1.transfer(address(lp), 1e30);
            lp.add(extL);
        }
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
    }

    function _impactBps(uint160 a, uint160 b) internal pure returns (uint256) {
        uint256 hi = a > b ? a : b; uint256 lo = a > b ? b : a;
        return (hi * hi / lo) * 10_000 / lo - 10_000;
    }

    /// Scan deposit sizes; count certified (valid) plans whose swap breaks the 50bps bound.
    function _scan(string memory tag, bool zeroForOne) internal {
        uint256 maxBps; uint256 atAmt; uint256 nValid; uint256 nBypass;
        Types.Snapshot memory st0 = _state();
        for (uint256 a = unit0 / 100; a < 100_000 * unit0; a = a * 5 / 4) {
            Types.Snapshot memory st = _state();
            Types.Plan memory p = Planner._composition(st, Quotes.Params(poolManager, poolKey, st.position, zeroForOne, 0, address(weth)), a);
            if (!p.valid || p.swap.amountIn == 0) continue;
            ++nValid;
            uint256 bps = _impactBps(st0.position.sqrtPriceX96, p.swap.sqrtPriceAfterX96);
            if (bps > maxBps) { maxBps = bps; atAmt = a; }
            if (!Protection._priceWithin(st0.position.sqrtPriceX96, p.swap.sqrtPriceAfterX96, 50)) ++nBypass;
        }
        console2.log(tag);
        console2.log("  valid plans", nValid);
        console2.log("  max price impact bps among valid", maxBps);
        console2.log("  at amount (milli)", atAmt * 1000 / unit0);
        console2.log("  valid plans exceeding 50bps", nBypass);
        if (!zeroForOne) assertGt(nBypass, 0, "certified plans exceed 50bps");
    }

    function test_scan_default() public { _bootstrap(); _scan("ext 1e6, vault 1000 (dir 0->1)", true); _scan("  dir 1->0", false); }
    function test_scan_ext1000() public { _freshPool(uint128(1_000 * unit0)); _bootstrap(); _scan("ext 1000, vault 1000", true); _scan("  dir 1->0", false); }
    function test_scan_bigvault() public { _bootstrapN(1_000_000); _scan("ext 1e6, vault 1e6", true); _scan("  dir 1->0", false); }

    /// Sweep: show preview never returns 0 for impact reasons (check is dead).
    function test_sweep() public {
        _bootstrap();
        uint160 before = _price();
        uint256[6] memory sizes = [uint256(2_000), 5_000, 10_000, 50_000, 200_000, 1_000_000];
        for (uint256 i; i < sizes.length; ++i) {
            uint256 amount = sizes[i] * unit0;(uint256 quote,) = vault.previewExchangeIn(token0, amount, IERC20(address(vault)));
            (uint160 planned,) = _plannedPrice(amount);
            bool within = Protection._priceWithin(before, planned, 50);
            uint256 snap = vm.snapshotState();
            (bool ok, bytes memory ret) = address(vault).call(abi.encodeWithSelector(vault.exchangeIn.selector,
                token0, amount, IERC20(address(vault)), quote, address(this), false, block.timestamp));
            vm.revertToState(snap);
            console2.log("size", sizes[i]);
            console2.log("  preview", quote);
            console2.log("  within50", within);
            console2.log("  exec ok", ok);
            if (!ok && ret.length >= 4) console2.logBytes4(bytes4(ret));
            if (!within) assertGt(quote, 0, "preview nonzero despite impact");
        }
    }
}
