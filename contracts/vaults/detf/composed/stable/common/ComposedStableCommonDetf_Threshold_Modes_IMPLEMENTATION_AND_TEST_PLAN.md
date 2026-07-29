# ComposedStableCommonDetf — Threshold Modes Implementation & Test Plan

## 1. Normative refs

| Resource | Path |
|----------|------|
| Product law | [`../../DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) — **formal LOCKED 2026-07-28** + **§16** encoding locks |
| Progress tracker | [`../../DETF_Threshold_Modes_PROGRESS.md`](../../DETF_Threshold_Modes_PROGRESS.md) |
| Core lib (shipped) | [`../../core/DETFThresholdPolicy.sol`](../../core/DETFThresholdPolicy.sol) |
| Gold F1 plan | [`../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Family PRD | [`ComposedStableCommonDetf_PRD.md`](./ComposedStableCommonDetf_PRD.md) |
| Gold TestBase | [`TestBase_ComposedStableCommonDetf.sol`](./TestBase_ComposedStableCommonDetf.sol), [`TestBase_ComposedStableCommonDetf_Components.sol`](./TestBase_ComposedStableCommonDetf_Components.sol) |
| Integrated deploy | `test/foundry/spec/vaults/detf/composed/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol` |

**Conforms to product law + §16; no re-litigation.**  
**Family:** F4 / Wave 3 — same Policy/Open product surface as F1–F3.  
**Depends on:** shipped P0 core lib API (`ThresholdMode`, `resolveAndRequireValidThresholds`, `requireValidThresholdMode`, 3-arg `_isMintingAllowed` / `_isBurningAllowed`). Do **not** redesign the lib.

**Family PRD conform note:** one-liner “conforms to `DETF_Threshold_Modes_PRD`” is **P7** — not this plan’s implement scope.

---

## 2. Goals / non-goals (F4 only)

### Goals

1. Deploy-time **Policy** (default) and **Open** via **trailing** `PkgArgs.thresholdMode` (§16).
2. Source of truth: **PkgArgs → resolve → instance storage only** (never fee oracle for thresholds/mode).
3. Mode-aware mint/burn gates using existing **`_syntheticDetfEthPrice()`** + core lib 3-arg helpers.
4. **Live** enforcement stays in the **family** (via existing reserve-pool initialized check / equivalent); core lib has **no `live` param**.
5. MUST surface: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()` (PRD §4.5).
6. Emit `ThresholdModeSet(mode, mint, burn)` **once** at init with **resolved** values.
7. Keep Policy/gated paths green; add Open suites; dual-path extremes OK but map illegal always-allow Policy pairs to product Open.
8. Map program T1–T19 to concrete F4 tests/helpers.
9. Nested attachment: when this DETF is an SE leg under F1 matrix (or any outer DETF), **outer/inner modes remain independent**.

### Non-goals

- Claim redeem product rules / rebasing claim economics changes
- MixedBuffer F3 package work
- Brand renames unrelated to thresholds
- UI / marketing copy
- Fee-oracle threshold control or post-deploy mode setters
- Asymmetric modes (open mint / gated burn only — do not exist)
- Changing seigniorage split or usage fee schedules by mode
- F5 / F6 / F7 / AGENTS.md (P6–P7)
- Production Solidity in the **plan-only** session that authors this file

---

## 3. Current state audit (grep-backed, 2026-07-28)

### 3.1 Gate call sites (ExchangeIn **and** ExchangeOut/query)

| Location | Function | Live check | Policy check (today) | Price |
|----------|----------|------------|----------------------|-------|
| `ComposedStableCommonDetfExchangeIn.sol` | `previewExchangeIn` mint branch (`tokenOut == detfToken`) | **none** before gate | `_isMintingAllowed(synthetic)` 2-arg Policy | `_syntheticDetfEthPrice()` |
| `ComposedStableCommonDetfExchangeIn.sol` | `previewExchangeIn` burn branch (`tokenIn == detfToken`) | `_requireReservePoolInitialized()` **after** burn gate | `_isBurningAllowed(synthetic)` 2-arg | `_syntheticDetfEthPrice()` |
| `ComposedStableCommonDetfExchangeIn.sol` | `_executeMintRoute` | none before gate (mint may create live path via join) | `_isMintingAllowed` 2-arg | `_syntheticDetfEthPrice()` |
| `ComposedStableCommonDetfExchangeIn.sol` | `_executeBurnRoute` | `_requireReservePoolInitialized()` then | `_isBurningAllowed` 2-arg | `_syntheticDetfEthPrice()` |
| `ComposedStableCommonDetfExchangeOutQueryFacet.sol` | `previewExchangeOut` | `_requireReservePoolInitialized()` then | `_isBurningAllowed` 2-arg | `_syntheticDetfEthPrice()` |
| `ComposedStableCommonDetfExchangeOutQueryFacet.sol` | `_executeExchangeOut` | `_requireReservePoolInitialized()` then | `_isBurningAllowed` 2-arg | `_syntheticDetfEthPrice()` |
| `ComposedStableCommonDetfCommon.sol` | `_isMintingAllowed(uint256)` / `_isBurningAllowed(uint256)` | **None** (threshold only) | `DETFThresholdPolicy._is*(threshold, price)` **2-arg Policy-only** | caller-supplied synthetic |
| Bonding | `bond` / first bond | `_requireReservePoolInitialized` on non-bootstrap paths as today | **no synthetic threshold gate** on first bond | — |
| Rebasing / claim | claim liquidity / redeem | family rules | **out of threshold-mode scope** | — |

**Already correct (do not change):**

- Gate price input is **synthetic** via `_syntheticDetfEthPrice()` → `IDETF.syntheticDetfEthPrice()` (no spot migration for F4).

**Audit findings to fix:**

1. Common helpers use **2-arg** Policy-only lib wrappers — no `ThresholdMode`.
2. No `thresholdMode` storage or `PkgArgs` field.
3. No `resolveAndRequireValidThresholds` / `requireValidThresholdMode` at init — raw `mintThreshold`/`burnThreshold` written as-is (e.g. `burn=0` stays 0; IntegratedDeploy defaults mint=`1e18`, burn=`0`).
4. No `ThresholdModeSet` event.
5. No public `thresholdMode()` / live-coupled `isMintingAllowed` / `isBurningAllowed` on this diamond (PRD MUST for in-scope families). Pricing facet exposes `syntheticDetfEthPrice` but not gate views.
6. Preview paths **already gate** (F4-specific). Keep gate-on-preview parity after mode wiring (document; T12 = preview==execution when **allowed**).
7. Live is pool-initialized / totalSupply via `_requireReservePoolInitialized()`, not a dedicated `isReserveLive` flag — treat that as the family’s live check for §4.5.

### 3.2 PkgArgs / storage / init (today)

**`IComposedStableCommonDetfDFPkg.PkgArgs`** (`ComposedStableCommonDetfDFPkg.sol`):

```text
reservePool, bondNftVault, rebasingDetfToken, detfToken,
stablePoolBpt, commonPoolBpt, rateAsset,
stablePoolExitPricer, commonPoolExitPricer,
permit2, balancerV3Router, stablePool, commonPool, reservePoolEntryRouter,
detfIndex, stablePoolBptIndex, commonPoolBptIndex,
mintThreshold, burnThreshold,
routes[]
```

**`ComposedStableCommonDetfRepo.Storage`:** `mintThreshold`, `burnThreshold` (no mode).

**Write path:** `initAccount` → `_initializePricing(...)` then `_initializeExchangeIn(..., mintThreshold, burnThreshold, routes)` — **no resolve**, **no mode**, **no event**.

**Factory helper:** `ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfPricingConfig` + `buildPkgArgs` mirrors PkgArgs fields through `burnThreshold` + `routes` only.

### 3.3 Info / facet selectors (today)

| Facet | Selectors related to gates / price |
|-------|-------------------------------------|
| `ComposedStableCommonDetfExchangeIn` | `previewExchangeIn`, `exchangeIn` only |
| `ComposedStableCommonDetfExchangeOutQueryFacet` | `previewExchangeOut`, `exchangeOut`, claim liquidity |
| `RebasingDETFTokenPricingFacet` | IDETF pricing incl. `syntheticDetfEthPrice` — **no** mint/burn threshold or `is*Allowed` / `thresholdMode` |
| Bonding facet | bond surface only |

**Gap:** need `thresholdMode()`, `mintThreshold()`, `burnThreshold()`, `isMintingAllowed()`, `isBurningAllowed()` on an appropriate interface + facet function array(s). Prefer a small **Info** surface on the pricing facet or a dedicated info facet if one exists; if adding to pricing facet, keep IDETF pricing selectors and append threshold selectors. Match F1 pattern of exposing on the diamond users already query.

### 3.4 Tests / dual-path (today)

| Site | Pattern |
|------|---------|
| `ComposedStableCommonDetf_IntegratedDeploy.t.sol` | `_composedMintThreshold() → 1e18`, `_composedBurnThreshold() → 0` |
| `ComposedStableCommonDetfDFPkg_Deploy.t.sol` | `mintThreshold: 1e18`, `burnThreshold: 0` |
| `ComposedStableCommonDetfExchangeIn.t.sol` harness | sets mintThreshold; burn 0; overrides `_syntheticDetfEthPrice` for unit gate tests |
| `ComposedStableCommonDetfBurnExchangeIn.t.sol` / `ExchangeOutQueryFacet.t.sol` harnesses | burnThreshold + synthetic override |
| F1 matrix / nested attach (if any) | may construct ComposedStable `PkgArgs` — grep `ComposedStableCommonDetf` + `mintThreshold` under `test/` and F1 forks when implementing |

**Note:** `burnThreshold: 0` today does **not** mean Open. After this work, `0` resolves to `0.95e18`. Fixtures that intended “always burn” must use product **Open** or extreme Policy (`mint=1`, `burn=max`) dual-path — **not** illegal `mint ≤ burn` after resolve.

---

## 4. API / storage diff

### 4.1 `PkgArgs` (trailing `thresholdMode`)

**Locked shape (§16):** append `ThresholdMode thresholdMode` as the **last** field (after `routes`).

```solidity
struct PkgArgs {
    // ... existing fields through commonPoolBptIndex ...
    uint256 mintThreshold;       // 0 → 1.05e18
    uint256 burnThreshold;       // 0 → 0.95e18
    ComposedStableCommonDetfRepo.RouteConfig[] routes;
    ThresholdMode thresholdMode; // trailing; 0 = Policy default
}
```

**Also update:**

- `ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfPricingConfig`
- `buildPkgArgs(...)` named fields

**Breaking:** every `PkgArgs({...})` / pricing-config literal must set `thresholdMode` (or rely on zero = Policy with named fields).

### 4.2 Repo storage

```solidity
struct Storage {
    // ... existing ...
    uint256 mintThreshold;
    uint256 burnThreshold;
    ThresholdMode thresholdMode; // NEW
    RouteConfig[] routes;
}
```

Update `_initializeExchangeIn` (both overloads) to accept and store `ThresholdMode thresholdMode_` (append after burn or as documented adjacent param). Prefer:

```text
..., feeOracle_, mintThreshold_, burnThreshold_, thresholdMode_, routes_
```

Add `_thresholdMode()` getter(s) parallel to `_mintThreshold` / `_burnThreshold`.

### 4.3 Event (canonical ABI — §16.4)

Declare on family info interface (new or existing):

```solidity
event ThresholdModeSet(
    ThresholdMode mode,
    uint256 mintThreshold,
    uint256 burnThreshold
);
```

Emit **once** from the DFPkg path that writes resolved thresholds into repo (`initAccount` after `_initializeExchangeIn`, or a single helper immediately after storage write). Values must be **resolved**.

### 4.4 Info selectors (MUST)

```solidity
function thresholdMode() external view returns (ThresholdMode);
function mintThreshold() external view returns (uint256);
function burnThreshold() external view returns (uint256);
function isMintingAllowed() external view returns (bool); // live + mode + synthetic
function isBurningAllowed() external view returns (bool); // live + mode + synthetic
```

Wire onto diamond via pricing facet **or** ExchangeIn facet (if info co-located) — choose the facet that already owns IDETF reads; document choice in implement PR. Bump `facetFuncs` / dual arrays + lengths.

### 4.5 Nested attachment

When F1 (or other) matrix deploys this family as an SE leg:

- Update nested `PkgArgs` / pricing config to include trailing `thresholdMode`.
- Outer DETF mode and this instance’s mode are **independent** (PRD §0.3).
- No cross-instance “inherit Open” rules.

---

## 5. Core lib integration (shipped API only)

| Concern | Implementation |
|---------|----------------|
| Import | `DETFThresholdPolicy`, `ThresholdMode` from `contracts/vaults/detf/core/DETFThresholdPolicy.sol` |
| Mode validate | `DETFThresholdPolicy.requireValidThresholdMode(args.thresholdMode)` |
| Resolve + pair validate | `resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)` |
| Allow | `DETFThresholdPolicy._isMintingAllowed(mode, mintThreshold, synthetic)` (3-arg) |
| Live | **Family only:** `_requireReservePoolInitialized()` on execution where required; Common/`is*Allowed` views return false when reserve not initialized |
| Open short-circuit | **Only in lib** — family must not reimplement Open as local `return true` without mode |
| Defaults | Prefer lib `DEFAULT_MINT_THRESHOLD` / `DEFAULT_BURN_THRESHOLD`; do not invent alternate zeros→Open |

### 5.1 Common helper rewrite (normative F4 pattern)

```solidity
function _isReserveLive() internal view returns (bool) {
    // Prefer a non-reverting live probe shared with _requireReservePoolInitialized,
    // or try/catch pattern used by peers. Implementor: extract isPoolInitialized && totalSupply > 0
    // without inventing a second liveness concept.
}

function _isMintingAllowed(uint256 /* unused price arg optional */) internal view returns (bool) {
    if (!_isReserveLive()) return false;
    return DETFThresholdPolicy._isMintingAllowed(
        ComposedStableCommonDetfRepo._thresholdMode(),
        ComposedStableCommonDetfRepo._mintThreshold(),
        _syntheticDetfEthPrice()
    );
}

function _isBurningAllowed(...) internal view returns (bool) {
    if (!_isReserveLive()) return false;
    return DETFThresholdPolicy._isBurningAllowed(
        ComposedStableCommonDetfRepo._thresholdMode(),
        ComposedStableCommonDetfRepo._burnThreshold(),
        _syntheticDetfEthPrice()
    );
}
```

**Migration note:** today’s helpers take `syntheticPrice_` from the caller. Either:

- Keep signature and pass price through after live check + 3-arg mode, or  
- Compute price inside helpers (cleaner; update all call sites).

Execution remains:

```text
// burn / out: _requireReservePoolInitialized(); then if (!_isBurningAllowed(...)) revert BurningNotAllowed
// mint: if (!_isMintingAllowed(...)) revert MintingNotAllowed — live rules as family already orders them
```

When live + Open, lib allow always true.  
When inert/not initialized, views false; execution hits reserve-not-initialized where applicable.  
When live + Policy deadband (incl. equality), reverts `MintingNotAllowed` / `BurningNotAllowed` with **synthetic** and threshold.

### 5.2 Target gate call-site table

| Function | Live | Policy/Open | Price |
|----------|------|-------------|-------|
| `previewExchangeIn` mint | view: false if !live | mode-aware | `_syntheticDetfEthPrice()` |
| `previewExchangeIn` burn | require / live check | mode-aware | synthetic |
| `_executeMintRoute` | family order preserved | mode-aware | synthetic |
| `_executeBurnRoute` | `_requireReservePoolInitialized` | mode-aware | synthetic |
| `previewExchangeOut` | require then | mode-aware | synthetic |
| `_executeExchangeOut` | require then | mode-aware | synthetic |
| `isMintingAllowed` / `isBurningAllowed` views | false if !live | mode-aware | synthetic |
| first bond bootstrap | family | **no** synthetic threshold gate | — |

---

## 6. Touch list (concrete files)

| File | Change |
|------|--------|
| `ComposedStableCommonDetfDFPkg.sol` | trailing `thresholdMode`; resolve/validate; pass mode; emit `ThresholdModeSet` once |
| `ComposedStableCommonDetfRepo.sol` | storage + `_initializeExchangeIn` + getters |
| `ComposedStableCommonDetfCommon.sol` | mode-aware + live-coupled `_is*Allowed`; keep `_syntheticDetfEthPrice` |
| `ComposedStableCommonDetfExchangeIn.sol` | call-site updates if helper signatures change; confirm mint/burn gate order |
| `ComposedStableCommonDetfExchangeOutQueryFacet.sol` | same for both burn gate sites |
| Pricing facet / Info surface | `thresholdMode`, mint/burn thresholds, `is*Allowed` selectors |
| `ComposedStableCommonDetf_Component_FactoryService.sol` | PricingConfig + `buildPkgArgs` |
| Interface(s) under `contracts/interfaces/` | declare views + event as needed (family-specific or IDETF extension if already planned for F6 — prefer family surface now if IDETF lacks them) |
| `TestBase_ComposedStableCommonDetf*.sol` | helpers below if deploy helpers live here |
| `test/foundry/spec/vaults/detf/composed/stable/common/**` | PkgArgs literals; Open suite; dual-path; harness init signatures |
| Nested / F1 matrix constructors of this PkgArgs | trailing mode field |

**Do not touch:** MixedBuffer F3 sources; claim-token product rules; core lib API redesign.

---

## 7. Init / validation sequence

**Site:** `ComposedStableCommonDetfDFPkg.initAccount`.

```text
1. requireValidThresholdMode(args.thresholdMode)
2. (mint, burn) = resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)
3. _initializePricing(...)  // unchanged
4. _initializeExchangeIn(..., mint, burn, mode, routes)
5. emit ThresholdModeSet(mode, mint, burn) once
```

| Case | Result |
|------|--------|
| mode omitted / 0 | Policy |
| mode Open | store Open; thresholds still resolved/stored |
| Open + `0,0` | store 1.05e18 / 0.95e18; gates ignore thresholds |
| Open + custom | store custom; gates ignore |
| after resolve mint ≤ burn | revert `InvalidThresholdPair` |
| mode > Open | revert `InvalidThresholdMode` |
| Policy extreme mint=1 / burn=max | **legal Policy** (dual-path) |
| Policy `mint=1e18, burn=0` | resolve burn→0.95e18; **valid** Policy custom mint + default burn |

---

## 8. TestBase helpers

| Helper | Behavior |
|--------|----------|
| Default IntegratedDeploy thresholds | Prefer Policy + product `0,0` → defaults **or** keep explicit Policy custom band with valid mint > burn after resolve; set `thresholdMode: Policy` |
| `_deployOpenModeDetf*` / config | **New:** `thresholdMode: Open`, thresholds `0,0` (or optional custom stored) |
| Extreme Policy dual-path | Policy + `mint=1`, `burn=type(uint256).max` — NatSpec: “extreme Policy, **not** product Open” |
| Illegal after validation | Do **not** use mint=1 / burn=max as “open” if that pair fails elsewhere; do **not** use burn=0 expecting always-allow — map old always-allow intent → product Open |

Update `_composedMintThreshold` / `_composedBurnThreshold` callers to also supply mode (extend virtuals or add `_composedThresholdMode()`).

---

## 9. Test map T1–T19 → concrete F4 tests

**New file (recommended):**

`test/foundry/spec/vaults/detf/composed/stable/common/ComposedStableCommonDetf_ThresholdMode.t.sol`

(Inherits IntegratedDeploy / production TestBase chain — production-first; no mocks of SUT DETF/manager/registry/fee oracle/SE legs.)

| ID | Case | Concrete test / home |
|----|------|----------------------|
| **T1** | Policy `0,0` → defaults + mode Policy + event | `test_deploy_policyDefaults_thresholdModeAndEvent` — assert mode Policy; 1.05e18/0.95e18; `vm.expectEmit` `ThresholdModeSet` |
| **T2** | Policy custom band | `test_deploy_policyCustomBand` — e.g. 1.10e18 / 0.90e18 stored |
| **T3** | Open deploy | `test_openDeploy_modeAndStoredThresholds` — Open + 0,0 → defaults stored, mode Open |
| **T4** | Invalid mint ≤ burn after resolve | `test_deploy_revertsWhenMintLeBurn_policy` / `_open` |
| **T4b** | Extreme Policy 1 / max | dual-path deploy still works; mode remains Policy |
| **T5** | Live Policy deadband (incl. equality) | ExchangeIn / Burn unit or integrated: synth == mint/burn → not allowed |
| **T6** | Live Policy mint above | existing mint happy + Policy open path |
| **T7** | Live Policy burn below | existing burn ExchangeIn / ExchangeOut happy |
| **T8** | Inert blocked any mode | mint/burn blocked when reserve not initialized; Open still blocked |
| **T9** | Real pool trades under default ±5% | integrated price-shift if available; else document N/A + unit synthetic drive on production diamond when fixtures allow |
| **T9b** | Info views match execution | `test_infoViews_matchExecution_policy` |
| **T10** | Open live inside former deadband | mint+burn succeed with synth in (0.95, 1.05) |
| **T11** | Inert + Open blocked | `test_openInert_mintBlocked` |
| **T12** | Preview == execution when allowed | ExchangeIn / Out under Policy-allowed and Open |
| **T13** | Open mint fee/seigniorage split | balances fee/protocol as family already asserts |
| **T13b** | Live Open info both true | `isMintingAllowed` && `isBurningAllowed` |
| **T14** | No post-deploy setter | no selector / low-level set fails |
| **T15** | No alternate route bypass Policy | invalid routes still invalid; deadband on mint/burn routes |
| **T16** | Reentrancy `IsLocked` | adversarial suite remains green (Open or extreme Policy) |
| **T17** | Open round-trip mint→burn | no MintingNotAllowed/BurningNotAllowed under Open live |
| **T18** | Extreme Policy reports mode Policy | `thresholdMode()==Policy` |
| **T19** | Open + non-default stored thresholds never deadband-revert | Open + 1.2e18/0.8e18; live mint/burn ok |

### 9.1 Keep green (Policy baseline)

- `ComposedStableCommonDetfDFPkg_Deploy.t.sol` — add mode field; fix `burn: 0` resolve expectations
- `ComposedStableCommonDetf_IntegratedDeploy.t.sol`
- `ComposedStableCommonDetfExchangeIn.t.sol`, `BurnExchangeIn.t.sol`, `ExchangeOutQueryFacet.t.sol` — harness init + mode
- Bonding / Rebasing / sequences / adversarial P0
- Any nested F1 matrix PkgArgs for this family

### 9.2 Harness unit tests note

ExchangeIn / Burn / Out harnesses override `_syntheticDetfEthPrice`. After mode wiring:

- Init must store mode + resolved thresholds.
- Gate assertions use mode-aware helpers.
- Prefer production IntegratedDeploy for Open/Policy product suites; harnesses may remain for pure gate math if they still deploy real Common/Repo paths (not mock SUT diamonds).

---

## 10. Implementation order

1. Repo storage + `_initializeExchangeIn` signature + getters.
2. DFPkg `PkgArgs` trailing mode + resolve/validate + emit event once.
3. FactoryService PricingConfig / `buildPkgArgs`.
4. Common mode-aware + live-coupled `_is*Allowed` (keep synthetic price).
5. Confirm **all** ExchangeIn + ExchangeOutQueryFacet gate sites use Common helpers.
6. Info surface + facet selectors (`thresholdMode`, thresholds, `is*Allowed`).
7. Fix all test/config struct literals to compile.
8. Dual-path / IntegratedDeploy helpers; map always-allow → Open where needed.
9. Policy regression green.
10. Open suite T1–T19 mapped green.
11. Grep nested/F1 matrix PkgArgs; update trailing mode.
12. Update `DETF_Threshold_Modes_PROGRESS.md` P5 F4 implement → done (implement session).

---

## 11. Definition of done

- [x] Trailing `thresholdMode` on `IComposedStableCommonDetfDFPkg.PkgArgs` (after `routes`)
- [x] Storage + init resolve/validate both modes; invalid pair/mode revert
- [x] `ThresholdModeSet` emitted once with **resolved** thresholds
- [x] Gates use mode-aware lib 3-arg helpers + `_syntheticDetfEthPrice()`; live in family
- [x] All ExchangeIn **and** ExchangeOut/query gate sites mode-aware (exhaustive §3.1 table)
- [x] `thresholdMode()` / live-correct `isMintingAllowed` / `isBurningAllowed`
- [x] Facet selector arrays include new views
- [x] FactoryService / PricingConfig updated
- [x] Existing Policy + dual-path tests green; `0` thresholds never mean Open
- [x] Open suites cover T3, T8/T11 Open, T10, T12–T13b, T17–T19
- [x] Full T1–T19 mapped or N/A with reason
- [x] Nested/F1 matrix PkgArgs note addressed (outer/inner modes independent)
- [x] Production-first: no mocks of SUT DETF/manager/registry/fee oracle/SE vaults
- [x] Role names only (`rateAsset`, `pairToken`, vault shares, reserve BPT — no brand-era leakage)
- [x] Verify:

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/**' -vv
# plus any F1 matrix paths that deploy ComposedStable as a leg / construct PkgArgs
```

- [x] PROGRESS.md F4 implement status updated (implement session) — **116/116** green 2026-07-28

---

## 12. Out of scope

- Claim redeem / `RedemptionNotAllowed` product redesign
- MixedBuffer F3 / MultiVaultWeighted F2 rewrites
- Frontend
- Fee-oracle thresholds or mode
- Asymmetric modes
- Cross-instance nested mode inheritance
- Changing first-bond synthetic ungating
- F5 synthetic migration (separate plan)
- F6 NatSpec / F7 Seigniorage / P7 AGENTS + family PRD conform edits (beyond this plan’s one-liner pointer)

---

## 13. Family PRD conform note (P7)

When P7 runs: add a one-liner to `ComposedStableCommonDetf_PRD.md` that this family **conforms to** `DETF_Threshold_Modes_PRD` (Policy/Open + synthetic gates). Do **not** re-open product law here.

---

## 14. Risks specific to F4

| Risk | Plan response |
|------|----------------|
| Multi-facet gate sites (In + Out/query + previews) | Exhaustive §3.1 table; DoD requires all sites |
| Nested F1 matrix PkgArgs | Note trailing mode; modes independent |
| `burn=0` fixtures | Resolve to 0.95e18; remap always-allow intent → Open |
| mint=1 / burn=max dual-path | Legal Policy only; product Open is explicit mode |
| No public is*Allowed today | Add MUST info surface |
| Live via pool initialized vs `isReserveLive` flag | Document family live probe; do not invent second FX/liveness ledger |
| Scope creep into claim/F3 | Explicit non-goals |
