# StandardExchangeBufferPool Rate-Tracking Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the two-token StandardExchangeBufferPool so its quoted price dynamically tracks the rate provider configured in the Balancer V3 Vault for the pool, instead of cancelling the rate out of the swap math.

**Architecture:** The current bespoke constant-product math (`x = virtualTTA`, `y = rate-scaled shares`) cancels the rate out of every marginal quote (price = `virtualTTA / rawShares`, rate-free). The fix replaces the CP formulas with Balancer `WeightedMath` using **rate-scaled effective weights**: `wShares : wTta = (currentRate / baselineRate) : 1`, where `baselineRate` is captured at pool initialization. At initialization the ratio is 1 → weights are exactly 50/50 → behavior is identical to today's CP. As the rate drifts, the weight ratio carries the rate into the price: marginal TTA-per-raw-share = `(rate/baselineRate) · virtualTTA / parShares`, which equals NAV at the seeded equilibrium and re-prices instantly (no arbitrage flow needed) when the rate moves. All rate reads go through `IVault.getPoolTokenRates(pool)` — the exact rates the Vault itself applies — never through the rate provider directly.

**Tech Stack:** Solidity ^0.8.0 (Foundry / forge), Balancer V3 (Crane ports), Crane Diamond Facet-Target-Repo pattern.

## Global Constraints

- Repo root for all paths below: `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex` (run all `forge` commands from there).
- Token registration stays exactly as-is: TTA = `TokenType.STANDARD`, shares = `TokenType.WITH_RATE` with the StandardExchangeRateProvider (`StandardExchangeBufferPoolStandardVaultPkg._buildTokenConfigs` is NOT modified).
- The pool/hook math paths must read the share token's rate and decimal scaling factor ONLY via `IVault(vault).getPoolTokenRates(address(this))` (crane `IVault` inherits `IVaultExtension`; modifier is `withRegisteredPool`, so it is callable from registration onward, including inside `onBeforeInitialize`). Never call `Repo._rateProvider().getRate()` in refactored code.
- `StandardExchangeBufferPoolRepo.Storage` layout is append-only: existing fields keep offsets 0–9 (tests use `vm.store` at offsets 7 and 8); new field `baselineRate` goes at offset 10.
- The pool remains two-token (TTA + one share token). No multi-token generalization in this plan.
- No mocks in new tests. Rate movement must come from the **Uniswap V2 Standard Exchange Vault**: execute real trades through the underlying Uniswap V2 pair so the share NAV (and thus `getRate()`) genuinely changes.
- License headers: `// SPDX-License-Identifier: BSL-1.1`.
- Commit after every task; message prefixes follow repo convention (`feat:`, `fix:`, `test:`, `chore:`).

## Design Reference (read before starting any task)

Derivation of the pricing identity (all quantities scaled18 unless noted):

- `x = virtualTTA`, `B` = raw share balance, `s` = decimal scaling factor, `r` = current rate, `r₀` = baselineRate.
- Live shares balance the Vault supplies: `L = B·s·r/1e18`. Derived depth `y = L ± lift(hookSharesDelta)` (unchanged).
- Weighted marginal price with weights `(wTta, wShares)`: TTA per raw share = `(wShares/wTta) · x/(B·s)`.
- With `wShares/wTta = r/r₀` and the existing seed `x = exactAmountsInScaled18[sharesIdx] = B·s·r₀/1e18`, the price is `s·r/1e18` = NAV. Rate changes re-price instantly; the equilibrium inventory point does not move.
- At `r = r₀`, weights are 50/50 and `WeightedMath.computeOutGivenExactIn` reduces to the CP formula exactly (the pow exponent is `1e18`, which `FixedPoint.powUp/powDown` special-case to identity). Only ≤ a few wei of rounding differ from the old `Math.mulDiv` code, and `computeInvariant` (pow-based, ~1e-9 relative error vs `Math.sqrt`) — existing exact-value assertions may need `assertApproxEqAbs`/`assertApproxEqRel` tolerances.
- Behavior changes accepted by this plan: `WeightedMath` enforces `MaxInRatio`/`MaxOutRatio` (30% of the respective balance per swap) and reverts `ZeroInvariant` on zero balances (old code returned `sqrt(0)=0`).

Key file inventory (all under `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/` unless noted):

| File | Role |
|---|---|
| `StandardExchangeBufferPoolTarget.sol` | `IBalancerV3Pool` math (onSwap/computeInvariant/computeBalance) |
| `StandardExchangeBufferPoolFacet.sol` | Facet exposing target + storage views (funcs array currently 11 entries) |
| `StandardExchangeBufferHookTarget.sol` | `IHooks` impl: init, pre-seat, reconcile, LP bookkeeping |
| `StandardExchangeHookFacet.sol` | Hook facet; `_balancerV3Vault()` = `BalancerV3VaultAwareRepo._balancerV3Vault()` |
| `StandardExchangeBufferPoolRepo.sol` | Diamond storage (slot `keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange")`) |
| `IStandardExchangeBufferPool.sol` | Errors + storage views interface |
| `@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol` | `computeInvariantDown/Up(uint256[] weights, uint256[] balances)`, `computeBalanceOutGivenInvariant(uint256 currentBalance, uint256 weight, uint256 invariantRatio)`, `computeOutGivenExactIn(balIn, wIn, balOut, wOut, amountIn)`, `computeInGivenExactOut(balIn, wIn, balOut, wOut, amountOut)` |
| Tests | `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/` (TestBase in `bases/`) |
| Uniswap V2 SE vault | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol`, test base `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol` |

---

### Task 1: Plumbing — `baselineRate` storage, interface additions, shared `Common` contract

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol`
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol`
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol`
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolFacet.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.t.sol`

**Interfaces:**
- Consumes: `StandardExchangeBufferPoolRepo` (existing), `BalancerV3VaultAwareRepo._balancerV3Vault()`, `IVault.getPoolTokenRates`.
- Produces (later tasks rely on these exact signatures):
  - `StandardExchangeBufferPoolRepo._baselineRate() returns (uint256)` / `_setBaselineRate(uint256)`
  - `IStandardExchangeBufferPool.baselineRate() returns (uint256)` and `error EffectiveWeightOutOfBounds(uint256 wTta, uint256 wShares)`
  - `StandardExchangeBufferPoolCommon` internal API: `_vaultSharesRateAndScale() returns (uint256 rate, uint256 scalingFactor)`, `_effectiveWeights(uint256 currentRate, uint256 baselineRate_) returns (uint256 wTta, uint256 wShares)` (pure), `_currentEffectiveWeights() returns (uint256 wTta, uint256 wShares)`, `_derivedY(uint256[] memory) returns (uint256)`, `_liftSharesToScaled18Rated(uint256) returns (uint256)`, `_bv3SharesDonationRaw(uint256) returns (uint256)`, `_bv3SharesRemoveOutRaw(uint256) returns (uint256)`

- [ ] **Step 1: Write the failing test**

Create `StandardExchangeBufferPoolCommon.t.sol` with a harness for the pure weight math (the storage-reading members are integration-tested in later tasks through the deployed pool):

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol";

contract CommonHarness is StandardExchangeBufferPoolCommon {
    function effectiveWeights(uint256 currentRate, uint256 baselineRate_)
        external pure returns (uint256 wTta, uint256 wShares)
    {
        return _effectiveWeights(currentRate, baselineRate_);
    }
}

contract StandardExchangeBufferPoolCommonTest is Test {
    CommonHarness internal harness;

    function setUp() public {
        harness = new CommonHarness();
    }

    function test_effectiveWeights_atBaseline_are5050() public view {
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(1e18, 1e18);
        assertEq(wTta, 0.5e18);
        assertEq(wShares, 0.5e18);
    }

    function test_effectiveWeights_sumToOne_andTrackRatio() public view {
        // rate 20% above baseline: ratio = 1.2, wShares = 1.2/2.2
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(1.2e18, 1e18);
        assertEq(wShares, uint256(1.2e18) * 1e18 / 2.2e18);
        assertEq(wTta + wShares, 1e18);
        // Ratio identity: wShares/wTta == rate/baseline (to rounding)
        assertApproxEqRel(uint256(wShares) * 1e18 / wTta, 1.2e18, 1e6);
    }

    function test_effectiveWeights_nonUnitBaseline() public view {
        // Same ratio expressed with a non-1e18 baseline (e.g. decimal-offset SE rates)
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(6e8, 5e8); // ratio 1.2
        assertEq(wShares, uint256(1.2e18) * 1e18 / 2.2e18);
        assertEq(wTta + wShares, 1e18);
    }

    function test_effectiveWeights_revertsBelowMinWeight() public {
        // ratio 100 → wTta = 1/101 < 1%
        vm.expectRevert(IStandardExchangeBufferPool.EffectiveWeightOutOfBounds.selector);
        harness.effectiveWeights(100e18, 1e18);
        // ratio 1/100 → wShares < 1%
        vm.expectRevert(IStandardExchangeBufferPool.EffectiveWeightOutOfBounds.selector);
        harness.effectiveWeights(1e18, 100e18);
    }

    function testFuzz_effectiveWeights_boundedAndNormalized(uint256 rate, uint256 base) public view {
        rate = bound(rate, 1, 1e30);
        base = bound(base, 1, 1e30);
        uint256 ratio = rate * 1e18 / base;
        vm.assume(ratio >= 0.0102e18 && ratio <= 98e18); // safely inside the 1% weight band
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(rate, base);
        assertEq(wTta + wShares, 1e18);
        assertGe(wTta, 1e16);
        assertGe(wShares, 1e16);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.t.sol" -vv`
Expected: compilation FAILURE — `StandardExchangeBufferPoolCommon.sol` not found, `EffectiveWeightOutOfBounds` undeclared.

- [ ] **Step 3: Add the Repo field and accessors**

In `StandardExchangeBufferPoolRepo.sol`, append to the END of `struct Storage` (after `pendingPreSeatS`, so it lands at offset 10):

```solidity
        // Rate reported by the Vault for the share token at pool initialization.
        // Effective weights are computed from currentRate / baselineRate, so the
        // pool's seeded inventory is its equilibrium point regardless of where the
        // rate provider's absolute scale sits.
        uint256 baselineRate;
```

And append accessors after `_setPendingPreSeatS`:

```solidity
    function _baselineRate() internal view returns (uint256) { return _layout().baselineRate; }
    function _setBaselineRate(uint256 v) internal { _layout().baselineRate = v; }
```

- [ ] **Step 4: Add the interface error and view**

In `IStandardExchangeBufferPool.sol`, add to the errors block:

```solidity
    error EffectiveWeightOutOfBounds(uint256 wTta, uint256 wShares);
```

and to the views block:

```solidity
    function baselineRate() external view returns (uint256);
```

- [ ] **Step 5: Create `StandardExchangeBufferPoolCommon.sol`**

This consolidates the `_derivedY` / `_liftSharesToScaled18Rated` duplicates that currently live in BOTH `StandardExchangeBufferPoolTarget` and `StandardExchangeBufferHookTarget`, moves the hook's `_bv3SharesDonationRaw` / `_bv3SharesRemoveOutRaw` round-trip mirrors here, and adds the new rate/weight helpers. All rate reads go through the Vault.

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BalancerV3VaultAwareRepo} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferPoolCommon
 * @notice Shared helpers for the buffer pool target and hook target: Vault-sourced
 *         rate reads, rate-scaled effective weights, derived shares depth, and the
 *         Balancer V3 raw<->scaled18 round-trip mirrors.
 * @dev The share token's rate is ALWAYS read via `IVault.getPoolTokenRates(address(this))`
 *      so the pool math uses the exact rate the Vault applied when scaling balances and
 *      amounts. The pool never talks to the rate provider directly.
 */
abstract contract StandardExchangeBufferPoolCommon {

    /// @dev Minimum effective normalized weight (1%), mirroring Balancer weighted-pool bounds.
    uint256 internal constant _MIN_EFFECTIVE_WEIGHT = 1e16;

    /* ----- Vault-sourced rate ----- */

    /**
     * @dev Reads the share token's current rate and decimal scaling factor from the Vault —
     *      the same values the Vault used to build balancesLiveScaled18.
     *      Reverts RateProviderZero if the Vault reports a zero rate.
     */
    function _vaultSharesRateAndScale() internal view returns (uint256 rate, uint256 scalingFactor) {
        (uint256[] memory scalingFactors, uint256[] memory rates) =
            IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault())).getPoolTokenRates(address(this));
        uint256 sharesIdx = Repo._sharesIndex();
        rate = rates[sharesIdx];
        scalingFactor = scalingFactors[sharesIdx];
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
    }

    /* ----- Effective weights ----- */

    /**
     * @dev Normalized effective weights carrying the rate ratio:
     *        wShares/wTta = currentRate/baselineRate.
     *      At currentRate == baselineRate this is exactly 50/50 (the constant-product case).
     *      Marginal price identity: TTA per raw share = (wShares/wTta) * virtualTTA / parShares,
     *      i.e. the pool re-prices proportionally to the rate with no arbitrage flow.
     */
    function _effectiveWeights(uint256 currentRate, uint256 baselineRate_)
        internal pure returns (uint256 wTta, uint256 wShares)
    {
        uint256 rateRatio = Math.mulDiv(currentRate, 1e18, baselineRate_);
        wShares = Math.mulDiv(rateRatio, 1e18, rateRatio + 1e18);
        wTta = 1e18 - wShares;
        if (wTta < _MIN_EFFECTIVE_WEIGHT || wShares < _MIN_EFFECTIVE_WEIGHT) {
            revert IStandardExchangeBufferPool.EffectiveWeightOutOfBounds(wTta, wShares);
        }
    }

    /// @dev Effective weights for the pool's current state (Vault rate vs stored baseline).
    function _currentEffectiveWeights() internal view returns (uint256 wTta, uint256 wShares) {
        (uint256 rate, ) = _vaultSharesRateAndScale();
        return _effectiveWeights(rate, Repo._baselineRate());
    }

    /* ----- Derived shares depth (moved verbatim from the target/hook duplicates, with
             the rate read switched to the Vault) ----- */

    /**
     * @dev Effective shares-side depth used in AMM math: the live balance minus the
     *      hook's accumulated reshuffling offset (hookSharesDelta).
     */
    function _derivedY(uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        uint256 sharesIdx = Repo._sharesIndex();
        int256 h = Repo._hookSharesDelta();
        uint256 actualSharesScaled = balancesLiveScaled18[sharesIdx];
        if (h <= 0) {
            uint256 add = _liftSharesToScaled18Rated(uint256(-h));
            unchecked { return actualSharesScaled + add; }
        }
        uint256 sub = _liftSharesToScaled18Rated(uint256(h));
        if (sub >= actualSharesScaled) return 0;
        unchecked { return actualSharesScaled - sub; }
    }

    /**
     * @dev Converts a raw shares amount to scaled18+rated units, matching the Vault's
     *      balancesLiveScaled18 representation (floor rounding, as the Vault's
     *      toScaled18ApplyRateRoundDown).
     */
    function _liftSharesToScaled18Rated(uint256 rawShares) internal view returns (uint256) {
        if (rawShares == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultSharesRateAndScale();
        return Math.mulDiv(rawShares * scalingFactor, rate, 1e18);
    }

    /* ----- Balancer V3 raw<->scaled18 round-trip mirrors (moved from the hook target,
             with the rate/decimals read switched to the Vault) ----- */

    /**
     * @dev Raw shares Balancer will charge as amountInRaw for a DONATION of `desiredRaw`:
     *        scaled      = floor(desiredRaw * scalingFactor * rate / 1e18)
     *        amountInRaw = ceil (scaled * 1e18 / (scalingFactor * rate))
     */
    function _bv3SharesDonationRaw(uint256 desiredRaw) internal view returns (uint256) {
        if (desiredRaw == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultSharesRateAndScale();
        uint256 denom = scalingFactor * rate;
        uint256 scaled = (desiredRaw * denom) / 1e18;
        return Math.mulDiv(scaled, 1e18, denom, Math.Rounding.Ceil);
    }

    /**
     * @dev Raw shares Balancer will return as amountOutRaw for a removeLiquidity CUSTOM
     *      given `sRaw` as minAmountsOut:
     *        scaled       = ceil (sRaw * scalingFactor * rate / 1e18)
     *        amountOutRaw = floor(scaled * 1e18 / (scalingFactor * rate))
     */
    function _bv3SharesRemoveOutRaw(uint256 sRaw) internal view returns (uint256) {
        if (sRaw == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultSharesRateAndScale();
        uint256 denom = scalingFactor * rate;
        uint256 scaled = Math.mulDiv(sRaw, denom, 1e18, Math.Rounding.Ceil);
        return (scaled * 1e18) / denom;
    }
}
```

- [ ] **Step 6: Expose `baselineRate()` on the pool facet**

In `StandardExchangeBufferPoolFacet.sol` add alongside the other storage views:

```solidity
    function baselineRate() external view returns (uint256) {
        return StandardExchangeBufferPoolRepo._baselineRate();
    }
```

and grow the funcs array from 11 to 12 entries:

```solidity
        funcs = new bytes4[](12);
        // ... existing 11 assignments unchanged ...
        funcs[11] = this.baselineRate.selector;
```

- [ ] **Step 7: Run the new test and the existing suite**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*" -vv`
Expected: new `StandardExchangeBufferPoolCommonTest` PASSES. Existing tests PASS unchanged (no behavior has changed yet — `Common` is not wired into the target/hook until Tasks 2–3). If a facet IFacet-shape test asserts the funcs array length/content, update it for the 12th selector.

- [ ] **Step 8: Commit**

```bash
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/ \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.t.sol
git commit -m "feat(buffer-pool): add baselineRate storage and rate-scaled effective weight helpers"
```

---

### Task 2: Capture `baselineRate` at initialization; route all hook rate reads through the Vault

**Files:**
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_Registration.t.sol` (extend)

**Interfaces:**
- Consumes: `StandardExchangeBufferPoolCommon` (Task 1), `Repo._setBaselineRate`.
- Produces: after initialization, `IStandardExchangeBufferPool(pool).baselineRate()` equals the Vault-reported share rate at init time. Later tasks assume this holds.

- [ ] **Step 1: Write the failing test**

Add to the registration/initialization test file (which uses `TestBase_StandardExchangeBufferPool` and its initialized `bufferPool`):

```solidity
    function test_onBeforeInitialize_capturesBaselineRateFromVault() public view {
        (, uint256[] memory rates) = IVault(address(balV3Vault)).getPoolTokenRates(bufferPool);
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();
        uint256 baseline = IStandardExchangeBufferPool(bufferPool).baselineRate();
        assertGt(baseline, 0, "baselineRate not set");
        assertEq(baseline, rates[sharesIdx], "baselineRate != vault rate at init");
    }
```

(Match the test base's actual Vault variable name — the base exposes the Crane Balancer V3 VaultMock used to register `bufferPool`; reuse the same identifier the sibling tests use.)

- [ ] **Step 2: Run test to verify it fails**

Run: `forge test --match-test test_onBeforeInitialize_capturesBaselineRateFromVault -vv`
Expected: FAIL — `baselineRate` is 0 (never set).

- [ ] **Step 3: Wire the hook to `Common` and set the baseline**

In `StandardExchangeBufferHookTarget.sol`:

1. Add the import and inherit:

```solidity
import {StandardExchangeBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol";

abstract contract StandardExchangeBufferHookTarget is StandardExchangeBufferPoolCommon, IHooks {
```

2. DELETE the hook's local `_derivedY`, `_liftSharesToScaled18Rated`, `_bv3SharesDonationRaw`, and `_bv3SharesRemoveOutRaw` (all four now come from `Common`). Remove the now-unused `IERC20Metadata` import if nothing else uses it.

3. Replace `onBeforeInitialize` with:

```solidity
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory)
        external virtual override returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        uint256 sharesIdx = Repo._sharesIndex();
        // Read the rate the Vault itself just applied (reverts RateProviderZero on 0).
        (uint256 rate, ) = _vaultSharesRateAndScale();
        // exactAmountsIn is exactAmountsInScaled18 from Balancer. For WITH_RATE tokens,
        // scaled18 = rawShares * rate / 1e18 — already in TTA-equivalent units.
        uint256 virtualInit = exactAmountsIn[sharesIdx];
        if (virtualInit == 0) revert IStandardExchangeBufferPool.InitialInvariantTooSmall();
        Repo._setVirtualTTA(virtualInit);
        // Anchor for effective weights: weights are 50/50 at this rate, so the seeded
        // inventory is the equilibrium point and the pool quotes NAV immediately.
        Repo._setBaselineRate(rate);
        Repo._setHookSharesDelta(0);
        return true;
    }
```

- [ ] **Step 4: Run the full pool suite**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*" -vv`
Expected: all PASS, including the new baseline test. (Swap math is still CP — untouched in this task.)

- [ ] **Step 5: Commit**

```bash
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_Registration.t.sol
git commit -m "feat(buffer-pool): capture baselineRate at init; hook rate reads via Vault"
```

---

### Task 3: Weighted math in the pool target + matching hook pre-seat (atomic)

These must land together: `_preSeatShares` re-derives the swap output, and the two formulas must agree or shares→TTA swaps break settlement.

**Files:**
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol`
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol` (extend/adjust), existing spec suite (tolerances)

**Interfaces:**
- Consumes: `_currentEffectiveWeights()`, `_derivedY()` (Task 1), `baselineRate` set at init (Task 2), `WeightedMath` (crane).
- Produces: `onSwap`/`computeInvariant`/`computeBalance` now weighted; `_preSeatShares` uses `WeightedMath.computeOutGivenExactIn(y, wShares, x, wTta, amountInPostFee)` for EXACT_IN and `Y_TTA_raw = params.amountGivenScaled18` for EXACT_OUT; `onAfterSwap` shares→TTA uses `params.amountOutScaled18` as the TTA delivered (kind-correct, TTA is 18-dec STANDARD).

- [ ] **Step 1: Write the failing tests**

Add to `StandardExchangeBufferPoolTargetTest`. This file already forces Repo state via `vm.store` (see its `_setVirtualTTA`); reuse that technique to force a `baselineRate` that diverges from the current rate — no NAV movement or mocks needed at unit level (real rate-movement coverage arrives in Task 4). Add the offset constant and helper next to the existing ones:

```solidity
    uint256 internal constant BASELINE_RATE_OFFSET = 10;

    function _setBaselineRate(uint256 v) internal {
        vm.store(bufferPool, bytes32(uint256(POOL_REPO_SLOT) + BASELINE_RATE_OFFSET), bytes32(v));
    }
```

and the tests (reuse this file's existing `PoolSwapParams`-building helper for direct `onSwap` calls):

```solidity
    function test_onSwap_matchesCP_atBaseline() public {
        // At rate == baselineRate weights are 50/50 and the quote must equal the CP
        // formula to within rounding (<= 2 wei).
        uint256 x = _virtualTTA();
        uint256[] memory bals = _liveBalances(); // this file's existing balance helper
        uint256 y = bals[IStandardExchangeBufferPool(bufferPool).sharesIndex()];
        uint256 dx = x / 100;
        uint256 cpOut = y * dx / (x + dx);
        uint256 got = IBalancerV3Pool(bufferPool).onSwap(_swapParams(SwapKind.EXACT_IN, dx, ttaIdx, sharesIdx));
        assertApproxEqAbs(got, cpOut, 2, "50/50 weighted != CP");
    }

    function test_onSwap_quoteScalesInverselyWithRateRatio() public {
        // Force baselineRate = currentRate / 1.2, i.e. the rate has "risen" 20% since
        // init. The quoted shares-out for a small TTA amount must fall by ~1.2x versus
        // the baseline quote. Under the old CP math the two quotes are identical.
        uint256 dx = 1e15;
        uint256 out1 = IBalancerV3Pool(bufferPool).onSwap(_swapParams(SwapKind.EXACT_IN, dx, ttaIdx, sharesIdx));
        uint256 currentRate = seRateProvider.getRate();
        _setBaselineRate(Math.mulDiv(currentRate, 1e18, 1.2e18));
        uint256 out2 = IBalancerV3Pool(bufferPool).onSwap(_swapParams(SwapKind.EXACT_IN, dx, ttaIdx, sharesIdx));
        // price-per-share ∝ rate/baseline ⇒ shares-out ∝ baseline/rate
        // (0.5% tolerance for finite trade size)
        assertApproxEqRel(out2, Math.mulDiv(out1, 1e18, 1.2e18), 0.005e18, "quote did not track rate ratio");
    }

    function test_computeInvariant_usesEffectiveWeights() public {
        // Invariant equals WeightedMath.computeInvariantDown over [virtualTTA, derivedY]
        // with the effective weights for the forced rate ratio.
        uint256 currentRate = seRateProvider.getRate();
        _setBaselineRate(Math.mulDiv(currentRate, 1e18, 1.2e18));
        (uint256 wTta, uint256 wShares) = new CommonHarness().effectiveWeights(1.2e18, 1e18);

        uint256[] memory bals = _liveBalances();
        uint256[] memory weights = new uint256[](2);
        uint256[] memory balances = new uint256[](2);
        weights[ttaIdx] = wTta;
        weights[sharesIdx] = wShares;
        balances[ttaIdx] = _virtualTTA();
        balances[sharesIdx] = bals[sharesIdx]; // hookSharesDelta is 0 here, so derivedY == live
        uint256 expected = WeightedMath.computeInvariantDown(weights, balances);

        uint256 got = IBalancerV3Pool(bufferPool).computeInvariant(bals, Rounding.ROUND_DOWN);
        assertApproxEqRel(got, expected, 1e6);
    }
```

Import `CommonHarness` from the Task 1 test file (or redeclare the two-line harness locally) plus `WeightedMath` and `Math`.

- [ ] **Step 2: Run to verify the new tests fail**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol" -vv`
Expected: `test_onSwap_quoteScalesInverselyWithRateRatio` FAILS (old CP math ignores `baselineRate`, so `out2 == out1`) and `test_computeInvariant_usesEffectiveWeights` FAILS (old invariant is `sqrt(x*y)`). The 50/50 parity test passes trivially pre-refactor; it exists to pin behavior through the change.

- [ ] **Step 3: Rewrite `StandardExchangeBufferPoolTarget.sol`**

Full replacement of the math (contract now inherits `Common`; its local `_derivedY`/`_liftSharesToScaled18Rated` are deleted):

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferPoolTarget
 * @notice Rate-tracking weighted AMM pool target where x = virtualTTA (virtual, from storage)
 *         and y is derived from the Vault-supplied live shares balance minus the hook's
 *         accumulated delta. Effective weights carry currentRate/baselineRate so the pool's
 *         marginal price tracks the Vault-configured rate provider (NAV) directly:
 *         TTA per raw share = (wShares/wTta) * virtualTTA / parShares.
 *         At currentRate == baselineRate the weights are 50/50 — exactly the previous
 *         constant-product behavior.
 * @dev Implements IBalancerV3Pool (computeInvariant, computeBalance, onSwap).
 */
contract StandardExchangeBufferPoolTarget is StandardExchangeBufferPoolCommon, IBalancerV3Pool {

    /**
     * @notice Pool invariant: x^wTta * y^wShares with rate-scaled effective weights.
     * @param balancesLiveScaled18 Token balances after decimal scaling and rates (from Vault).
     * @param rounding Rounding direction.
     */
    function computeInvariant(uint256[] memory balancesLiveScaled18, Rounding rounding)
        public view virtual override returns (uint256 invariant)
    {
        uint256 ttaIdx = StandardExchangeBufferPoolRepo._ttaIndex();
        uint256 sharesIdx = StandardExchangeBufferPoolRepo._sharesIndex();
        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();

        uint256[] memory weights = new uint256[](2);
        uint256[] memory balances = new uint256[](2);
        weights[ttaIdx] = wTta;
        weights[sharesIdx] = wShares;
        balances[ttaIdx] = StandardExchangeBufferPoolRepo._virtualTTA();
        balances[sharesIdx] = _derivedY(balancesLiveScaled18);

        invariant = rounding == Rounding.ROUND_DOWN
            ? WeightedMath.computeInvariantDown(weights, balances)
            : WeightedMath.computeInvariantUp(weights, balances);
    }

    /**
     * @notice New balance of a token after an operation, given an invariant ratio.
     */
    function computeBalance(uint256[] memory balancesLiveScaled18, uint256 tokenInIndex, uint256 invariantRatio)
        public view virtual override returns (uint256 newBalance)
    {
        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();
        bool isTta = (tokenInIndex == StandardExchangeBufferPoolRepo._ttaIndex());
        uint256 currentBalance = isTta
            ? StandardExchangeBufferPoolRepo._virtualTTA()
            : _derivedY(balancesLiveScaled18);
        newBalance = WeightedMath.computeBalanceOutGivenInvariant(
            currentBalance, isTta ? wTta : wShares, invariantRatio
        );
    }

    /**
     * @notice Execute a swap using weighted math over x = virtualTTA and y = derivedY,
     *         with rate-scaled effective weights.
     */
    function onSwap(PoolSwapParams calldata params)
        public view virtual override returns (uint256 amountCalculatedScaled18)
    {
        uint256 ttaIdx = StandardExchangeBufferPoolRepo._ttaIndex();
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(params.balancesScaled18);
        if (y == 0) revert IStandardExchangeBufferPool.PoolSharesSideExhausted();
        if (x == 0) revert IStandardExchangeBufferPool.PoolTTASideExhausted();

        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();

        bool ttaIn = (params.indexIn == ttaIdx);
        (uint256 balanceIn, uint256 weightIn, uint256 balanceOut, uint256 weightOut) = ttaIn
            ? (x, wTta, y, wShares)
            : (y, wShares, x, wTta);

        amountCalculatedScaled18 = params.kind == SwapKind.EXACT_IN
            ? WeightedMath.computeOutGivenExactIn(
                balanceIn, weightIn, balanceOut, weightOut, params.amountGivenScaled18)
            : WeightedMath.computeInGivenExactOut(
                balanceIn, weightIn, balanceOut, weightOut, params.amountGivenScaled18);
    }
}
```

- [ ] **Step 4: Update the hook to match**

In `StandardExchangeBufferHookTarget.sol`:

1. Add `SwapKind` to the VaultTypes import list and import `WeightedMath` (same path as the target).

2. In `_preSeatShares`, replace the fee/Y_TTA block (the lines computing `amountInPostFee` and `Y_TTA_raw = (x * amountInPostFee) / (y + amountInPostFee)`) with:

```solidity
        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();
        uint256 Y_TTA_raw;
        if (params.kind == SwapKind.EXACT_IN) {
            // The Vault deducts the swap fee from amountGiven before calling onSwap;
            // replicate so the pre-seated TTA matches onSwap's output exactly.
            uint256 swapFeePercentage = vault.getStaticSwapFeePercentage(pool);
            uint256 feeAmount =
                Math.mulDiv(params.amountGivenScaled18, swapFeePercentage, 1e18, Math.Rounding.Ceil);
            Y_TTA_raw = WeightedMath.computeOutGivenExactIn(
                y, wShares, x, wTta, params.amountGivenScaled18 - feeAmount
            );
        } else {
            // EXACT_OUT shares->TTA: the given amount IS the TTA the Vault must deliver
            // (TTA is an 18-decimal STANDARD token: scaled18 == raw).
            Y_TTA_raw = params.amountGivenScaled18;
        }
```

(`vault` here is the existing local `IVault vault = IVault(_balancerV3Vault());` — keep the surrounding code, including the `Y_TTA_raw > x` underflow guard, unchanged.)

3. In `onAfterSwap`, make the shares→TTA branch kind-correct — replace
`uint256 actualTTAOut = params.amountCalculatedRaw;` with:

```solidity
            // TTA delivered to the user. Correct for BOTH kinds: TTA is an 18-decimal
            // STANDARD token, so amountOutScaled18 == amountOutRaw. (amountCalculatedRaw
            // is the shares side for EXACT_OUT and would corrupt virtualTTA.)
            uint256 actualTTAOut = params.amountOutScaled18;
```

- [ ] **Step 5: Run the full pool suite; tune tolerances**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*" -vv`
Expected: the three new tests PASS. Pre-existing tests that assert exact swap outputs or exact invariant/BPT values may fail by a few wei (rounding: `divUp`+`complement` vs `mulDiv`; pow-based invariant vs `Math.sqrt`). Fix ONLY by relaxing exact `assertEq` to `assertApproxEqAbs(a, b, 2)` for amounts, `assertApproxEqRel(a, b, 1e9)` for invariant/BPT values — never by changing production code to chase old constants. Tests that push swaps > 30% of a pool side will now revert `MaxInRatio`/`MaxOutRatio`; cap those trade sizes or assert the revert.

- [ ] **Step 6: Commit**

```bash
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/ \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/
git commit -m "feat(buffer-pool): rate-tracking weighted math with Vault-sourced effective weights"
```

---

### Task 4: Uniswap V2-backed integration base + rate-tracking integration tests (no mocks)

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool_UniV2.sol`
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_RateTracking.t.sol`

**Interfaces:**
- Consumes: `StandardExchangeBufferPoolStandardVaultPkg.deployPool(IStandardExchange seVault, IERC20 tta)`, `UniswapV2StandardExchangeDFPkg` deployment flow (see `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol`, which composes `TestBase_Permit2`, `TestBase_UniswapV2`, `TestBase_VaultComponents`), the Balancer V3 wiring from `bases/TestBase_StandardExchangeBufferPool.sol`.
- Produces: a reusable base exposing `bufferPool` (address), `seVault` (IStandardExchange), `seRateProvider` (IRateProvider), `tta` (IERC20), `shareToken` (IERC20), and `_shiftRateUp() returns (uint256 newRate)` / `_shiftRateDown() returns (uint256 newRate)` helpers. Task 5's regression test reuses this base.

- [ ] **Step 1: Build the base**

Create `TestBase_StandardExchangeBufferPool_UniV2.sol`. Construction recipe (both source bases are in-repo; copy their concrete calls rather than inventing new wiring):

1. From `TestBase_UniswapV2StandardExchange` (contracts/protocols/dexes/uniswap/v2/test/bases/): reuse its `setUp` chain to deploy the Uniswap V2 factory/router/pair, seed the pair with two 18-decimal test tokens (call them `tta` and `counterAsset`; `tta` is the rate target), and deploy the Uniswap V2 Standard Exchange vault (`UniswapV2StandardExchangeDFPkg`) over that pair. The SE vault's share NAV in `tta` terms is a function of the pair's reserves.
2. From `TestBase_StandardExchangeBufferPool` (this directory's `bases/`): reuse its Balancer V3 section verbatim — Crane Balancer V3 VaultMock deployment, `StandardExchangeRateProviderDFPkg` deployment pointed at the SE vault with `rateTarget = tta`, `StandardExchangeBufferPoolStandardVaultPkg.deployPool(seVault, tta)`, pool initialization with seeded shares. Only the SE vault construction differs.
3. Add the rate levers — real trades through the underlying Uniswap V2 pair:

```solidity
    /**
     * @dev Moves the SE share NAV (in TTA terms) by trading through the underlying
     *      Uniswap V2 pair. Buying counterAsset with TTA raises counterAsset's TTA
     *      price; LP value in TTA terms ~ 2*sqrt(k * p_counter), so the share NAV —
     *      and therefore seRateProvider.getRate() — rises. Swap fees push NAV up in
     *      both directions, so _shiftRateDown trades the opposite way and asserts
     *      the net effect.
     */
    function _shiftRateUp() internal returns (uint256 newRate) {
        uint256 before = seRateProvider.getRate();
        uint256 amountIn = tta.balanceOf(address(this)) / 10;
        _swapThroughV2Pair(tta, counterAsset, amountIn);
        newRate = seRateProvider.getRate();
        assertGt(newRate, before, "rate did not increase");
    }

    function _shiftRateDown() internal returns (uint256 newRate) {
        uint256 before = seRateProvider.getRate();
        uint256 amountIn = counterAsset.balanceOf(address(this)) / 10;
        _swapThroughV2Pair(counterAsset, tta, amountIn);
        newRate = seRateProvider.getRate();
        assertLt(newRate, before, "rate did not decrease");
    }
```

`_swapThroughV2Pair` uses the same router-call pattern as the swap helpers already present in `TestBase_UniswapV2StandardExchange`'s spec tests (`test/foundry/spec/protocol/dexes/uniswap/v2/`); mint/deal the input token to the test contract as those tests do. If `_shiftRateDown`'s fee accrual outweighs the price move at the chosen size, increase `amountIn` until the assertion holds deterministically.

- [ ] **Step 2: Write the integration tests**

`StandardExchangeBufferPool_RateTracking.t.sol`, inheriting the new base:

```solidity
contract StandardExchangeBufferPool_RateTrackingTest is TestBase_StandardExchangeBufferPool_UniV2 {

    /// Pool quotes NAV at initialization (equilibrium identity).
    function test_initialQuote_isNav() public {
        uint256 rate = seRateProvider.getRate();
        uint256 dx = 1e15; // small trade => marginal price
        uint256 sharesOut = _quoteSwapExactIn(tta, shareToken, dx); // direct onSwap quote helper
        // NAV: TTA per raw share = scalingFactor * rate / 1e18; invert for shares-out.
        uint256 expected = Math.mulDiv(dx, 1e18, _navTtaPerRawShare(rate));
        assertApproxEqRel(sharesOut, expected, 0.01e18);
    }

    /// The headline property: after real V2 trades move the NAV, the pool re-quotes
    /// proportionally with NO trades against the buffer pool itself.
    function test_quoteTracksRate_upAndDown() public {
        uint256 dx = 1e15;
        uint256 r1 = seRateProvider.getRate();
        uint256 out1 = _quoteSwapExactIn(tta, shareToken, dx);

        uint256 r2 = _shiftRateUp();
        uint256 out2 = _quoteSwapExactIn(tta, shareToken, dx);
        assertApproxEqRel(out2, Math.mulDiv(out1, r1, r2), 0.005e18, "up-shift not tracked");

        uint256 r3 = _shiftRateDown();
        uint256 out3 = _quoteSwapExactIn(tta, shareToken, dx);
        assertApproxEqRel(out3, Math.mulDiv(out1, r1, r3), 0.005e18, "down-shift not tracked");
    }

    /// Full-path swap (through the Balancer Vault + hook) executes near NAV after a shift.
    function test_fullPathSwap_executesNearNav_afterRateShift() public {
        uint256 r = _shiftRateUp();
        uint256 dx = 1e16;
        uint256 sharesReceived = _swapThroughBalancerVault(tta, shareToken, dx); // reuse the
        // swap-execution helper pattern from StandardExchangeBufferPool.spec.t.sol
        uint256 expected = Math.mulDiv(dx, 1e18, _navTtaPerRawShare(r));
        // fee + finite-size slippage tolerance
        assertApproxEqRel(sharesReceived, expected, 0.07e18);
    }

    /// Effective-weight bound: force an extreme baseline via vm.store ONLY to prove the
    /// guard path (production state cannot reach it without ~99x rate drift).
    function test_extremeRateDrift_revertsEffectiveWeightOutOfBounds() public {
        uint256 BASELINE_RATE_OFFSET = 10;
        vm.store(
            bufferPool,
            bytes32(uint256(keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange")) + BASELINE_RATE_OFFSET),
            bytes32(uint256(seRateProvider.getRate() * 150))
        );
        vm.expectRevert(IStandardExchangeBufferPool.EffectiveWeightOutOfBounds.selector);
        _quoteSwapExactIn(tta, shareToken, 1e15);
    }

    /// No free lunch: a round trip after a rate shift returns strictly less than paid.
    function test_roundTrip_afterRateShift_losesFees() public {
        _shiftRateUp();
        uint256 dx = 1e16;
        uint256 shares = _swapThroughBalancerVault(tta, shareToken, dx);
        uint256 back = _swapThroughBalancerVault(shareToken, tta, shares);
        assertLt(back, dx);
    }
}
```

`_quoteSwapExactIn` calls `IBalancerV3Pool(bufferPool).onSwap` directly with `PoolSwapParams` built from `IVault.getPoolTokenRates`-fresh live balances (pattern already in `StandardExchangeBufferPoolTarget.t.sol`); `_navTtaPerRawShare(rate)` returns `scalingFactor * rate / 1e18` for the share token.

- [ ] **Step 3: Run**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_RateTracking.t.sol" -vv`
Expected: all PASS. `test_fullPathSwap_executesNearNav_afterRateShift` may FAIL with `PostSwapDepositFailed` if the rate shift is large — that is the Task 5 defect; if so, mark it with a `// Task 5 unblocks this` skip (`vm.skip(true)`) and un-skip in Task 5.

- [ ] **Step 4: Commit**

```bash
git add test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/
git commit -m "test(buffer-pool): UniswapV2 SE vault integration base and rate-tracking tests"
```

---

### Task 5: Best-effort TTA→shares reconcile (remove the NAV-drift revert path)

**Files:**
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_PostSwap.t.sol` (update), `StandardExchangeBufferPool_RateTracking.t.sol` (un-skip)

**Interfaces:**
- Consumes: `IStandardExchange.exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline) returns (uint256 amountOut)`; `_bv3SharesDonationRaw` (Task 1).
- Produces: `_reconcileTTAToShares(uint256 X_raw)` (single parameter — the `sharesOut` parameter is removed; callers updated).

Rationale: the old reconcile mints **exactly** `sharesOut` via `exchangeOut` with an `X_raw` budget. Whenever the pool's execution price is below NAV (post-shift imbalance, slippage on large trades), minting `sharesOut` costs more than `X_raw` and the whole swap reverts `PostSwapDepositFailed`. The buffer does not need exactly `sharesOut`: the user's shares are physically delivered from pool reserves; the reconcile only converts the incoming TTA into shares. Depositing all of `X_raw` best-effort keeps `derivedY` correct for ANY minted amount `M`, because the donation credits the pool balance with `M` and `hookSharesDelta` grows by the same round-tripped amount — the two cancel in `derivedY`.

- [ ] **Step 1: Write the failing test**

In `StandardExchangeBufferPool_RateTracking.t.sol` (base from Task 4), un-skip / add:

```solidity
    /// Regression: TTA->shares through the full path after an upward NAV shift used to
    /// revert PostSwapDepositFailed (exchangeOut needed more TTA than the user paid).
    function test_ttaToShares_afterUpwardNavShift_succeeds() public {
        _shiftRateUp();
        uint256 dx = 1e16;
        uint256 sharesReceived = _swapThroughBalancerVault(tta, shareToken, dx);
        assertGt(sharesReceived, 0);
    }
```

- [ ] **Step 2: Run to verify current behavior**

Run: `forge test --match-test test_ttaToShares_afterUpwardNavShift_succeeds -vv`
Expected: FAIL (revert `PostSwapDepositFailed`) — or, if the Task 3 re-pricing already keeps the drift inside the fee margin at this trade size, increase the shift/trade size until the failure reproduces, so the fix is actually exercised.

- [ ] **Step 3: Replace `_reconcileTTAToShares`**

New implementation (replaces the whole function; note the signature change):

```solidity
    /**
     * @dev TTA->shares post-swap reconcile, best-effort:
     *      1. Drain the X_raw TTA the swap added to the pool into this hook.
     *      2. Deposit ALL of it into the SE vault via exchangeIn, minting M shares to the
     *         Balancer Vault (M is whatever X_raw affords at NAV — the user's shares were
     *         already delivered from pool reserves, so no exact target is required).
     *      3. Settle the minted shares (round-trip capped, see _bv3SharesDonationRaw).
     *      4. DONATE [0, M] into the pool; the donation credits donationRaw to the pool
     *         balance and hookSharesDelta grows by the same amount, so derivedY is
     *         unchanged for ANY M.
     *      5. CUSTOM removeLiquidity [X_raw, 0] zeroes the swap-added TTA in pool balance.
     *      6. virtualTTA += X_raw.
     */
    function _reconcileTTAToShares(uint256 X_raw) internal {
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault();
        IERC20 ttaTok = Repo._ttaToken();
        IERC20 shareTok = Repo._shareToken();
        uint256 ttaIdx = Repo._ttaIndex();
        uint256 sharesIdx = Repo._sharesIndex();

        // 1) Drain the swap's TTA input.
        vault.sendTo(ttaTok, address(this), X_raw);

        // 2) Best-effort deposit of the full amount.
        ttaTok.approve(address(seVault), X_raw);
        uint256 minted = seVault.exchangeIn(
            ttaTok, X_raw, shareTok, 0, address(vault), false, block.timestamp
        );
        if (minted == 0) revert IStandardExchangeBufferPool.PostSwapDepositFailed(X_raw);

        // 3) Credit the Balancer Vault for the minted shares (round-trip capped).
        uint256 donationRaw = _bv3SharesDonationRaw(minted);
        vault.settle(shareTok, donationRaw);

        // 4) DONATE the minted shares into the pool.
        {
            uint256[] memory addAmts = new uint256[](2);
            addAmts[sharesIdx] = minted;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }

        // 5) Remove the swap-added TTA from the pool's balance.
        {
            uint256[] memory remAmts = new uint256[](2);
            remAmts[ttaIdx] = X_raw;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }

        // 6) Update state. derivedY: pool balance +donationRaw, delta +donationRaw — net zero.
        Repo._setVirtualTTA(Repo._virtualTTA() + X_raw);
        Repo._setHookSharesDelta(Repo._hookSharesDelta() + int256(donationRaw));
    }
```

Update the caller in `onAfterSwap` from `_reconcileTTAToShares(params.amountInScaled18, params.amountCalculatedRaw);` to:

```solidity
        _reconcileTTAToShares(params.amountInScaled18);
```

(TTA is an 18-decimal STANDARD token, so `amountInScaled18` equals the raw TTA paid for both swap kinds.)

- [ ] **Step 4: Run the PostSwap suite and the regression test**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*" -vv`
Expected: regression test PASSES. `StandardExchangeBufferHookTarget_PostSwap.t.sol` assertions about the exact minted amount / TTA surplus must be updated: there is no longer a `ttaSurplus` leg (all `X_raw` is deposited), and the shares credited equal whatever `exchangeIn` mints — assert instead that (a) the Vault session settles (no `BalanceNotSettled`), (b) `virtualTTA` grew by exactly `X_raw`, (c) `hookSharesDelta` grew by `_bv3SharesDonationRaw(minted)`, and (d) the user received the swap's quoted shares.

- [ ] **Step 5: Commit**

```bash
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/
git commit -m "fix(buffer-pool): best-effort TTA->shares reconcile; remove NAV-drift revert path"
```

---

### Task 6: Invariant handler update, full-suite verification, NatSpec sweep

**Files:**
- Modify: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/Handler_StandardExchangeBufferPool.sol` (if it recomputes the CP invariant)
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol` + `StandardExchangeBufferPoolLiquidityFacet.sol` (comment/NatSpec only, unless they embed CP math — verify)
- Test: whole `standardExchange` spec directory + `StandardExchangeBufferPool.spec.t.sol`

**Interfaces:**
- Consumes: everything produced in Tasks 1–5.
- Produces: green suite; documentation consistent with weighted rate-tracking math.

- [ ] **Step 1: Audit the liquidity target and handler for CP assumptions**

Run: `grep -n "sqrt\|constant.product\|x \* y\|mulDiv(outSide" contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*.sol test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/Handler_StandardExchangeBufferPool.sol`

For every hit in the handler that recomputes `sqrt(x*y)` as the conserved quantity, replace with the weighted invariant using the pool's own view (`IBalancerV3Pool(bufferPool).computeInvariant(liveBalances, Rounding.ROUND_DOWN)`) so the handler stays correct as weights drift; the invariant-growth property (invariant never decreases across swaps, modulo fees which make it grow) is unchanged. If `StandardExchangeBufferPoolLiquidityTarget.sol` only passes amounts through (CUSTOM add/remove bookkeeping) leave its code alone and update comments only.

- [ ] **Step 2: NatSpec sweep**

Update stale wording introduced by the refactor — at minimum: `StandardExchangeBufferPoolTarget` contract header (done in Task 3), `IStandardExchangeBufferPool` header if it says constant-product, `StandardExchangeBufferHookTarget` function comments referencing "CP formula" (pre-seat now says "weighted formula"), and the `constProd/` README/PRD if one exists in the directory (check: `ls contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*.md`).

- [ ] **Step 3: Full suite + invariant runs**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/*" -vv`
Expected: ALL PASS, including the invariant/handler campaign in `StandardExchangeBufferPool.spec.t.sol`.

Then run the two adjacent suites that share infrastructure, to catch collateral breakage:
`forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/*" -q` and `forge test --match-path "test/foundry/spec/protocol/dexes/uniswap/v2/*" -q`
Expected: PASS (or failures demonstrably pre-existing on the base branch — verify with `git stash && forge test ... && git stash pop` before touching anything).

- [ ] **Step 4: Commit**

```bash
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/ \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/
git commit -m "test(buffer-pool): weighted-invariant handler, NatSpec sweep, full-suite verification"
```

---

## Deliberately Out of Scope

- Multi-token (N-share) generalization — planned as a follow-up once this two-token version is proven.
- `paysYieldFees` enablement (registration config change, orthogonal).
- The `onAfterAddLiquidity` UNBALANCED "eventual zero TTA" semantics — unchanged.
- Rebaselining `baselineRate` post-initialization (governance lever for extreme drift) — the 1%-weight guard reverts safely at ~99x drift; add a rebaseline function only if a real deployment approaches the bound.

## Verification Summary (what "done" means)

1. `IStandardExchangeBufferPool(pool).baselineRate()` equals the Vault-reported rate at init.
2. A real trade through the underlying Uniswap V2 pair that moves `getRate()` by X% moves the buffer pool's marginal quote by X% in the same direction, with zero trades against the buffer pool itself (Task 4's `test_quoteTracksRate_upAndDown`).
3. All rate reads in pool/hook go through `IVault.getPoolTokenRates` (grep for `_rateProvider().getRate()` under `constProd/standardExchange/` returns only the Repo accessor definition and registration validation).
4. TTA→shares swaps no longer revert after upward NAV drift (Task 5 regression).
5. Full `standardExchange` spec + invariant suite green.
