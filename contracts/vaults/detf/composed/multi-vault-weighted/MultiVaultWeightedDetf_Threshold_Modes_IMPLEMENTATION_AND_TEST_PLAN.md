# MultiVaultWeightedDetf — Threshold Modes Implementation & Test Plan

## 1. Normative refs

| Resource | Path |
|----------|------|
| Product law | [`../../DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) — **PRODUCT LAW LOCKED** + **§16** |
| Progress tracker | [`../../DETF_Threshold_Modes_PROGRESS.md`](../../DETF_Threshold_Modes_PROGRESS.md) |
| Core lib plan | [`../../core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| F1 gold pattern | [`../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Family PRD | [`MultiVaultWeightedDetf_PRD.md`](./MultiVaultWeightedDetf_PRD.md) |
| Existing impl plan | [`MultiVaultWeightedDetf_IMPLEMENTATION_AND_TEST_PLAN.md`](./MultiVaultWeightedDetf_IMPLEMENTATION_AND_TEST_PLAN.md) (link; this file is additive) |
| Gold TestBase | [`TestBase_MultiVaultWeightedDetf.sol`](./TestBase_MultiVaultWeightedDetf.sol) |

**Conforms to product law + §16; no re-litigation.**  
**Family:** F2 / P1 — formal PRD LOCKED gate. Same external behavior as F1; multi-leg weighted reserve.

**Nested DETFs:** no cross-instance mode rules — outer and inner each have independent `thresholdMode`.

---

## 2. Goals / non-goals (F2 only)

### Goals

1. Trailing `PkgArgs.thresholdMode` + storage + resolve/validate + `ThresholdModeSet`.
2. Mode-aware mint/burn gates via `_syntheticPrice()` + core lib.
3. Info: `thresholdMode()`, live-coupled `isMintingAllowed()` / `isBurningAllowed()`.
4. Keep Policy/gated + extreme dual-path (`_deployOpenThresholdDetf*`) green; add formal Open helpers/suites.
5. T1–T19 mapped; multi-leg (N=1..3+) coverage where existing tests already parameterize N.

### Non-goals

- Claim redeem gates (`MixedBuffer`/`claim` paths stay independent of Open)
- Changing weighted pool weights / rate provider rules
- Nested mode composition policy
- Fee-oracle threshold control
- UI; asymmetric modes
- Spot pricing (already synthetic)

---

## 3. Current state audit

### 3.1 Gate call sites

| Location | Function | Live | Threshold | Price |
|----------|----------|------|-----------|-------|
| `MultiVaultWeightedDetfExchangeInTarget.sol` | mint branch | `_requireReserveLive` (or equivalent live check) | `_isMintingAllowed()` → `MintingNotAllowed` | `_syntheticPrice()` |
| `MultiVaultWeightedDetfExchangeOutTarget.sol` | burn | live then `_isBurningAllowed()` → `BurningNotAllowed` | | `_syntheticPrice()` |
| `MultiVaultWeightedDetfCommon.sol` | `_isMintingAllowed` / `_isBurningAllowed` | **None** | 2-arg `DETFThresholdPolicy` | `_syntheticPrice()` |
| `MultiVaultWeightedDetfInfoTarget.sol` | info is* | **None** | delegates Common | synthetic |
| `MultiVaultWeightedDetfExchangeQueryTarget.sol` | `previewExchangeIn` | none | **none** | quote math |
| `MultiVaultWeightedDetfBondingTarget.sol` | first bond BPT / bootstrap | live transition | **no synthetic gate on first bond** | — |

**Same findings as F1:** live not in info helpers; no mode; no mint>burn validation; extreme Policy dual-path via `_deployOpenThresholdDetf` / `_deployOpenThresholdDetfN` / nested SSE with mint=1 burn=max.

### 3.2 PkgArgs / storage (today)

**`IMultiVaultWeightedDetfDFPkg.PkgArgs`:**

```text
name, symbol, vaults, vaultShares, rateProviders, rateAssets,
weightDetf, vaultWeights, mintThreshold, burnThreshold
```

**Target trailing order:**

```text
... vaultWeights, mintThreshold, burnThreshold, thresholdMode
```

**`MultiVaultWeightedDetfRepo.Storage` / `InitParams`:** add `ThresholdMode thresholdMode` next to thresholds; wire in `_initialize`.

**Resolve:** DFPkg `initAccount` local `_DEFAULT_*` → switch to `DETFThresholdPolicy.resolveAndRequireValidThresholds`.

**Init write:** `p.mintThreshold` / `p.burnThreshold` in DFPkg postDeploy (~lines 523–524); extend with mode + event.

### 3.3 Facet selectors

`MultiVaultWeightedDetfExchangeInFacet.sol`: `funcs_[20..23]` = mintThreshold, burnThreshold, isMintingAllowed, isBurningAllowed. Add `thresholdMode` selector; bump lengths in both arrays.

### 3.4 Extreme / open dual-path tests

| Site | Pattern |
|------|---------|
| `TestBase_MultiVaultWeightedDetf._deployOpenThresholdDetf` / `N` | mint=1, burn=max |
| `_deployDetfN(..., mintTh, burnTh, rated)` | generic |
| Nested outer `_deployOuterOverNested` | passes mint/burn; no mode yet |
| Nested SSE deploy | mint=1, burn=max on F1 PkgArgs |
| Specs: MintBurn, MultiLeg, Nested, Reentrancy, Fuzz, Invariant, Adversarial | use open extremes |

---

## 4. API / storage diff

### 4.1 PkgArgs

```solidity
struct PkgArgs {
    string name;
    string symbol;
    IStandardExchangeProxy[] vaults;
    IERC20[] vaultShares;
    IRateProvider[] rateProviders;
    IERC20[] rateAssets;
    uint256 weightDetf;
    uint256[] vaultWeights;
    uint256 mintThreshold;       // 0 → 1.05e18
    uint256 burnThreshold;       // 0 → 0.95e18
    ThresholdMode thresholdMode; // trailing
}
```

### 4.2 Storage / InitParams

```solidity
// Storage + InitParams
uint256 mintThreshold;
uint256 burnThreshold;
ThresholdMode thresholdMode; // NEW
```

### 4.3 Event

```solidity
event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
```

Emit once after repo init with resolved values.

### 4.4 Info + facets

- `function thresholdMode() external view returns (ThresholdMode);`
- Facet arrays include selector
- `isMintingAllowed` / `isBurningAllowed`: live + mode + synthetic

---

## 5. Core lib integration

Mirror F1:

```solidity
// Common
if (!s.isReserveLive) return false;
return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
// burn analog
```

| Layer | Responsibility |
|-------|----------------|
| Lib | mode + price only |
| Family | live first on execution (`_requireReserveLive`); info returns false if !live |
| Price | **`_syntheticPrice()` only** |

### Gate call-site table (target)

| Function | Live | Mode/policy |
|----------|------|-------------|
| ExchangeIn mint | require live | mode-aware allow |
| ExchangeOut burn | require live | mode-aware allow |
| Info is* | false if !live | mode-aware |
| First bond / initializeReserve paths | family liveness | **ungated** by synthetic |

---

## 6. Touch list

| File | Change |
|------|--------|
| `MultiVaultWeightedDetfDFPkg.sol` | PkgArgs, DeployConfig, resolve/validate, InitParams mode, event |
| `MultiVaultWeightedDetfRepo.sol` | Storage, InitParams, `_initialize` |
| `MultiVaultWeightedDetfCommon.sol` | mode-aware + live info helpers |
| `MultiVaultWeightedDetfExchangeInTarget.sol` | confirm gates (likely Common-only) |
| `MultiVaultWeightedDetfExchangeOutTarget.sol` | same |
| `MultiVaultWeightedDetfInfoTarget.sol` | `thresholdMode()` + interface |
| `MultiVaultWeightedDetfExchangeInFacet.sol` | selectors |
| `MultiVaultWeightedDetf_*_FactoryService.sol` | only if args/selectors hardcoded |
| `TestBase_MultiVaultWeightedDetf.sol` | PkgArgs + helpers |
| Nested helper using `ISingleStandardExchangeDETDFPkg.PkgArgs` | add F1 `thresholdMode` after F1 lands |
| `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**` | Open suite + compile fixes |

---

## 7. Init / validation

Same as F1 / §16.3:

1. `requireValidThresholdMode(args.thresholdMode)`
2. `resolveAndRequireValidThresholds(mint, burn)`
3. Store mode + resolved thresholds
4. Emit `ThresholdModeSet` once

Invalid `mint <= burn` after resolve and invalid mode → revert (both Policy and Open).

---

## 8. Synthetic confirmation

| Gate | Function |
|------|----------|
| All mint/burn/info gates | **`MultiVaultWeightedDetfCommon._syntheticPrice()`** |
| Spot | **Not used** |

Multi-leg rates already inside synthetic via pool rate providers — do not introduce off-pool FX ledger.

---

## 9. Test map (T1–T19)

### 9.1 TestBase helpers

| Helper | Behavior |
|--------|----------|
| `_deployDetfN(n, mint, burn, rated)` | extend signature **or** default mode Policy; add overload `_deployDetfN(..., ThresholdMode mode)` |
| `_deployOpenThresholdDetf` / `N` | **Keep** Policy + 1/max; document dual-path |
| `_deployOpenModeDetfN(n)` | **New:** `thresholdMode: Open`, thresholds 0,0 |
| `_buildPkgArgs` | set trailing mode |

Prefer overload with default Policy to minimize churn:

```solidity
function _deployDetfN(uint8 n, uint256 mintTh, uint256 burnTh, bool rated)
    internal returns (address)
{
    return _deployDetfN(n, mintTh, burnTh, rated, ThresholdMode.Policy);
}
```

### 9.2 T1–T19 mapping

| ID | Proposed test location | Notes |
|----|------------------------|-------|
| T1 | `MultiVaultWeightedDetf_Deploy.t.sol` extend | defaults + mode Policy + event |
| T2 | Deploy custom band | |
| T3 | **New** `MultiVaultWeightedDetf_ThresholdMode.t.sol` Open deploy | |
| T4 | Deploy revert mint≤burn Policy + Open | |
| T4b | existing extreme deploy | |
| T5–T7 | MintBurn / Pricing / PriceShift Policy paths | keep |
| T8 | `MultiVaultWeightedDetf_Liveness.t.sol` + Open inert | |
| T9 | `MultiVaultWeightedDetf_PriceShift.t.sol` | real underlying trades |
| T9b | Info coupling live+mode | |
| T10 | Open live mint+burn in former deadband | N=1 sufficient; optional N=2 |
| T11 | Open inert blocked | |
| T12 | MintBurn preview==execution | Open + Policy allowed |
| T13 | Open mint fee/split | FeeNonDilution patterns if present |
| T13b | Open live info both true | |
| T14 | no post-deploy setter | Guards / adversarial |
| T15 | no route bypass Policy deadband | Guards |
| T16 | `MultiVaultWeightedDetf_Reentrancy.t.sol` | |
| T17 | Open round-trip | |
| T18 | extreme Policy reports Policy mode | |
| T19 | Open + custom stored thresholds | |

**New file:** `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_ThresholdMode.t.sol`

### 9.3 Nested independence (extra, not a T-id)

| Test | Expect |
|------|--------|
| Outer Open / inner Policy (or reverse) | Each diamond’s gates follow **its** mode only |

Use `_deployNestedSingleSeDetfLive` + `_deployOuterOverNested` with explicit modes once F1 PkgArgs include `thresholdMode`.

---

## 10. Production-first rules

- `TestBase_MultiVaultWeightedDetf` production SE legs + registry deploy path.
- No mocks of SUT DETF, DFPkg, manager, registry, fee oracle, attached SE vaults.
- Nested Single SE DETF is production package, not a mock.
- Hostile ERC20 only for existing reentrancy suite share slot.

---

## 11. Rollout order

1. P0 core lib (shared).
2. Prefer F1 patterns merged (or implement from this plan + core API alone).
3. Repo → DFPkg → Common → Info/Facet → TestBase → Policy regression → Open suite.
4. Nested helpers after F1 `PkgArgs` includes mode.
5. PROGRESS.md P2 → `done`.

---

## 12. Definition of done

- [x] Trailing `thresholdMode` on F2 PkgArgs; storage; resolve/validate; event once
- [x] Mode-aware gates + `_syntheticPrice()`; live in family/info
- [x] `thresholdMode()` + accurate is*Allowed
- [x] Facet selectors updated
- [x] Policy + dual-path extreme tests green
- [x] Open suites for T3, T10–T13b, T17–T19 (+ T1/T4/T8/T11/T18 as mapped)
- [x] Nested mode independence smoke (optional but recommended)
- [x] `forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**'` green
- [x] PROGRESS.md updated

---

## 13. Out of scope

- Claim redeem / rebasing claim product rules
- UI; fee-oracle thresholds; asymmetric modes
- Changing multi-leg weight validation
- Cross-instance mode inheritance
- F3/F4+ code

---

## 14. Family PRD conform note (docs only, P7)

When porting: strike any “fee oracle overrides thresholds later” language in `MultiVaultWeightedDetf_PRD.md`; add “Conforms to `DETF_Threshold_Modes_PRD`”.
