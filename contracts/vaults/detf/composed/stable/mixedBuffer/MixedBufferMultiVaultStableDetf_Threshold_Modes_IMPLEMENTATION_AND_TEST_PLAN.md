# MixedBufferMultiVaultStableDetf — Threshold Modes Implementation & Test Plan

## 1. Normative refs

| Resource | Path |
|----------|------|
| Product law | [`../../../DETF_Threshold_Modes_PRD.md`](../../../DETF_Threshold_Modes_PRD.md) — **PRODUCT LAW LOCKED** + **§16** |
| Progress tracker | [`../../../DETF_Threshold_Modes_PROGRESS.md`](../../../DETF_Threshold_Modes_PROGRESS.md) |
| Core lib plan | [`../../../core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| F1 gold pattern | [`../../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Family PRD | [`MixedBufferMultiVaultStableDetf_PRD.md`](./MixedBufferMultiVaultStableDetf_PRD.md) (D1–D30; thresholds ±5% D7 — extend with mode) |
| Existing impl plan | [`MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md`](./MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md) (link; this file is additive) |
| Gold TestBase | [`TestBase_MixedBufferMultiVaultStableDetf.sol`](./TestBase_MixedBufferMultiVaultStableDetf.sol) |

**Conforms to product law + §16; no re-litigation.**  
**Family:** F3 / P1 — formal PRD LOCKED gate.

**Product-specific lock:** Open means **threshold gates open**, not new burn assets. Post-live burn remains **buffer-only** per family PRD. First bond / `bootstrapFirstBond` remains **synthetically ungated** in both modes.

---

## 2. Goals / non-goals (F3 only)

### Goals

1. Trailing `PkgArgs.thresholdMode` + storage + resolve/validate + `ThresholdModeSet`.
2. Mode-aware mint/burn using `_syntheticPrice()` + core lib.
3. Info surface with live coupling + `thresholdMode()`.
4. Keep Policy/gated suites (esp. PriceShift under default ±5%, Pricing closed-band) green.
5. Add formal Open suites; keep extreme dual-path helpers documented as Policy.
6. T1–T19 mapped with F3 route specifics (buffer mint paths, vaultShare mint, buffer-only burn).

### Non-goals

- Expanding burn outputs beyond bufferToken under Open
- Changing MixedBuffer pool math / amplification / bootstrap peg seed
- Claim redeem gates (independent of Open)
- Fee-oracle thresholds; UI; asymmetric modes
- Spot pricing (already synthetic)

---

## 3. Current state audit

### 3.1 Gate call sites

| Location | Function | Live | Threshold | Price |
|----------|----------|------|-----------|-------|
| `MixedBufferMultiVaultStableDetfExchangeInTarget.sol` | mint (`tokenOut == this`) | live check in path | `_isMintingAllowed()` → `MintingNotAllowed` | `_syntheticPrice()` |
| `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` | burn → buffer | live + `_isBurningAllowed()` → `BurningNotAllowed` | | `_syntheticPrice()` |
| `MixedBufferMultiVaultStableDetfCommon.sol` | `_isMintingAllowed` / `_isBurningAllowed` | **None** | 2-arg policy | `_syntheticPrice()` |
| `MixedBufferMultiVaultStableDetfInfoTarget.sol` | is*Allowed | **None** | delegates Common | synthetic |
| `MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol` | `previewExchangeIn` | none | **none** | quote |
| `MixedBufferMultiVaultStableDetfBondingTarget.sol` | `bootstrapFirstBond` / bond | live flags | **no synthetic threshold on bootstrap** | peg seed math |

**Findings (same class as F1/F2):** live missing from info helpers; no mode; no mint>burn init validation; dual-path extremes via `_deployOpenThresholdDetfN` and reentrancy args mint=1 burn=max.

### 3.2 PkgArgs / storage (today)

**`IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs`:**

```text
name, symbol, bufferToken, standardExchangeVaults, vaultShareRateProviders,
amplificationParameter, mintThreshold, burnThreshold
```

**Target trailing order:**

```text
... amplificationParameter, mintThreshold, burnThreshold, thresholdMode
```

**Repo `Storage` / `InitParams`:** add `ThresholdMode thresholdMode` beside thresholds.

**Resolve:** DFPkg local defaults → core `resolveAndRequireValidThresholds`.

**Write:** postDeploy sets `p.mintThreshold` / `p.burnThreshold` (~438–439); add mode + event.

### 3.3 Facet selectors

`MixedBufferMultiVaultStableDetfExchangeInFacet.sol`: `funcs_[19..22]` thresholds + is*. Add `thresholdMode`; sync both arrays.

### 3.4 Tests (threshold-related)

| Site | Role |
|------|------|
| `MixedBufferMultiVaultStableDetf_Deploy.t.sol` | inert deploy |
| `MixedBufferMultiVaultStableDetf_Pricing.t.sol` | closed mint/burn bands; gate coupling |
| `MixedBufferMultiVaultStableDetf_PriceShift.t.sol` | **T9 gold** — real skew under default ±5% |
| `MixedBufferMultiVaultStableDetf_Mint.t.sol` / `_Burn.t.sol` | open extremes helpers |
| `MixedBufferMultiVaultStableDetf_Liveness.t.sol` / `_Bootstrap.t.sol` | inert→live |
| `MixedBufferMultiVaultStableDetf_Reentrancy.t.sol` | mint=1 burn=max |
| `MixedBufferMultiVaultStableDetf_Guards.t.sol` / Routes / Claim | dual-path open extremes |
| TestBase `_deployDetfN` / `_buildPkgArgs` | threshold args only |

**Note:** Pricing test uses `_deployDetfN(1, type(uint256).max, 0)` for closed mint — after validation, `burn=0` resolves to **0.95e18**, not 0. Confirm existing intent: comment says “burnThreshold 0 maps to default”. Closed burn uses `_deployDetfN(1, 1, 1)` (mint=1, burn=1) — **will fail new mint>burn validation** (1 <= 1).  

**Migration for T4-compatible closed-burn fixtures:**

| Intent | Old | New valid Policy |
|--------|-----|------------------|
| Mint always closed | mint=max, burn=default or low | mint=`type(uint256).max`, burn=`0.95e18` (or 1) — valid if mint > burn |
| Burn always closed | mint=1, burn=1 (**invalid after PRD**) | mint=`1.05e18` (or 2), burn=`1` so synth ~1e18 never `< 1` is wrong; actually burn needs synth < burnThreshold. To close burn: burnThreshold=`1` means only synth `< 1` allows burn (essentially never for WAD prices). mint must be `> 1`, e.g. mint=`2` or `1.05e18`, burn=`1`. |

Execution agents **must** fix Pricing/Guards fixtures that set mint≤burn when adding validation.

---

## 4. API / storage diff

### 4.1 PkgArgs

```solidity
struct PkgArgs {
    string name;
    string symbol;
    IERC20 bufferToken;
    IStandardExchange[] standardExchangeVaults;
    IRateProvider[] vaultShareRateProviders;
    uint256 amplificationParameter;
    uint256 mintThreshold;       // 0 → 1.05e18
    uint256 burnThreshold;       // 0 → 0.95e18
    ThresholdMode thresholdMode; // trailing
}
```

### 4.2 Storage / InitParams

```solidity
uint256 mintThreshold;
uint256 burnThreshold;
ThresholdMode thresholdMode; // NEW
```

### 4.3 Event

```solidity
event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
```

Once at init with resolved values.

### 4.4 Info + facets

- `thresholdMode()` on `IMixedBufferMultiVaultStableDetfInfo`
- Facet selector arrays updated
- is*Allowed: live + mode + synthetic

---

## 5. Core lib integration

```solidity
// MixedBufferMultiVaultStableDetfCommon
function _isMintingAllowed() internal view returns (bool) {
    MixedBufferMultiVaultStableDetfRepo.Storage storage s = ...;
    if (!s.isReserveLive) return false;
    return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
}
// burn analog
```

### Gate call-site table (target)

| Function | Live | Mode/policy | Route notes |
|----------|------|-------------|-------------|
| exchangeIn mint buffer→DETF | require live | mode-aware | still buffer + vaultShare mint inputs |
| exchangeIn mint vaultShare→DETF | require live | mode-aware | |
| burn DETF→buffer | require live | mode-aware | **buffer only** even in Open |
| bootstrapFirstBond | makes live | **no** synthetic threshold | both modes |
| Info is* | !live ⇒ false | mode-aware | |

---

## 6. Touch list

| File | Change |
|------|--------|
| `MixedBufferMultiVaultStableDetfDFPkg.sol` | PkgArgs, DeployConfig, resolve/validate, init mode, event |
| `MixedBufferMultiVaultStableDetfRepo.sol` | Storage, InitParams, `_initialize` |
| `MixedBufferMultiVaultStableDetfCommon.sol` | mode-aware + live |
| `MixedBufferMultiVaultStableDetfExchangeInTarget.sol` | confirm |
| `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` | confirm |
| `MixedBufferMultiVaultStableDetfInfoTarget.sol` | `thresholdMode()` |
| `MixedBufferMultiVaultStableDetfExchangeInFacet.sol` | selectors |
| `MixedBufferMultiVaultStableDetf_*_FactoryService.sol` | if needed |
| `TestBase_MixedBufferMultiVaultStableDetf.sol` | helpers + PkgArgs |
| `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**` | Open suite + fix invalid threshold pairs |

---

## 7. Init / validation

Identical product law:

1. `requireValidThresholdMode`
2. `resolveAndRequireValidThresholds`
3. Store + emit `ThresholdModeSet` once

| Case | Expect |
|------|--------|
| Policy 0,0 | 1.05 / 0.95, mode Policy |
| Open 0,0 | store defaults; gates ignore |
| mint ≤ burn after resolve | revert (Policy **and** Open) |
| Open does not unlock vaultShare burn | burn still buffer-only (`InvalidRoute` / family error) |

---

## 8. Synthetic confirmation

| Gate | Function |
|------|----------|
| All primary mint/burn/info gates | **`MixedBufferMultiVaultStableDetfCommon._syntheticPrice()`** (owned BPT claim on math balances) |
| Spot | **Not used** |

---

## 9. Test map (T1–T19)

### 9.1 TestBase helpers

| Helper | Behavior |
|--------|----------|
| `_deployDetfN(n, mint, burn)` | default `thresholdMode: Policy`; optional mode overload |
| `_deployOpenThresholdDetfN(n)` | **Keep** Policy + 1/max dual-path; NatSpec clarify |
| `_deployOpenModeDetfN(n)` | **New:** Open + 0,0 thresholds |
| `_buildPkgArgs` | trailing mode field |

### 9.2 T1–T19 mapping

| ID | Proposed test | Notes |
|----|---------------|-------|
| T1 | Extend `MixedBufferMultiVaultStableDetf_Deploy.t.sol` | mode Policy, defaults, event |
| T2 | Deploy custom band | |
| T3 | **New** `MixedBufferMultiVaultStableDetf_ThresholdMode.t.sol` | Open deploy |
| T4 | Deploy reverts mint≤burn Policy+Open | also fix Pricing fixtures |
| T4b | extreme Policy still deploys | mode Policy |
| T5 | Pricing / PriceShift deadband | equality included |
| T6 | Mint happy when allowed | Policy or dual-path |
| T7 | Burn happy when allowed | buffer out |
| T8 | Liveness / Deploy inert | any mode |
| T9 | **`MixedBufferMultiVaultStableDetf_PriceShift.t.sol`** | keep green under default ±5% |
| T9b | Info match execution | live-coupled |
| T10 | Open live mint (buffer and/or share) + burn buffer inside former deadband | |
| T11 | Open inert blocked | |
| T12 | Mint/Burn preview==execution when allowed | TestBase helpers already compare |
| T13 | Open mint fee/seigniorage split | |
| T13b | Open live both is* true | |
| T14 | no post-deploy mode/threshold setter | Guards |
| T15 | Policy deadband not bypassed by alternate mint input (buffer vs share) | both gated |
| T16 | `MixedBufferMultiVaultStableDetf_Reentrancy.t.sol` | |
| T17 | Open round-trip mint→burn buffer | residual rules |
| T18 | extreme Policy reports Policy | |
| T19 | Open + non-default stored thresholds | no deadband reverts |

**Open must not:**

- Allow DETF→vaultShare burn if family forbids it (assert still reverts route error, not threshold)

### 9.3 Fixture repair list (compile/validation)

Search and fix any `mintThreshold`/`burnThreshold` pairs where after resolve `mint <= burn`:

- `MixedBufferMultiVaultStableDetf_Pricing.t.sol` — `_deployDetfN(1, 1, 1)` → e.g. `(2, 1)` or `(1.05e18, 1)`
- Reentrancy / guards if any equality pairs

---

## 10. Production-first rules

- `TestBase_MixedBufferMultiVaultStableDetf` + real MixedBuffer pool package + production SE legs.
- No mocks of SUT DETF/manager/registry/fee oracle/SE vaults/MixedBuffer pool under test.
- Bootstrap via production `bootstrapFirstBond` path.
- T9 via real underlying / pool skew as existing PriceShift does.

---

## 11. Rollout order

1. P0 core lib.
2. F1 patterns recommended for copy (Common/Info/event).
3. Repo → DFPkg → Common → Info/Facet → TestBase.
4. Fix invalid threshold fixtures **before** enabling strict validation in tests.
5. Policy regression (PriceShift, Pricing, Deploy, Liveness).
6. Open suite.
7. PROGRESS.md P3 → `done`.

---

## 12. Definition of done

- [x] Trailing `thresholdMode`; storage; resolve/validate both modes; event once
- [x] Mode-aware gates + `_syntheticPrice()`; live in family/info
- [x] Open does not change burn asset set (buffer-only preserved)
- [x] Bootstrap/first bond still synthetically ungated
- [x] Facet selectors include `thresholdMode`
- [x] Invalid mint≤burn fixtures fixed; T4 green
- [x] Policy suites green including PriceShift (T9)
- [x] Open suites T3, T10–T13b, T17–T19 (+ remaining map)
- [x] `forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**'` green (72/72)
- [x] PROGRESS.md updated

---

## 13. Out of scope

- Claim redeem / rebasing claim thresholds
- UI; fee-oracle mode/thresholds
- Asymmetric modes
- New burn assets under Open
- MixedBuffer pool package behavior changes (reserve infra only)
- F4 ComposedStableCommon (Wave 3)

---

## 14. Family PRD conform note (P7 docs)

Add to `MixedBufferMultiVaultStableDetf_PRD.md`: “Conforms to `DETF_Threshold_Modes_PRD`”; D7 ±5% remains Policy default; Open is deploy-time mode.
