# Standard Exchange Buffer Pool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Balancer V3 constant-product pool + bound IHooks facet that pairs a Standard Exchange Vault share with one of its underlyings (TTA), maintaining a strict zero-actual-TTA invariant and pricing off `virtualTTA · derivedShares` with `derivedShares = max(0, actualShares - hookSharesDelta_rated)`.

**Architecture:** Single Crane Diamond containing all facets — IBasePool math, IPoolLiquidity (custom add/remove for reconcile), IHooks (pre-seat + reconcile orchestration), and the standard Balancer V3 pool token / authentication / vault-aware facets. Hook lives at `address(pool)`. Hook drives `Vault.sendTo` + Standard Exchange Vault `exchangeIn/Out` + `Vault.settle` + custom add/remove cycles to keep actual TTA balance at zero while keeping per-pool bookkeeping consistent.

**Tech Stack:** Solidity 0.8.30, Foundry, Crane (Diamond Factory Packages, CREATE3 deployment), Balancer V3 (Vault, IHooks, IBasePool, IPoolLiquidity), Standard Exchange Vault (`IStandardExchange`), Indexedex Vault Registry.

**Spec:** `docs/superpowers/specs/2026-05-31-standard-exchange-buffer-pool-design.md`

**Target dir:** `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/`

**Test dir:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/` (mirror tree)

---

## File Structure

### New production files (all under `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/`)

| File | Responsibility |
|---|---|
| `IStandardExchangeBufferPool.sol` | Public interface: storage getters, typed errors, events |
| `StandardExchangeBufferPoolRepo.sol` | Storage repo (diamond storage): `virtualTTA` (uint256), `hookSharesDelta` (int256), immutables (TTA, shares, SE vault, rate provider, shares index in pool) |
| `StandardExchangeBufferPoolTarget.sol` | CP math: `computeInvariant`, `computeBalance`, `onSwap`. Uses `virtualTTA` + derived `y`. |
| `StandardExchangeBufferPoolFacet.sol` | Facet wrapper for `StandardExchangeBufferPoolTarget`. |
| `StandardExchangeBufferPoolLiquidityTarget.sol` | `IPoolLiquidity.onAddLiquidityCustom`, `IPoolLiquidity.onRemoveLiquidityCustom`. Only callable by the pool's own hook facet (validated via `address(this)` check inside the Vault unlock session). |
| `StandardExchangeBufferPoolLiquidityFacet.sol` | Facet wrapper for the liquidity target. |
| `StandardExchangeBufferHookTarget.sol` | `IHooks` implementation: `onRegister`, `getHookFlags`, `onBeforeInitialize`, `onBeforeSwap`, `onAfterSwap`, `onBeforeAddLiquidity`, `onAfterAddLiquidity`, `onAfterRemoveLiquidity`. |
| `StandardExchangeHookFacet.sol` | Facet wrapper for the hook target. |
| `StandardExchangeBufferPoolStandardVaultPkg.sol` | DFPkg: composes all facets with the spec's `LiquidityManagement` and `HookFlags`, registers pool with Balancer V3 Vault in `postDeploy`, exposes `deployPool` helper routing through `VaultRegistry.deployVault`. |
| `StandardExchangeBufferPool_FactoryService.sol` | CREATE3 deployment library: `deployStandardExchangeBufferPoolTarget`, `…Facet`, `…LiquidityTarget`, `…LiquidityFacet`, `…HookTarget`, `…HookFacet`, `…Pkg`, plus `buildPkgInit` helper. |

### New test files (under `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/`)

| File | Responsibility |
|---|---|
| `bases/TestBase_StandardExchangeBufferPool.sol` | Setup: deploy Balancer V3 Vault (or use harness), deploy Standard Exchange Vault, deploy our pool DFPkg, deploy + register + initialize the pool, fund test actors. |
| `behaviors/Behavior_StandardExchangeBufferPool_Registration.sol` | Registration behavior library (success + each failure path). |
| `behaviors/Behavior_StandardExchangeBufferPool_Initialization.sol` | Init seeds virtualTTA + hookSharesDelta correctly. |
| `behaviors/Behavior_StandardExchangeBufferPool_Swap_TTAtoShares.sol` | End-to-end TTA→shares assertions. |
| `behaviors/Behavior_StandardExchangeBufferPool_Swap_SharesToTTA.sol` | End-to-end shares→TTA assertions; `Y_TTA_final == Y_TTA` invariant. |
| `behaviors/Behavior_StandardExchangeBufferPool_LP_AddProportional.sol` | LP add (with and without TTA contribution). |
| `behaviors/Behavior_StandardExchangeBufferPool_LP_RemoveProportional.sol` | LP remove (shares only). |
| `behaviors/Behavior_StandardExchangeBufferPool_Clamping.sol` | Drive `derived_y → 0` and `virtualTTA → 0`; assert typed reverts. |
| `behaviors/Behavior_StandardExchangeBufferPool_Errors.sol` | One assertion per typed error. |
| `StandardExchangeBufferPoolRepo.t.sol` | Storage repo unit tests. |
| `StandardExchangeBufferPoolTarget.t.sol` | Pure CP math unit tests. |
| `StandardExchangeBufferPool.spec.t.sol` | Integration spec — runs each behavior library against the test base. |
| `Handler_StandardExchangeBufferPool.sol` | Invariant handler exposing user actions + rate-drift actor. |
| `StandardExchangeBufferPool.invariant.t.sol` | Foundry invariant test, runs handlers + asserts spec section 8.3 invariants. |

### Fork test (under `test/foundry/fork/base_main/balancer/v3/`)

| File | Responsibility |
|---|---|
| `Fork_StandardExchangeBufferPool.t.sol` | Deploys against the live Balancer V3 Vault on Sepolia, exercises the Behavior libraries end-to-end. |

### No deletions / no modifications to existing pool DFPkg

The existing `BalancerV3ConstantProductPoolStandardVaultPkg.sol` is a separate generic CP pool and stays as-is. Our pool is a sibling — different LM flags, different storage, different facet composition.

---

## Conventions to follow

- **Crane style**: section headers (`/* ----- Section ----- */`), imports grouped by source (Crane / Balancer V3 / OpenZeppelin / Indexedex), no emojis, no premature abstraction. Match the style of `BalancerV3ConstantProductPoolStandardVaultPkg.sol` and `StandardExchangeRateProviderDFPkg.sol`.
- **IERC20**: always Crane's `@crane/contracts/interfaces/IERC20.sol`, never OpenZeppelin's. Spec memory entry confirms this.
- **Storage repo**: diamond storage slot `keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange")`. Use the `_layout(bytes32)` + `_layout()` + per-field accessor pattern from `StandardExchangeRateProviderRepo`.
- **TDD**: every task writes failing test first, then minimal impl, then verifies, then commits. Tests under `test/foundry/spec/...`.
- **One commit per task** unless otherwise noted. Commit message format: `feat(pool): <task subject>` for new code, `test(pool): …` for test-only commits.
- **No skipping hooks** in test commits: `forge test` must pass at each commit boundary.

---

## Task 0: Verify clean baseline

**Files:** none modified

- [ ] **Step 1: Confirm working tree is clean**

```
git status --short
```
Expected: only the spec doc and this plan file modified/staged (or none).

- [ ] **Step 2: Run the full test suite as baseline**

```
forge build
forge test --no-match-path 'test/foundry/fork/**'
```
Expected: build succeeds; tests pass. If anything is red on `main`, stop and ask before continuing.

- [ ] **Step 3: Commit the spec and plan**

```
git add docs/superpowers/specs/2026-05-31-standard-exchange-buffer-pool-design.md docs/superpowers/plans/2026-05-31-standard-exchange-buffer-pool-plan.md
git commit -m "docs(pool): spec + plan for Standard Exchange Buffer Pool"
```

---

## Task 1: Interface — `IStandardExchangeBufferPool`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol`

- [ ] **Step 1: Write the interface**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

interface IStandardExchangeBufferPool {
    /* ----- Errors ----- */
    error NotHookCaller(address caller);
    error PreSeatRedemptionFailed(uint256 sharesAttempted, uint256 ttaExpected);
    error PostSwapDepositFailed(uint256 ttaAttempted);
    error VirtualTTAUnderflow(uint256 current, uint256 deduct);
    error PoolSharesSideExhausted();
    error PoolTTASideExhausted();
    error RateProviderZero();
    error SwapTooSmall();
    error AddLiquidityNotProportional();
    error InitialInvariantTooSmall();
    error InvalidPoolRegistration();

    /* ----- Views (storage getters) ----- */
    function virtualTTA() external view returns (uint256);
    function hookSharesDelta() external view returns (int256);
    function ttaToken() external view returns (IERC20);
    function shareToken() external view returns (IERC20);
    function standardExchangeVault() external view returns (IStandardExchange);
    function rateProvider() external view returns (IRateProvider);
    function ttaIndex() external view returns (uint256);
    function sharesIndex() external view returns (uint256);
}
```

- [ ] **Step 2: Build to verify it compiles standalone**

```
forge build --skip test
```

- [ ] **Step 3: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol
git commit -m "feat(pool): interface for Standard Exchange Buffer Pool"
```

---

## Task 2: Storage repo — `StandardExchangeBufferPoolRepo`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.t.sol`

- [ ] **Step 1: Write failing tests for storage repo**

```solidity
// test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.t.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

contract StandardExchangeBufferPoolRepoHarness {
    function init(
        IERC20 tta,
        IERC20 shares,
        IStandardExchange seVault,
        IRateProvider rp,
        uint256 ttaIdx,
        uint256 sharesIdx
    ) external {
        StandardExchangeBufferPoolRepo._initialize(tta, shares, seVault, rp, ttaIdx, sharesIdx);
    }
    function setVirtualTTA(uint256 v) external { StandardExchangeBufferPoolRepo._setVirtualTTA(v); }
    function getVirtualTTA() external view returns (uint256) { return StandardExchangeBufferPoolRepo._virtualTTA(); }
    function setHookSharesDelta(int256 v) external { StandardExchangeBufferPoolRepo._setHookSharesDelta(v); }
    function getHookSharesDelta() external view returns (int256) { return StandardExchangeBufferPoolRepo._hookSharesDelta(); }
    function getTTA() external view returns (IERC20) { return StandardExchangeBufferPoolRepo._ttaToken(); }
    function getShares() external view returns (IERC20) { return StandardExchangeBufferPoolRepo._shareToken(); }
    function getSeVault() external view returns (IStandardExchange) { return StandardExchangeBufferPoolRepo._standardExchangeVault(); }
    function getRP() external view returns (IRateProvider) { return StandardExchangeBufferPoolRepo._rateProvider(); }
    function getTtaIdx() external view returns (uint256) { return StandardExchangeBufferPoolRepo._ttaIndex(); }
    function getSharesIdx() external view returns (uint256) { return StandardExchangeBufferPoolRepo._sharesIndex(); }
}

contract StandardExchangeBufferPoolRepoTest is Test {
    StandardExchangeBufferPoolRepoHarness harness;
    function setUp() public { harness = new StandardExchangeBufferPoolRepoHarness(); }

    function test_initialize_setsAllImmutables() public {
        harness.init(IERC20(address(0x1)), IERC20(address(0x2)), IStandardExchange(address(0x3)), IRateProvider(address(0x4)), 0, 1);
        assertEq(address(harness.getTTA()), address(0x1));
        assertEq(address(harness.getShares()), address(0x2));
        assertEq(address(harness.getSeVault()), address(0x3));
        assertEq(address(harness.getRP()), address(0x4));
        assertEq(harness.getTtaIdx(), 0);
        assertEq(harness.getSharesIdx(), 1);
    }

    function test_virtualTTA_roundTrip() public {
        harness.setVirtualTTA(42e18);
        assertEq(harness.getVirtualTTA(), 42e18);
    }

    function test_hookSharesDelta_canBeNegative() public {
        harness.setHookSharesDelta(-100);
        assertEq(harness.getHookSharesDelta(), -100);
        harness.setHookSharesDelta(int256(7e18));
        assertEq(harness.getHookSharesDelta(), int256(7e18));
    }
}
```

- [ ] **Step 2: Run test, confirm it fails**

```
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.t.sol' -vv
```
Expected: fails to compile (`StandardExchangeBufferPoolRepo` not found).

- [ ] **Step 3: Write the repo**

```solidity
// contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

library StandardExchangeBufferPoolRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange");

    struct Storage {
        // Immutable after _initialize:
        IERC20 ttaToken;
        IERC20 shareToken;
        IStandardExchange standardExchangeVault;
        IRateProvider rateProvider;
        uint256 ttaIndex;
        uint256 sharesIndex;
        // Live state:
        uint256 virtualTTA;
        int256 hookSharesDelta;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage l) {
        assembly { l.slot := slot_ }
    }
    function _layout() internal pure returns (Storage storage) { return _layout(STORAGE_SLOT); }

    function _initialize(
        IERC20 tta,
        IERC20 shares,
        IStandardExchange seVault,
        IRateProvider rp,
        uint256 ttaIdx,
        uint256 sharesIdx
    ) internal {
        Storage storage l = _layout();
        l.ttaToken = tta;
        l.shareToken = shares;
        l.standardExchangeVault = seVault;
        l.rateProvider = rp;
        l.ttaIndex = ttaIdx;
        l.sharesIndex = sharesIdx;
    }

    function _ttaToken() internal view returns (IERC20) { return _layout().ttaToken; }
    function _shareToken() internal view returns (IERC20) { return _layout().shareToken; }
    function _standardExchangeVault() internal view returns (IStandardExchange) { return _layout().standardExchangeVault; }
    function _rateProvider() internal view returns (IRateProvider) { return _layout().rateProvider; }
    function _ttaIndex() internal view returns (uint256) { return _layout().ttaIndex; }
    function _sharesIndex() internal view returns (uint256) { return _layout().sharesIndex; }

    function _virtualTTA() internal view returns (uint256) { return _layout().virtualTTA; }
    function _setVirtualTTA(uint256 v) internal { _layout().virtualTTA = v; }

    function _hookSharesDelta() internal view returns (int256) { return _layout().hookSharesDelta; }
    function _setHookSharesDelta(int256 v) internal { _layout().hookSharesDelta = v; }
}
```

- [ ] **Step 4: Run test, confirm it passes**

```
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.t.sol' -vv
```
Expected: all 3 tests pass.

- [ ] **Step 5: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.t.sol
git commit -m "feat(pool): storage repo for Standard Exchange Buffer Pool"
```

---

## Task 3: Pool math target — `StandardExchangeBufferPoolTarget`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol`

The target uses `virtualTTA` for the TTA side and `derived_y = max(0, balancesLiveScaled18[sharesIdx] - hookSharesDelta_scaled18_rated)` for the shares side. The scaled-18 + rate conversion of `hookSharesDelta` comes from the Vault's `tokenRates` — but at math-time we only have `balancesLiveScaled18`. So we store `tokenRates[sharesIdx]` implicitly: we recover it as `balancesLiveScaled18[sharesIdx] / balancesRaw[sharesIdx] * 1e18` when needed, OR (simpler) we let the rate-application happen at hook-update time and store `hookSharesDelta_scaled18_rated` directly in storage.

**Decision (re-stated for implementation):** store `hookSharesDelta` in raw shares units; convert to scaled-18 + rated at math-time using a known scaling factor and the current rate. The pool reads the rate at math-time via the rate provider stored in the repo. This matches the spec's "re-apply the current rate on every read" decision.

- [ ] **Step 1: Write failing tests for the math**

```solidity
// test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {StandardExchangeBufferPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol";

contract StaticRateProvider is IRateProvider {
    uint256 immutable RATE;
    constructor(uint256 r) { RATE = r; }
    function getRate() external view returns (uint256) { return RATE; }
}

contract PoolUnderTest is StandardExchangeBufferPoolTarget {
    constructor(IRateProvider rp) {
        // Set up storage as the DFPkg would.
        StandardExchangeBufferPoolRepo._initialize(
            IERC20(address(0x1)), IERC20(address(0x2)), IStandardExchange(address(0x3)),
            rp, 0, 1
        );
    }
    function setVirtualTTA(uint256 v) external { StandardExchangeBufferPoolRepo._setVirtualTTA(v); }
    function setHookSharesDelta(int256 v) external { StandardExchangeBufferPoolRepo._setHookSharesDelta(v); }
}

contract StandardExchangeBufferPoolTargetTest is Test {
    PoolUnderTest pool;
    function setUp() public {
        // Rate = 1e18 (1:1). Decimal scaling factor 1.
        pool = new PoolUnderTest(new StaticRateProvider(1e18));
        pool.setVirtualTTA(100e18);
        pool.setHookSharesDelta(0);
    }

    function _buildSwapParams(SwapKind kind, uint256 idxIn, uint256 idxOut, uint256 amount, uint256[] memory bal)
        internal view returns (PoolSwapParams memory)
    {
        return PoolSwapParams({
            kind: kind, amountGivenScaled18: amount, balancesScaled18: bal,
            indexIn: idxIn, indexOut: idxOut, router: address(0), userData: ""
        });
    }

    function test_onSwap_TTAin_EXACT_IN_basicCP() public {
        // virtualTTA=100, derived_y=100 (actualShares=100, hookSharesDelta=0). Swap 10 TTA in.
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        uint256 out = pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 0, 1, 10e18, bal));
        // Y = 100 * 10 / (100 + 10) = 9.0909... e18
        assertApproxEqAbs(out, 9.090909090909090909e18, 1e9);
    }

    function test_onSwap_SharesIn_EXACT_IN_basicCP() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        uint256 out = pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 1, 0, 10e18, bal));
        // Y = 100 * 10 / (100 + 10) = 9.0909...
        assertApproxEqAbs(out, 9.090909090909090909e18, 1e9);
    }

    function test_onSwap_hookSharesDeltaShiftsDerivedY() public {
        // actualShares=100, hookSharesDelta=20 -> derived_y=80
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        pool.setHookSharesDelta(int256(20e18));
        uint256 out = pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 0, 1, 10e18, bal));
        // Y = 80 * 10 / (100 + 10) = 7.2727...
        assertApproxEqAbs(out, 7.272727272727272727e18, 1e9);
    }

    function test_onSwap_revertsWhenSharesSideExhausted() public {
        // actualShares=100, hookSharesDelta=120 -> derived_y clamps to 0
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        pool.setHookSharesDelta(int256(120e18));
        vm.expectRevert(IStandardExchangeBufferPool.PoolSharesSideExhausted.selector);
        pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 0, 1, 10e18, bal));
    }

    function test_onSwap_revertsWhenTTASideExhausted() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        pool.setVirtualTTA(0);
        vm.expectRevert(IStandardExchangeBufferPool.PoolTTASideExhausted.selector);
        pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 1, 0, 10e18, bal));
    }

    function test_computeInvariant_sqrtOfXY() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        uint256 inv = pool.computeInvariant(bal, Rounding.ROUND_DOWN);
        // sqrt(100 * 100) = 100 (in scaled18)
        assertApproxEqAbs(inv, 100e18, 1e9);
    }
}
```

- [ ] **Step 2: Run test, confirm it fails to compile**

```
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol' -vv
```

- [ ] **Step 3: Write the target**

```solidity
// contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

contract StandardExchangeBufferPoolTarget is IBalancerV3Pool {
    using FixedPoint for uint256;

    /* ----- Derived y ----- */

    function _derivedY(uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        // balancesLiveScaled18[sharesIdx] already has decimal scaling + rate applied by the Vault.
        // hookSharesDelta is stored in raw shares; lift to scaled18 + rated using the same rate the Vault used.
        uint256 sharesIdx = StandardExchangeBufferPoolRepo._sharesIndex();
        int256 h = StandardExchangeBufferPoolRepo._hookSharesDelta();
        uint256 actualSharesScaled = balancesLiveScaled18[sharesIdx];
        if (h <= 0) {
            // hookSharesDelta is negative or zero — actual shares is at least the full derived y;
            // adding |h|*scaling*rate gives the larger derived value.
            uint256 add = _liftSharesToScaled18Rated(uint256(-h));
            unchecked { return actualSharesScaled + add; }
        }
        uint256 sub = _liftSharesToScaled18Rated(uint256(h));
        if (sub >= actualSharesScaled) return 0;
        unchecked { return actualSharesScaled - sub; }
    }

    /// @dev Reads the current rate from the rate provider; combines with the implicit scaling factor.
    /// For 18-decimal share tokens (common case) the decimal-scaling factor is 1e18; for other decimals
    /// the share token's metadata is consulted via the Vault's tokenRates path. We mirror that by
    /// querying the rate provider and the share token's decimals.
    function _liftSharesToScaled18Rated(uint256 rawShares) internal view returns (uint256) {
        if (rawShares == 0) return 0;
        uint256 rate = StandardExchangeBufferPoolRepo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        uint8 decimals = _shareDecimals();
        // scaled18 = rawShares * 10^(18 - decimals) * rate / 1e18
        uint256 scaleFactor = 10 ** (uint256(18) - uint256(decimals));
        return Math.mulDiv(rawShares * scaleFactor, rate, 1e18);
    }

    function _shareDecimals() internal view virtual returns (uint8) {
        // Decimals are read from the share token. Cached value is implicit via tokenRates path on Vault calls.
        IERC20Metadata m = IERC20Metadata(address(StandardExchangeBufferPoolRepo._shareToken()));
        return m.decimals();
    }

    /* ----- IBalancerV3Pool ----- */

    function computeInvariant(uint256[] memory balancesLiveScaled18, Rounding rounding)
        public view virtual override returns (uint256 invariant)
    {
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(balancesLiveScaled18);
        if (rounding == Rounding.ROUND_DOWN) {
            invariant = Math.sqrt(x * y);
        } else {
            invariant = Math.sqrt(x * y) + 1;
        }
    }

    function computeBalance(uint256[] memory balancesLiveScaled18, uint256 tokenInIndex, uint256 invariantRatio)
        public view virtual override returns (uint256 newBalance)
    {
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(balancesLiveScaled18);
        uint256 newInvariant = Math.mulDiv(Math.sqrt(x * y), invariantRatio, 1e18);
        uint256 other = (tokenInIndex == StandardExchangeBufferPoolRepo._ttaIndex()) ? y : x;
        newBalance = Math.mulDiv(newInvariant, newInvariant, other, Math.Rounding.Ceil);
    }

    function onSwap(PoolSwapParams calldata params) public view virtual override returns (uint256 amountCalculatedScaled18) {
        uint256 ttaIdx = StandardExchangeBufferPoolRepo._ttaIndex();
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(params.balancesScaled18);
        if (y == 0) revert IStandardExchangeBufferPool.PoolSharesSideExhausted();
        if (x == 0) revert IStandardExchangeBufferPool.PoolTTASideExhausted();

        bool ttaIn = (params.indexIn == ttaIdx);
        uint256 inSide = ttaIn ? x : y;
        uint256 outSide = ttaIn ? y : x;

        if (params.kind == SwapKind.EXACT_IN) {
            // dy = outSide * amountIn / (inSide + amountIn), round DOWN
            amountCalculatedScaled18 = Math.mulDiv(outSide, params.amountGivenScaled18, inSide + params.amountGivenScaled18);
        } else {
            // dx = inSide * amountOut / (outSide - amountOut), round UP
            amountCalculatedScaled18 =
                Math.mulDiv(inSide, params.amountGivenScaled18, outSide - params.amountGivenScaled18, Math.Rounding.Ceil);
        }
    }
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}
```

*Note: the `IERC20Metadata` shim inline is intentional — keeps the file self-contained. If the existing repo has a Crane `IERC20Metadata` import already, use that instead and drop the shim.*

- [ ] **Step 4: Run tests, confirm all 5 pass**

```
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol' -vv
```

- [ ] **Step 5: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.t.sol
git commit -m "feat(pool): CP math target with virtualTTA + hookSharesDelta"
```

---

## Task 4: Pool math facet — `StandardExchangeBufferPoolFacet`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolFacet.sol`

- [ ] **Step 1: Write the facet wrapper (no new test; covered transitively)**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {StandardExchangeBufferPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

contract StandardExchangeBufferPoolFacet is StandardExchangeBufferPoolTarget, IFacet {
    /* ----- IStandardExchangeBufferPool storage views ----- */

    function virtualTTA() external view returns (uint256) { return StandardExchangeBufferPoolRepo._virtualTTA(); }
    function hookSharesDelta() external view returns (int256) { return StandardExchangeBufferPoolRepo._hookSharesDelta(); }
    function ttaToken() external view returns (address) { return address(StandardExchangeBufferPoolRepo._ttaToken()); }
    function shareToken() external view returns (address) { return address(StandardExchangeBufferPoolRepo._shareToken()); }
    function standardExchangeVault() external view returns (address) { return address(StandardExchangeBufferPoolRepo._standardExchangeVault()); }
    function rateProvider() external view returns (address) { return address(StandardExchangeBufferPoolRepo._rateProvider()); }
    function ttaIndex() external view returns (uint256) { return StandardExchangeBufferPoolRepo._ttaIndex(); }
    function sharesIndex() external view returns (uint256) { return StandardExchangeBufferPoolRepo._sharesIndex(); }

    /* ----- IFacet ----- */

    function facetName() public pure returns (string memory) { return type(StandardExchangeBufferPoolFacet).name; }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](2);
        ifaces[0] = type(IBalancerV3Pool).interfaceId;
        ifaces[1] = type(IStandardExchangeBufferPool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IBalancerV3Pool.computeInvariant.selector;
        funcs[1] = IBalancerV3Pool.computeBalance.selector;
        funcs[2] = IBalancerV3Pool.onSwap.selector;
        funcs[3] = this.virtualTTA.selector;
        funcs[4] = this.hookSharesDelta.selector;
        funcs[5] = this.ttaToken.selector;
        funcs[6] = this.shareToken.selector;
        funcs[7] = this.standardExchangeVault.selector;
        funcs[8] = this.rateProvider.selector;
        funcs[9] = this.ttaIndex.selector;
        funcs[10] = this.sharesIndex.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName(); i = facetInterfaces(); f = facetFuncs();
    }
}
```

- [ ] **Step 2: Build to verify**

```
forge build --skip test
```

- [ ] **Step 3: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolFacet.sol
git commit -m "feat(pool): facet wrapper for CP math target"
```

---

## Task 5: Pool-liquidity target — custom add/remove for reconcile

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.t.sol`

The pool's `IPoolLiquidity` is used **only** by the hook during reconcile. Calling path: Vault.addLiquidity / removeLiquidity with `kind = CUSTOM` → Vault calls `IPoolLiquidity.onAddLiquidityCustom` / `onRemoveLiquidityCustom` on the pool. Vault passes `router = msg.sender of Vault.addLiquidity`. Since the hook is the pool itself and calls Vault directly, `router == address(this)` for legitimate calls.

For `onAddLiquidityCustom`: the hook passes the exact amount it wants donated; we accept any single-token contribution (TTA or shares) at full scaled18 face value, with `bptAmountOut = 0` (no minting), `swapFeeAmounts = [0, 0]`.

For `onRemoveLiquidityCustom`: same shape — accept any single-token withdrawal at face value, `bptAmountIn = 0` (no burning), `swapFeeAmounts = [0, 0]`. This effectively lets the hook move tokens off pool balance without burning BPT.

- [ ] **Step 1: Failing test**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {AddLiquidityKind, RemoveLiquidityKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol";

contract LiquidityTargetExposed is StandardExchangeBufferPoolLiquidityTarget {
    function callOnAdd(address router, uint256[] memory amts) external returns (uint256[] memory, uint256, uint256[] memory, bytes memory) {
        return this.onAddLiquidityCustom(router, amts, 0, new uint256[](2), "");
    }
}

contract StandardExchangeBufferPoolLiquidityTargetTest is Test {
    LiquidityTargetExposed t;
    function setUp() public { t = new LiquidityTargetExposed(); }

    function test_addCustom_acceptsFromSelf() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 5e18; amts[1] = 0;
        (uint256[] memory inScaled18, uint256 bptOut, uint256[] memory fees,) = t.callOnAdd(address(t), amts);
        assertEq(inScaled18[0], 5e18); assertEq(inScaled18[1], 0); assertEq(bptOut, 0); assertEq(fees.length, 2);
    }

    function test_addCustom_revertsForNonHookCaller() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 5e18; amts[1] = 0;
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, address(0xBEEF)));
        t.callOnAdd(address(0xBEEF), amts);
    }
}
```

- [ ] **Step 2: Confirm test fails to compile.**

- [ ] **Step 3: Write the target**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

contract StandardExchangeBufferPoolLiquidityTarget is IPoolLiquidity {
    function onAddLiquidityCustom(
        address router,
        uint256[] memory maxAmountsInScaled18,
        uint256 /*minBptAmountOut*/,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) public view virtual override returns (uint256[] memory amountsInScaled18, uint256 bptAmountOut, uint256[] memory swapFeeAmountsScaled18, bytes memory returnData) {
        if (router != address(this)) revert IStandardExchangeBufferPool.NotHookCaller(router);
        amountsInScaled18 = maxAmountsInScaled18;
        bptAmountOut = 0;
        swapFeeAmountsScaled18 = new uint256[](maxAmountsInScaled18.length);
        returnData = "";
    }

    function onRemoveLiquidityCustom(
        address router,
        uint256 /*maxBptAmountIn*/,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) public view virtual override returns (uint256 bptAmountIn, uint256[] memory amountsOutScaled18, uint256[] memory swapFeeAmountsScaled18, bytes memory returnData) {
        if (router != address(this)) revert IStandardExchangeBufferPool.NotHookCaller(router);
        bptAmountIn = 0;
        amountsOutScaled18 = minAmountsOutScaled18;
        swapFeeAmountsScaled18 = new uint256[](minAmountsOutScaled18.length);
        returnData = "";
    }
}
```

- [ ] **Step 4: Run tests, confirm both pass.**

- [ ] **Step 5: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.t.sol
git commit -m "feat(pool): pool-liquidity target for hook reconcile path"
```

---

## Task 6: Pool-liquidity facet — `StandardExchangeBufferPoolLiquidityFacet`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityFacet.sol`

- [ ] **Step 1: Write the facet (mirror Task 4's structure)**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {StandardExchangeBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol";

contract StandardExchangeBufferPoolLiquidityFacet is StandardExchangeBufferPoolLiquidityTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(StandardExchangeBufferPoolLiquidityFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ifs) {
        ifs = new bytes4[](1); ifs[0] = type(IPoolLiquidity).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory fns) {
        fns = new bytes4[](2);
        fns[0] = IPoolLiquidity.onAddLiquidityCustom.selector;
        fns[1] = IPoolLiquidity.onRemoveLiquidityCustom.selector;
    }
    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName(); i = facetInterfaces(); f = facetFuncs();
    }
}
```

- [ ] **Step 2: Build and commit**

```
forge build --skip test
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityFacet.sol
git commit -m "feat(pool): facet wrapper for pool-liquidity target"
```

---

## Task 7: Hook target — registration + initialization

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol` (first slice — registration + init only)

The hook target is large; we build it incrementally. This task adds `onRegister`, `getHookFlags`, and `onBeforeInitialize`.

- [ ] **Step 1: Failing test (registration + flags)**

```solidity
// test path: test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_Registration.t.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {HookFlags, TokenConfig, TokenType, LiquidityManagement} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {StandardExchangeBufferHookTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol";

contract HookHarness is StandardExchangeBufferHookTarget {
    address public immutable VAULT;
    address public immutable FACTORY;
    constructor(address v, address f, IERC20 tta, IERC20 sh, IStandardExchange sev, IRateProvider rp) {
        VAULT = v; FACTORY = f;
        StandardExchangeBufferPoolRepo._initialize(tta, sh, sev, rp, 0, 1);
    }
    function _balancerV3Vault() internal view override returns (address) { return VAULT; }
    function _expectedFactory() internal view override returns (address) { return FACTORY; }
}

contract HookRegistrationTest is Test {
    HookHarness h;
    address vault = address(0xCAFE);
    address factory = address(0xFACE);
    IERC20 tta = IERC20(address(0xA));
    IERC20 shares = IERC20(address(0xB));

    function setUp() public {
        h = new HookHarness(vault, factory, tta, shares, IStandardExchange(address(0xC)), IRateProvider(address(0xD)));
    }

    function _tc(IERC20 t, TokenType tt, address rp) internal pure returns (TokenConfig memory) {
        return TokenConfig({token: t, tokenType: tt, rateProvider: IRateProvider(rp), paysYieldFees: false});
    }

    function test_getHookFlags_matchesSpec() public view {
        HookFlags memory flags = h.getHookFlags();
        assertFalse(flags.enableHookAdjustedAmounts);
        assertTrue(flags.shouldCallBeforeInitialize);
        assertFalse(flags.shouldCallAfterInitialize);
        assertFalse(flags.shouldCallComputeDynamicSwapFee);
        assertTrue(flags.shouldCallBeforeSwap);
        assertTrue(flags.shouldCallAfterSwap);
        assertTrue(flags.shouldCallBeforeAddLiquidity);
        assertTrue(flags.shouldCallAfterAddLiquidity);
        assertFalse(flags.shouldCallBeforeRemoveLiquidity);
        assertTrue(flags.shouldCallAfterRemoveLiquidity);
    }

    function test_onRegister_acceptsValid() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(0xD));
        LiquidityManagement memory lm = LiquidityManagement({
            disableUnbalancedLiquidity: true,
            enableAddLiquidityCustom: true,
            enableRemoveLiquidityCustom: true,
            enableDonation: true
        });
        vm.prank(vault);
        bool ok = h.onRegister(factory, address(h), cfg, lm);
        assertTrue(ok);
    }

    function test_onRegister_rejectsWrongSender() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(0xD));
        LiquidityManagement memory lm = LiquidityManagement(true, true, true, true);
        vm.prank(address(0xDEAD));
        bool ok = h.onRegister(factory, address(h), cfg, lm);
        assertFalse(ok);
    }

    function test_onRegister_rejectsWrongTokenOrder() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(shares, TokenType.WITH_RATE, address(0xD));
        cfg[1] = _tc(tta, TokenType.STANDARD, address(0));
        LiquidityManagement memory lm = LiquidityManagement(true, true, true, true);
        vm.prank(vault);
        bool ok = h.onRegister(factory, address(h), cfg, lm);
        assertFalse(ok);
    }
}
```

- [ ] **Step 2: Confirm tests fail to compile.**

- [ ] **Step 3: Write the hook target — registration + init slice**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {
    HookFlags, TokenConfig, TokenType, LiquidityManagement,
    PoolSwapParams, AfterSwapParams, AddLiquidityKind, RemoveLiquidityKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

abstract contract StandardExchangeBufferHookTarget is IHooks {
    /* ----- Virtual hooks ----- */
    function _balancerV3Vault() internal view virtual returns (address);
    function _expectedFactory() internal view virtual returns (address);

    /* ----- Registration ----- */

    function getHookFlags() public pure virtual returns (HookFlags memory) {
        return HookFlags({
            enableHookAdjustedAmounts: false,
            shouldCallBeforeInitialize: true,
            shouldCallAfterInitialize: false,
            shouldCallComputeDynamicSwapFee: false,
            shouldCallBeforeSwap: true,
            shouldCallAfterSwap: true,
            shouldCallBeforeAddLiquidity: true,
            shouldCallAfterAddLiquidity: true,
            shouldCallBeforeRemoveLiquidity: false,
            shouldCallAfterRemoveLiquidity: true
        });
    }

    function onRegister(address factory, address pool, TokenConfig[] memory tokenConfig, LiquidityManagement calldata lm)
        public view virtual returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        if (factory != _expectedFactory()) return false;
        if (pool != address(this)) return false;
        if (tokenConfig.length != 2) return false;
        // Order: TTA (STANDARD) at ttaIndex, shares (WITH_RATE) at sharesIndex.
        uint256 ttaIdx = Repo._ttaIndex(); uint256 sharesIdx = Repo._sharesIndex();
        if (address(tokenConfig[ttaIdx].token) != address(Repo._ttaToken())) return false;
        if (address(tokenConfig[sharesIdx].token) != address(Repo._shareToken())) return false;
        if (tokenConfig[ttaIdx].tokenType != TokenType.STANDARD) return false;
        if (tokenConfig[sharesIdx].tokenType != TokenType.WITH_RATE) return false;
        if (address(tokenConfig[sharesIdx].rateProvider) != address(Repo._rateProvider())) return false;
        if (!lm.disableUnbalancedLiquidity || !lm.enableAddLiquidityCustom || !lm.enableRemoveLiquidityCustom || !lm.enableDonation) return false;
        return true;
    }

    /* ----- Initialization ----- */

    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory) public virtual returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        uint256 sharesIdx = Repo._sharesIndex();
        uint256 sInitRaw = exactAmountsIn[sharesIdx];
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        // virtualTTA = s_init * r, in scaled18. exactAmountsIn is raw; convert.
        // For simplicity in this slice we assume share token has 18 decimals; multi-decimal handled in Task TBD if needed.
        uint256 virtualInit = (sInitRaw * rate) / 1e18;
        if (virtualInit == 0) revert IStandardExchangeBufferPool.InitialInvariantTooSmall();
        Repo._setVirtualTTA(virtualInit);
        Repo._setHookSharesDelta(0);
        return true;
    }

    /* ----- Stubs for remaining IHooks methods (filled in later tasks) ----- */

    function onAfterInitialize(uint256[] memory, uint256, bytes memory) public virtual returns (bool) { return false; }
    function onBeforeAddLiquidity(address, address, AddLiquidityKind, uint256[] memory, uint256, uint256[] memory, bytes memory)
        public virtual returns (bool) { revert("unimplemented"); }
    function onAfterAddLiquidity(address, address, AddLiquidityKind, uint256[] memory, uint256[] memory, uint256, uint256[] memory, bytes memory)
        public virtual returns (bool, uint256[] memory) { revert("unimplemented"); }
    function onBeforeRemoveLiquidity(address, address, RemoveLiquidityKind, uint256, uint256[] memory, uint256[] memory, bytes memory)
        public virtual returns (bool) { return false; }
    function onAfterRemoveLiquidity(address, address, RemoveLiquidityKind, uint256, uint256[] memory, uint256[] memory, uint256[] memory, bytes memory)
        public virtual returns (bool, uint256[] memory) { revert("unimplemented"); }
    function onBeforeSwap(PoolSwapParams calldata, address) public virtual returns (bool) { revert("unimplemented"); }
    function onAfterSwap(AfterSwapParams calldata) public virtual returns (bool, uint256) { revert("unimplemented"); }
    function onComputeDynamicSwapFeePercentage(PoolSwapParams calldata, address, uint256)
        public view virtual returns (bool, uint256) { return (false, 0); }
}
```

- [ ] **Step 4: Run tests, confirm pass**

```
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_Registration.t.sol' -vv
```

- [ ] **Step 5: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_Registration.t.sol
git commit -m "feat(pool): hook target - registration + initialization"
```

---

## Task 8: Hook target — `onBeforeSwap` for `shares -> TTA` (pre-seat)

**Files:**
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_PreSeat.t.sol`

Implements step 3 of Section 6.3 of the spec. The pre-seat:
1. Compute `Y_TTA = x * X_rated / (y_pre + X_rated)`.
2. Compute `S = previewExchangeOut(shares, TTA, Y_TTA_raw)`.
3. `Vault.sendTo(shares, hook, S)`, then `IStandardExchangeOut.exchangeOut(shares, S, TTA, Y_TTA_raw, balancerVault, false, deadline)`.
4. `Vault.settle(TTA, Y_TTA_raw)`.
5. `Vault.addLiquidity(pool, hook, [Y_TTA_raw, 0], 0, DONATION, "")` and `Vault.removeLiquidity(pool, hook, 0, [0, S_raw], CUSTOM, "")`.
6. `virtualTTA -= Y_TTA_scaled18`, `hookSharesDelta -= int256(S)`.

The test uses **mocks** for the Balancer V3 Vault and the Standard Exchange Vault to assert the exact call sequence. Each Vault call is observed via `vm.expectCall`.

- [ ] **Step 1: Write the failing test**

(See `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_PreSeat.t.sol`. Build mocks `MockBalancerV3Vault` and `MockStandardExchange` that record calls and return scripted values. Assert: pre-seat issues exactly the 5 expected calls in order, updates `virtualTTA` and `hookSharesDelta` as specified, returns `true`.)

The mock interfaces:

```solidity
contract MockBalancerV3Vault {
    bytes[] public calls;
    uint256 public scriptedSettleReturn;
    function sendTo(address, address, uint256) external { calls.push(msg.data); }
    function settle(address, uint256) external returns (uint256) { calls.push(msg.data); return scriptedSettleReturn; }
    function addLiquidity(bytes calldata p) external { calls.push(msg.data); }
    function removeLiquidity(bytes calldata p) external { calls.push(msg.data); }
}

contract MockStandardExchange {
    uint256 public scriptedAmountOut;
    function previewExchangeOut(address, address, uint256) external view returns (uint256) { return scriptedAmountOut; }
    function exchangeOut(address, uint256, address, uint256, address, bool, uint256) external returns (uint256) { return scriptedAmountOut; }
}
```

Test cases:
- `test_preSeat_executesFiveVaultCallsInOrder()`: assert ordered: sendTo, exchangeOut, settle, addLiquidity, removeLiquidity (or whatever final ordering matches spec).
- `test_preSeat_updatesVirtualTTAAndHookSharesDelta()`: verify post-state.
- `test_preSeat_revertsIfRateProviderReturnsZero()`.
- `test_preSeat_revertsIfDerivedYIsZero()` with `PoolSharesSideExhausted`.

- [ ] **Step 2: Confirm tests fail.**

- [ ] **Step 3: Implement `onBeforeSwap`.** Branch on `params.indexIn`: if `== ttaIdx` return `true` no-op; otherwise execute the pre-seat sequence. Reference function calls into the Balancer V3 Vault use the `IVault` interface from `@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol`. Reference `IStandardExchangeOut.exchangeOut` for the redeem.

  Concrete signature path (use this exactly):

```solidity
function onBeforeSwap(PoolSwapParams calldata params, address pool)
    public override returns (bool)
{
    if (msg.sender != _balancerV3Vault()) return false;
    if (pool != address(this)) return false;

    uint256 ttaIdx = Repo._ttaIndex();
    if (params.indexIn == ttaIdx) {
        // TTA -> shares: no pre-seat needed.
        return true;
    }

    // shares -> TTA pre-seat.
    IVault vault = IVault(_balancerV3Vault());
    IStandardExchange seVault = Repo._standardExchangeVault();
    IERC20 shareTok = Repo._shareToken();
    IERC20 ttaTok = Repo._ttaToken();
    IRateProvider rp = Repo._rateProvider();

    uint256 x = Repo._virtualTTA();
    if (x == 0) revert IStandardExchangeBufferPool.PoolTTASideExhausted();

    // Derived y, mirroring StandardExchangeBufferPoolTarget._derivedY.
    uint256 y = _derivedY(params.balancesScaled18);
    if (y == 0) revert IStandardExchangeBufferPool.PoolSharesSideExhausted();

    // CP output (no fee here — fee is applied inside onSwap; this is sizing only).
    uint256 Y_TTA_scaled18 = (x * params.amountGivenScaled18) / (y + params.amountGivenScaled18);
    // Down-scale to raw TTA (assumes 18-decimal TTA; multi-decimal extension noted in Task TBD).
    uint256 Y_TTA_raw = Y_TTA_scaled18;

    // Compute S = exact shares needed to redeem Y_TTA_raw TTA.
    uint256 S = seVault.previewExchangeOut(IERC20(address(shareTok)), IERC20(address(ttaTok)), Y_TTA_raw);

    // 1) sendTo(shares, hook, S)
    vault.sendTo(IERC20(address(shareTok)), address(this), S);
    // 2) approve + exchangeOut
    shareTok.approve(address(seVault), S);
    uint256 got = seVault.exchangeOut(
        IERC20(address(shareTok)), S, IERC20(address(ttaTok)), Y_TTA_raw,
        address(vault), false, block.timestamp
    );
    if (got < Y_TTA_raw) revert IStandardExchangeBufferPool.PreSeatRedemptionFailed(S, Y_TTA_raw);
    // 3) settle
    vault.settle(IERC20(address(ttaTok)), Y_TTA_raw);

    // 4) addLiquidity(DONATION, [Y_TTA_raw, 0])
    uint256[] memory addAmts = new uint256[](2); addAmts[ttaIdx] = Y_TTA_raw;
    vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION, ""));

    // 5) removeLiquidity(CUSTOM, [0, S_raw])
    uint256[] memory remAmts = new uint256[](2); remAmts[Repo._sharesIndex()] = S;
    vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM, ""));

    // 6) Update state.
    if (Y_TTA_scaled18 > x) revert IStandardExchangeBufferPool.VirtualTTAUnderflow(x, Y_TTA_scaled18);
    Repo._setVirtualTTA(x - Y_TTA_scaled18);
    Repo._setHookSharesDelta(Repo._hookSharesDelta() - int256(S));
    return true;
}

function _derivedY(uint256[] memory bal) internal view returns (uint256) { /* same impl as pool target */ }
function _buildAddLiquidityParams(...) internal pure returns (AddLiquidityParams memory) { /* ... */ }
function _buildRemoveLiquidityParams(...) internal pure returns (RemoveLiquidityParams memory) { /* ... */ }
```

(The implementer should factor `_derivedY` into a shared library or have the hook call the pool's `IBalancerV3Pool` interface; this plan elects to duplicate the helper for clarity and gas. Confirm or refactor during implementation.)

- [ ] **Step 4: Tests pass.**

- [ ] **Step 5: Commit**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_PreSeat.t.sol
git commit -m "feat(pool): hook onBeforeSwap pre-seat for shares->TTA"
```

---

## Task 9: Hook target — `onAfterSwap` for `TTA -> shares` (post-swap reconcile)

**Files:**
- Modify: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol`
- Test: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget_PostSwap.t.sol`

Implements step 6 of Section 6.2 of the spec. The reconcile:
1. `Vault.sendTo(TTA, hook, X)`.
2. `IStandardExchangeIn.exchangeIn(TTA, X, shares, 0, balancerVault, false, deadline)` -> `Y'` shares minted to Balancer Vault.
3. `Vault.settle(shares, Y')`.
4. `Vault.removeLiquidity(CUSTOM, [X, 0])` and `Vault.addLiquidity(DONATION, [0, Y'])`.
5. `virtualTTA += X_scaled18`, `hookSharesDelta += int256(Y')`.

For `shares -> TTA` the after-swap body is a no-op (all reconciliation happened in pre-seat).

- [ ] **Step 1: Failing test (mirror Task 8 with `exchangeIn` direction; assert ordered calls + state updates; assert no-op when `params.tokenIn == shareToken`).**
- [ ] **Step 2: Confirm fail.**
- [ ] **Step 3: Implement `onAfterSwap` per the spec.**
- [ ] **Step 4: Tests pass.**
- [ ] **Step 5: Commit**

```
git commit -m "feat(pool): hook onAfterSwap reconcile for TTA->shares"
```

---

## Task 10: Hook target — LP `onBeforeAddLiquidity` (LP TTA -> shares conversion)

**Files:**
- Modify: `StandardExchangeBufferHookTarget.sol`
- Test: `StandardExchangeBufferHookTarget_LPAdd.t.sol`

Implements step 3 of Section 6.4. Reject non-PROPORTIONAL non-CUSTOM kinds (`AddLiquidityNotProportional`). For PROPORTIONAL with a TTA contribution: convert the LP's TTA into shares via `exchangeIn`, then donate + reconcile so the LP's effective contribution is shares-only. Update `hookSharesDelta += newlyMintedShares`.

- [ ] **Step 1: Failing test.**
- [ ] **Step 2: Confirm fail.**
- [ ] **Step 3: Implement `onBeforeAddLiquidity`.**
- [ ] **Step 4: Pass.**
- [ ] **Step 5: Commit**

```
git commit -m "feat(pool): hook onBeforeAddLiquidity converts LP TTA to shares"
```

---

## Task 11: Hook target — `onAfterAddLiquidity` and `onAfterRemoveLiquidity` proportional state updates

**Files:**
- Modify: `StandardExchangeBufferHookTarget.sol`
- Test: `StandardExchangeBufferHookTarget_LPProportional.t.sol`

Implements step 5 of Section 6.4 and step 4 of Section 6.5. Read `_totalSupply()` from the pool (the hook calls `IERC20(address(this)).totalSupply()` since the Diamond exposes the BPT ERC20 surface), recover `T_pre` (= `totalSupply() - bptOut` for add, `+ bptIn` for remove), and update `virtualTTA` and `hookSharesDelta` proportionally per the spec's Section 5.5 table. `virtualTTA` is clamped at zero on remove (defensive).

- [ ] **Step 1: Failing test (proportional add: virtualTTA + hookSharesDelta scale by `(T+bptOut)/T`; proportional remove: scale by `(T-bptIn)/T`; CP ratio preserved).**
- [ ] **Step 2: Confirm fail.**
- [ ] **Step 3: Implement both after-hooks.**
- [ ] **Step 4: Pass.**
- [ ] **Step 5: Commit**

```
git commit -m "feat(pool): hook proportional state updates on LP add/remove"
```

---

## Task 12: Hook facet — `StandardExchangeHookFacet`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeHookFacet.sol`

The facet must concretize the abstract `_balancerV3Vault()` and `_expectedFactory()`. Use a shared Crane repo for the Balancer V3 Vault address (`BalancerV3VaultAwareRepo` is already used elsewhere in this codebase). For the expected factory, store it in `StandardExchangeBufferPoolRepo` as an additional immutable, or use a small dedicated repo. Pick the path that requires the fewest new files.

**Decision:** add `expectedFactory` as an additional immutable field on `StandardExchangeBufferPoolRepo` (one-line repo extension). This avoids creating a separate repo just for one address.

- [ ] **Step 1: Extend `StandardExchangeBufferPoolRepo` with `expectedFactory` + accessor. Update the repo test to cover it. (Repo extension test follows the Task 2 pattern.)**

- [ ] **Step 2: Update `_initialize` signature in Tasks 2, 7, and DFPkg call sites to pass the factory.** (No commit yet — these updates land together with the facet in this Task's commit.)

- [ ] **Step 3: Write the facet.**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BalancerV3VaultAwareRepo} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {StandardExchangeBufferHookTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

contract StandardExchangeHookFacet is StandardExchangeBufferHookTarget, IFacet {
    function _balancerV3Vault() internal view override returns (address) { return address(BalancerV3VaultAwareRepo._balancerV3Vault()); }
    function _expectedFactory() internal view override returns (address) { return Repo._expectedFactory(); }

    function facetName() public pure returns (string memory) { return type(StandardExchangeHookFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory i) { i = new bytes4[](1); i[0] = type(IHooks).interfaceId; }
    function facetFuncs() public pure returns (bytes4[] memory f) {
        f = new bytes4[](11);
        f[0] = IHooks.onRegister.selector;
        f[1] = IHooks.getHookFlags.selector;
        f[2] = IHooks.onBeforeInitialize.selector;
        f[3] = IHooks.onAfterInitialize.selector;
        f[4] = IHooks.onBeforeAddLiquidity.selector;
        f[5] = IHooks.onAfterAddLiquidity.selector;
        f[6] = IHooks.onBeforeRemoveLiquidity.selector;
        f[7] = IHooks.onAfterRemoveLiquidity.selector;
        f[8] = IHooks.onBeforeSwap.selector;
        f[9] = IHooks.onAfterSwap.selector;
        f[10] = IHooks.onComputeDynamicSwapFeePercentage.selector;
    }
    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName(); i = facetInterfaces(); f = facetFuncs();
    }
}
```

- [ ] **Step 4: Build and commit.**

```
git add contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeHookFacet.sol \
        contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol \
        test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.t.sol
git commit -m "feat(pool): hook facet + expectedFactory in repo"
```

---

## Task 13: DFPkg — `StandardExchangeBufferPoolStandardVaultPkg`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol`

Mirror `BalancerV3ConstantProductPoolStandardVaultPkg.sol` (a peer-directory file) with these changes:
- Add the three new facets: `StandardExchangeBufferPoolFacet`, `StandardExchangeBufferPoolLiquidityFacet`, `StandardExchangeHookFacet`. Remove the generic `BALANCER_V3_CONST_PROD_POOL_FACET`.
- `_liquidityManagement()` returns `LiquidityManagement(disableUnbalancedLiquidity: true, enableAddLiquidityCustom: true, enableRemoveLiquidityCustom: true, enableDonation: true)`.
- `postDeploy`: register the pool with the Balancer V3 Vault, passing **`hooksContract = proxy`** (the pool's own address).
- `initAccount`: in addition to the existing repos (Multi-asset basic vault, Standard vault, ERC20, EIP712, BalancerV3PoolRepo, BalancerV3AuthenticationRepo, BalancerV3VaultAwareRepo), also initialize `StandardExchangeBufferPoolRepo` with `(tta, shares, seVault, rateProvider, ttaIdx, sharesIdx, expectedFactory=address(this))`.
- `PkgArgs` add `standardExchangeVault` and `rateProvider`.
- `deployPool(IStandardExchange seVault, IERC20 tta, IERC20 shares, IRateProvider rp)` helper routes through `VAULT_REGISTRY.deployVault(this, abi.encode(PkgArgs(...)))`.

Build a comprehensive test that deploys the DFPkg against a mock Balancer V3 Vault and asserts the registration call shape.

- [ ] **Step 1: Write a failing integration test that deploys the DFPkg and asserts `Vault.registerPool` was called with the expected `TokenConfig[]`, `roleAccounts`, `swapFee`, `hooksContract == pool`, and `liquidityManagement` matching the spec.**

- [ ] **Step 2: Confirm test fails.**

- [ ] **Step 3: Implement the DFPkg by copying `BalancerV3ConstantProductPoolStandardVaultPkg.sol` and applying the changes above.**

- [ ] **Step 4: Tests pass.**

- [ ] **Step 5: Commit**

```
git commit -m "feat(pool): DFPkg composing pool + hook + liquidity facets"
```

---

## Task 14: Factory service — `StandardExchangeBufferPool_FactoryService`

**Files:**
- Create: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_FactoryService.sol`

Library mirroring `BalancerV3ConstantProductPool_FactoryService.sol`. Add deploy helpers for each of the three new facets and the DFPkg. Add a `buildPkgInit` helper that packs the seven facets + immutables into the DFPkg's `PkgInit`.

- [ ] **Step 1: Write the library.**
- [ ] **Step 2: Build and commit.**

```
git commit -m "feat(pool): CREATE3 factory service library"
```

---

## Task 15: Test base — `TestBase_StandardExchangeBufferPool`

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol`

Setup steps in `_setUp` (extend `TestBase_VaultComponents` if applicable, otherwise extend the Crane Balancer V3 vault test base):
1. Deploy CREATE3 factory and Diamond Package Factory.
2. Deploy a Balancer V3 Vault test harness (use Crane's `BalancerV3VaultTestBase` if present; otherwise the upstream `Vault` constructor).
3. Deploy two test tokens (TTA, TTB) and a Standard Exchange Vault holding them.
4. Deploy `StandardExchangeRateProviderDFPkg` and call `deployRateProvider` to get an `IRateProvider` for the (seVault, TTA) pair.
5. Deploy our new pool DFPkg with the seven facets.
6. Call `pkg.deployPool(seVault, TTA, shares, rateProvider)` to get a `pool` address.
7. Initialize the pool with `s_init` shares (mint shares to the test alice; alice approves Vault; Router.initialize).
8. Fund alice/bob with TTA, TTB, and shares for swaps and LP ops.

Expose all relevant addresses as public state so behavior libraries can read them.

- [ ] **Step 1: Implement the test base.**
- [ ] **Step 2: Add a smoke test that deploys + initializes the pool and asserts `virtualTTA = s_init * 1e18` (rate is 1:1 at fresh seVault).**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): test base for end-to-end pool scenarios"
```

---

## Task 16: Behavior library — `Registration`

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Registration.sol`

Reusable behavior containing one function per registration assertion (success path + each rejection from Section 4.4). Each function takes a `TestBase_StandardExchangeBufferPool` reference.

- [ ] **Step 1: Implement behavior library.**
- [ ] **Step 2: Drive the behavior from a `.spec.t.sol` test contract that calls each behavior in turn.**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): registration behavior library"
```

---

## Task 17: Behavior library — `Initialization`

- [ ] **Step 1: Write `Behavior_StandardExchangeBufferPool_Initialization.sol` covering `virtualTTA` seed, `hookSharesDelta = 0`, BPT mint amount, `InitialInvariantTooSmall` rejection on undersized seed.**
- [ ] **Step 2: Drive from spec file.**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): initialization behavior library"
```

---

## Task 18: Behavior library — `Swap_TTAtoShares`

- [ ] **Step 1: Write the behavior. Assertions per Section 6.2 end-state plus: derived `y` change equals exactly `-Y_rated`, `hookSharesDelta` change equals exactly `+Y'`, pool actual TTA == 0 post-swap, deltas net to zero.**
- [ ] **Step 2: Drive from spec file with multiple swap sizes (small, medium, large within bounds).**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): TTA->shares swap behavior library"
```

---

## Task 19: Behavior library — `Swap_SharesToTTA`

- [ ] **Step 1: Write the behavior. Critical assertion: `Y_TTA_final == Y_TTA` exactly (no residual pass needed). Plus `virtualTTA -= Y_TTA`, `hookSharesDelta -= S` (allow negative), derived `y` change equals exactly `+X_rated`.**
- [ ] **Step 2: Drive from spec.**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): shares->TTA swap behavior library"
```

---

## Task 20: Behavior library — `LP_AddProportional` and `LP_RemoveProportional`

- [ ] **Step 1: Write `Behavior_StandardExchangeBufferPool_LP_AddProportional.sol`. Cover both (a) LP supplies only shares, and (b) LP supplies TTA + shares — assert hook converts TTA in `onBeforeAddLiquidity`. Verify `virtualTTA` and `hookSharesDelta` scale by `(T+bptOut)/T`. CP ratio preserved.**
- [ ] **Step 2: Write `Behavior_StandardExchangeBufferPool_LP_RemoveProportional.sol`. LP receives shares only. Verify both state variables scale by `(T-bptIn)/T`.**
- [ ] **Step 3: Drive from spec.**
- [ ] **Step 4: Commit**

```
git commit -m "test(pool): LP add/remove behavior libraries"
```

---

## Task 21: Behavior library — `Clamping` and `Errors`

- [ ] **Step 1: Write `Behavior_StandardExchangeBufferPool_Clamping.sol`. Construct states where derived `y` would clamp to zero (heavy `TTA -> shares` until shares run out) and assert `pool.onSwap` reverts `PoolSharesSideExhausted`. Symmetric for `virtualTTA -> 0` (`PoolTTASideExhausted`).**
- [ ] **Step 2: Write `Behavior_StandardExchangeBufferPool_Errors.sol`. One assertion per typed error in Section 7.1.**
- [ ] **Step 3: Drive from spec.**
- [ ] **Step 4: Commit**

```
git commit -m "test(pool): clamping + error path behavior libraries"
```

---

## Task 22: Spec runner — `StandardExchangeBufferPool.spec.t.sol`

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool.spec.t.sol`

Wires every behavior library into one runnable spec contract. Each `test_xxx` function delegates to a behavior method. This is the "single click runs everything" entry point.

- [ ] **Step 1: Implement spec runner.**
- [ ] **Step 2: Run `forge test --match-path '...StandardExchangeBufferPool.spec.t.sol' -vv`; confirm all behaviors green.**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): spec runner wires every behavior"
```

---

## Task 23: Invariant handler

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/Handler_StandardExchangeBufferPool.sol`

Handler exposes:
- `swap_TTA_in(uint256 amount)` — bounded `[1e6, alice TTA balance]`.
- `swap_shares_in(uint256 amount)` — bounded similarly.
- `add(uint256 bptOut)` — bounded `[1e12, totalSupply / 2]`, alternate "with TTA contribution" vs "without".
- `remove(uint256 bptIn)` — bounded `[1, alice BPT balance]`.
- `drift_rate(int256 delta_bps)` — actor that nudges the underlying Standard Exchange Vault's rate by a small basis-point amount (mutates the seVault's reserve composition to make `previewExchangeOut` return a different value).

- [ ] **Step 1: Implement handler.**
- [ ] **Step 2: Commit**

```
git commit -m "test(pool): invariant handler"
```

---

## Task 24: Invariant test contract

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool.invariant.t.sol`

Implements every invariant from Section 8.3 of the spec:
- `invariant_PoolHoldsZeroActualTTABetweenOps`
- `invariant_VaultReservesMatchPoolBalances`
- `invariant_VirtualTTANonNegative`
- `invariant_DerivedYNonNegative` (or onSwap reverts `PoolSharesSideExhausted`)
- `invariant_HookReshufflesInvisible` (after a TTA->shares + matching shares->TTA pair, state within rounding tolerance of pre-pair)
- `invariant_BPTSupplyTracksInvariant`
- `invariant_NoFreeValue`
- `invariant_RateProviderConsistency`

Configure Foundry runs/depth in `foundry.toml` under the invariant profile (likely already set; check before tuning).

- [ ] **Step 1: Implement invariant test.**
- [ ] **Step 2: Run `forge test --match-path '...StandardExchangeBufferPool.invariant.t.sol' -vv` with default depth. Tune if too slow.**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): invariant test suite"
```

---

## Task 25: Adversarial tests

**Files:**
- Add: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Adversarial.sol`
- Add cases to the spec runner.

Tests from Section 8.5 of the spec:
- Stale-rate sandwich.
- Malicious rate provider (reverts / returns wildly different values).
- Donation griefing — external party calls `addLiquidity(DONATION)` directly; assert `onAfterAddLiquidity` proportionally grows `virtualTTA` + `hookSharesDelta` and no value is drainable.
- Reentrant Standard Exchange Vault mock attempting to re-enter `Vault.swap`.

- [ ] **Step 1: Implement each adversarial behavior with its corresponding mock.**
- [ ] **Step 2: Wire into spec runner.**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): adversarial behavior coverage"
```

---

## Task 26: Fork test — Sepolia

**Files:**
- Create: `test/foundry/fork/base_main/balancer/v3/Fork_StandardExchangeBufferPool.t.sol`

Deploys against the live Balancer V3 Vault on Sepolia (the address pattern is already used by other fork tests in `test/foundry/fork/base_main/balancer/v3/`; copy the env-driven fork-block setup from `TestBase_BalancerV3Fork.sol`). Lays out a Standard Exchange Vault test fixture, deploys our pool, runs the behavior libraries against it.

- [ ] **Step 1: Implement the fork test.**
- [ ] **Step 2: Run with `forge test --match-path 'test/foundry/fork/base_main/balancer/v3/Fork_StandardExchangeBufferPool.t.sol' -vv` against the Sepolia RPC (env var the existing fork tests use).**
- [ ] **Step 3: Commit**

```
git commit -m "test(pool): Sepolia fork test"
```

---

## Task 27: Final verification

- [ ] **Step 1: Full local test run**

```
forge build
forge test --no-match-path 'test/foundry/fork/**'
```
Expected: no failures.

- [ ] **Step 2: Forge gas snapshot for the pool spec runner** (so swap gas is regression-tested going forward).

```
forge snapshot --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/**'
git add .gas-snapshot
git commit -m "test(pool): gas snapshot for buffer pool"
```

- [ ] **Step 3: Update CODEBASE_MAP.md** (`docs/CODEBASE_MAP.md` — quick scan to see if it lists pool DFPkgs; if so, add an entry for ours).

```
git add docs/CODEBASE_MAP.md
git commit -m "docs(map): add Standard Exchange Buffer Pool entry"
```

(Skip if the codebase map doesn't enumerate pool DFPkgs.)

- [ ] **Step 4: Open PR if working on a branch** (`gh pr create ...`).

---

## Notes on potential mid-execution discoveries

- **Decimal handling**: Tasks 7, 8, 9 assume 18-decimal share and TTA tokens. If either is non-18-decimal, the `_liftSharesToScaled18Rated` helper and the raw/scaled conversions in the hook need to use the Vault's `decimalScalingFactors` rather than ad-hoc factors. Track this as a follow-up issue if it arises in a real fork test.
- **Balancer `initialize` accepting 0 amount**: Task 15's setup expects `[0, s_init]` to work; if Balancer rejects, switch to a tiny dust TTA amount and update `onBeforeInitialize` per the spec's Open Question #1.
- **`_addLiquidityCalled` round-trip-fee surprise**: Section 7.4 of the spec. Already covered by Task 25's adversarial tests; if a real router integration surfaces user-visible fees, document in code comments where appropriate.
- **Hook calling Vault during onAfterAddLiquidity**: The reconcile dance in Task 10 (`onBeforeAddLiquidity`) calls `Vault.addLiquidity(DONATION)` while *inside* the Vault's `addLiquidity` call. Verify this works the way Section 7 of the spec claims (the outer `addLiquidity` is `onlyWhenUnlocked` but the inner `_addLiquidity` is `nonReentrant`, and the before-hook fires before the inner call). If the Vault rejects, the path falls back to settling the converted shares via a separate `Vault.swap` operation — design alternative to discuss with the user before implementing.
