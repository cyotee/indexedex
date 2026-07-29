# SingleStandardExchangeDETF — Threshold Modes Implementation & Test Plan

## 1. Normative refs

| Resource | Path |
|----------|------|
| Product law | [`../../DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) — **PRODUCT LAW LOCKED** + **§16** |
| Progress tracker | [`../../DETF_Threshold_Modes_PROGRESS.md`](../../DETF_Threshold_Modes_PROGRESS.md) |
| Core lib plan | [`../../core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Family PRD | [`SingleStandardExchangeDETF_PRD.md`](./SingleStandardExchangeDETF_PRD.md) |
| Existing impl plan | [`SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md`](./SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md) (link only; this file is additive) |
| Gold TestBase | [`TestBase_SingleStandardExchangeDETF.sol`](./TestBase_SingleStandardExchangeDETF.sol) |

**Conforms to product law + §16; no re-litigation.**  
**Family:** F1 / P0 gold — normative patterns for F2/F3.

Depends on **P0 core lib** API (`ThresholdMode`, `resolveAndRequireValidThresholds`, 3-arg allow helpers).

---

## 2. Goals / non-goals (F1 only)

### Goals

1. Deploy-time **Policy** (default) and **Open** via trailing `PkgArgs.thresholdMode`.
2. Source of truth: **PkgArgs → resolve → instance storage only** (never fee oracle).
3. Mode-aware gates on mint/burn using `_syntheticPrice()` + core lib.
4. Info surface: `thresholdMode()`, `isMintingAllowed()`, `isBurningAllowed()` with **live + mode + synthetic** accuracy (PRD §4.5).
5. Emit `ThresholdModeSet` once at init with **resolved** thresholds.
6. Keep existing Policy/gated and extreme-threshold dual-path tests green; **add** formal Open suites + named Open helper.
7. Map PRD T1–T19 to concrete tests.

### Non-goals

- Claim redeem / bond NFT term changes
- UI / marketing copy
- Fee-oracle threshold control
- Asymmetric modes
- Changing seigniorage split or usage fee schedules by mode
- Preview path adding new gate reverts (today preview is ungated math — keep; T12 = preview==execution when execution allowed)
- F2/F3/F4+ implementation

---

## 3. Current state audit (grep-backed)

### 3.1 Gate call sites

| Location | Function | Live check | Policy check | Price |
|----------|----------|------------|--------------|-------|
| `SingleStandardExchangeDETFExchangeInTarget.sol` | `exchangeIn` mint branch (`tokenOut == this`) | `_requireReserveLive()` then | `_isMintingAllowed()` → `MintingNotAllowed` | `_syntheticPrice()` |
| `SingleStandardExchangeDETFExchangeOutTarget.sol` | `_burnDetfExactIn` | `_requireReserveLive()` then | `_isBurningAllowed()` → `BurningNotAllowed` | `_syntheticPrice()` |
| `SingleStandardExchangeDETFCommon.sol` | `_isMintingAllowed()` / `_isBurningAllowed()` | **None** (threshold only) | `DETFThresholdPolicy._is*(threshold, price)` 2-arg | `_syntheticPrice()` |
| `SingleStandardExchangeDETFInfoTarget.sol` | `isMintingAllowed` / `isBurningAllowed` | **None** (delegates Common) | same | synthetic |
| `SingleStandardExchangeDETFExchangeInQueryTarget.sol` | `previewExchangeIn` | none | **none** | N/A quote math |
| `SingleStandardExchangeDETFBondingTarget.sol` | first bond / bond | live for non-bootstrap paths | **no synthetic threshold gate** on first bond | — |

**Audit findings to fix:**

1. Info/`_is*Allowed` ignore **live** → under extreme thresholds (`mint=1`), inert instance can report `isMintingAllowed()==true`. PRD §4.5: inert ⇒ both false.
2. No `thresholdMode` storage or PkgArgs field.
3. No `mint > burn` validation after resolve.
4. Defaults duplicated in DFPkg + Common; should import core constants after P0.
5. `_deployOpenThresholdDetf` is **extreme Policy**, not product Open.

### 3.2 PkgArgs / storage / init (today)

**`ISingleStandardExchangeDETDFPkg.PkgArgs`** (`SingleStandardExchangeDETDFPkg.sol`):

```text
name, symbol, standardExchangeVault, standardExchangeVaultShare, rateTarget,
detfWeight, vaultShareWeight, mintThreshold, burnThreshold
```

**`SingleStandardExchangeDETFRepo.Storage`:** `mintThreshold`, `burnThreshold` (no mode).

**Resolve (DFPkg `initAccount`):** `0 → 1.05e18 / 0.95e18` local constants.

**Write:** `_initFamilyRepo` → `Repo._initialize(..., mintThreshold_, burnThreshold_, ...)`.

**Event:** none for thresholds.

### 3.3 Info / facet selectors (today)

`ISingleStandardExchangeDETFInfo`: `mintThreshold`, `burnThreshold`, `isMintingAllowed`, `isBurningAllowed` — **no** `thresholdMode`.

`SingleStandardExchangeDETFExchangeInFacet`: `funcs_[10..13]` = mint/burn thresholds + is*Allowed. Need slot for `thresholdMode`.

### 3.4 Tests using extreme thresholds (dual-path)

| Helper / site | Pattern |
|---------------|---------|
| `TestBase_SingleStandardExchangeDETF._deployOpenThresholdDetf` | mint=1, burn=max |
| `SingleStandardExchangeDETF_Mint.t.sol`, `_Burn.t.sol`, `_Disable.t.sol`, `_Reentrancy.t.sol` | open extremes |
| `adversarial/TestBase_*`, fuzz, invariant | `_deployOpenThresholdDetf` |
| Fork matrix UniV4 / DualLiquidity / ComposedStable | mint=1, burn=max in PkgArgs |

Keep these as **Policy extreme** dual-path (T4b/T18). Add **separate** `_deployOpenModeDetf` with `thresholdMode: Open`.

---

## 4. API / storage diff

### 4.1 `PkgArgs` (trailing `thresholdMode`)

**Final field order (locked):**

```solidity
struct PkgArgs {
    string name;
    string symbol;
    IStandardExchangeProxy standardExchangeVault;
    IERC20 standardExchangeVaultShare;
    IERC20 rateTarget;
    uint256 detfWeight;          // 0 → 80e16
    uint256 vaultShareWeight;    // 0 → 20e16
    uint256 mintThreshold;       // 0 → 1.05e18
    uint256 burnThreshold;       // 0 → 0.95e18
    ThresholdMode thresholdMode; // trailing; 0 = Policy default
}
```

**Breaking:** every `PkgArgs({...})` / `abi.encode(args)` must set `thresholdMode` (or rely on zero = Policy for partial updates if using named fields).

### 4.2 Repo storage

Append after thresholds (or adjacent):

```solidity
struct Storage {
    // ... existing through vaultShareWeight ...
    uint256 mintThreshold;
    uint256 burnThreshold;
    ThresholdMode thresholdMode; // NEW — default 0 = Policy for old diamonds N/A (immutable new packages only)
    // feeOracle, bondNftVault, ...
}
```

Update `_initialize` signature to accept `ThresholdMode thresholdMode_` (and store it).

`Init` param order in `_initialize`: keep existing args; **append** `thresholdMode_` before or after feeOracle — document exact signature in PR:

```text
..., uint256 mintThreshold_, uint256 burnThreshold_, ThresholdMode thresholdMode_,
IVaultFeeOracleQuery feeOracle_, ...
```

### 4.3 Event (canonical ABI)

Declare on interface used by clients, e.g. `ISingleStandardExchangeDETFInfo` or package interface:

```solidity
event ThresholdModeSet(
    ThresholdMode mode,
    uint256 mintThreshold,
    uint256 burnThreshold
);
```

Emit **once** from DFPkg path that writes repo (`_initFamilyRepo` / immediately after `Repo._initialize`) with **resolved** values.

### 4.4 Info selectors

```solidity
function thresholdMode() external view returns (ThresholdMode);
function mintThreshold() external view returns (uint256); // existing
function burnThreshold() external view returns (uint256); // existing
function isMintingAllowed() external view returns (bool);   // live + mode + synth
function isBurningAllowed() external view returns (bool);   // live + mode + synth
```

### 4.5 Facet function arrays

In `SingleStandardExchangeDETFExchangeInFacet` (`facetFuncs` + any duplicate array):

- Insert `ISingleStandardExchangeDETFInfo.thresholdMode.selector` (recommended: immediately before or after mint/burn threshold selectors).
- Bump array length; keep both pure facet listings in sync (file has two nearly identical arrays today).

FactoryService: only if it hardcodes selector counts — update if present. Prefer grepping `thresholdMode` / `funcs_.length` after edit.

---

## 5. Core lib integration

| Concern | Implementation |
|---------|----------------|
| Import | `DETFThresholdPolicy`, `ThresholdMode` from core |
| Resolve + validate | `resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)` in `initAccount` |
| Mode validate | `requireValidThresholdMode(args.thresholdMode)` |
| Allow | `DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, price)` |
| Live | **Family only:** `_requireReserveLive()` on execution; Common info helpers check `isReserveLive` before allow |
| Defaults | Prefer `DETFThresholdPolicy.DEFAULT_*`; remove local DFPkg/Common duplicates when safe |

### 5.1 Common helper rewrite (normative pattern)

```solidity
function _isMintingAllowed() internal view returns (bool) {
    SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
    if (!s.isReserveLive) return false;
    return DETFThresholdPolicy._isMintingAllowed(
        s.thresholdMode,
        s.mintThreshold,
        _syntheticPrice()
    );
}

function _isBurningAllowed() internal view returns (bool) {
    SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
    if (!s.isReserveLive) return false;
    return DETFThresholdPolicy._isBurningAllowed(
        s.thresholdMode,
        s.burnThreshold,
        _syntheticPrice()
    );
}
```

Execution path:

```text
_requireReserveLive(); // reverts ReservePoolNotInitialized if inert
if (!_isMintingAllowed()) revert MintingNotAllowed(...); // Policy deadband only when live
```

When live + Open, `_isMintingAllowed()` is always true (lib short-circuit).  
When live + Policy deadband, reverts `MintingNotAllowed(synthetic, mintThreshold)`.  
When inert, execution hits `_requireReserveLive` first (not deadband error).

### 5.2 Gate call-site table (target)

| Function | Live | Policy/Open |
|----------|------|-------------|
| `exchangeIn` mint | `_requireReserveLive` | mode-aware `_isMintingAllowed` |
| `_burnDetfExactIn` | `_requireReserveLive` | mode-aware `_isBurningAllowed` |
| `isMintingAllowed` view | false if !live | mode-aware |
| `isBurningAllowed` view | false if !live | mode-aware |
| first bond bootstrap | family live transition | **no** synthetic threshold gate |

---

## 6. Touch list (concrete files)

| File | Change |
|------|--------|
| `../../core/DETFThresholdPolicy.sol` | P0 prerequisite |
| `SingleStandardExchangeDETDFPkg.sol` | PkgArgs trailing mode; DeployConfig.mode; resolve/validate; pass mode to repo; emit event |
| `SingleStandardExchangeDETFRepo.sol` | storage + `_initialize` param; optional event declaration if kept here |
| `SingleStandardExchangeDETFCommon.sol` | mode-aware `_is*Allowed` + live short-circuit; drop local default constants if unused |
| `SingleStandardExchangeDETFExchangeInTarget.sol` | no logic change if Common fixed; confirm mint gate order |
| `SingleStandardExchangeDETFExchangeOutTarget.sol` | same |
| `SingleStandardExchangeDETFInfoTarget.sol` | `thresholdMode()` view; interface update |
| `SingleStandardExchangeDETFExchangeInFacet.sol` | selector arrays + length |
| `SingleStandardExchangeDETF_Facet_FactoryService.sol` | only if needed for facet redeploy naming |
| `SingleStandardExchangeDETF_Pkg_FactoryService.sol` / Component | only if encodes PkgArgs |
| `TestBase_SingleStandardExchangeDETF.sol` | all PkgArgs; helpers below |
| Specs under `test/foundry/spec/vaults/detf/standardExchange/single/**` | Open suite + update struct literals |
| Fork matrix tests that build `PkgArgs` | add `thresholdMode: Policy` (or Open where intended) |

---

## 7. Init / validation

**Site:** `SingleStandardExchangeDETDFPkg.initAccount` (resolve into `DeployConfig`) + `_initFamilyRepo` (persist + event).

```text
1. requireValidThresholdMode(args.thresholdMode)
2. (mint, burn) = resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)
3. cfg.mintThreshold = mint; cfg.burnThreshold = burn; cfg.thresholdMode = args.thresholdMode
4. postDeploy → Repo._initialize(..., mint, burn, mode, ...)
5. emit ThresholdModeSet(mode, mint, burn) once
```

| Case | Result |
|------|--------|
| mode omitted / 0 | Policy |
| mode Open | store Open; thresholds still resolved/stored |
| Open + `0,0` | store 1.05/0.95; gates ignore |
| Open + custom | store custom; gates ignore |
| after resolve mint ≤ burn | revert `InvalidThresholdPair` |
| mode > Open | revert `InvalidThresholdMode` |
| Policy extreme 1 / max | legal Policy |

---

## 8. Synthetic confirmation

| Gate | Price function |
|------|----------------|
| Mint / burn / info | **`_syntheticPrice()`** in `SingleStandardExchangeDETFCommon` |
| Spot | **Not used** |

Zero supply: `_syntheticPrice()` returns `1e18` (existing). No Open-specific zero-supply path.

---

## 9. Test map (T1–T19 → concrete names)

### 9.1 TestBase helpers

| Helper | Behavior |
|--------|----------|
| `_deployDetfInstance()` | Policy, `0,0` thresholds, `thresholdMode: Policy` (or zero) |
| `_deployOpenThresholdDetf(name, symbol)` | **Keep** dual-path: Policy + mint=1, burn=max; set `thresholdMode: Policy` explicitly; NatSpec: “extreme Policy, not product Open” |
| `_deployOpenModeDetf(name, symbol)` | **New:** `thresholdMode: Open`, thresholds `0,0` (or optional custom) |
| `_deployPolicyThresholds(mint, burn)` | **New (optional):** Policy + custom band for T2/T4 |

### 9.2 Suggested new / extended contracts

| PRD | Test contract / function | Notes |
|-----|--------------------------|-------|
| **T1** | `SingleStandardExchangeDETF_Deploy_Test.test_deploy_inert_notLive` (extend) + `test_deploy_policyDefaults_thresholdModeAndEvent` | assert mode Policy; thresholds 1.05/0.95; `vm.expectEmit` ThresholdModeSet |
| **T2** | `test_deploy_policyCustomBand` | e.g. 1.10e18 / 0.90e18 stored |
| **T3** | `SingleStandardExchangeDETF_ThresholdMode_Open_Test.test_openDeploy_modeAndStoredThresholds` | Open + 0,0 → defaults stored |
| **T4** | `test_deploy_revertsWhenMintLeBurn_policy` / `_open` | both modes |
| **T4b** | existing extreme helper still deploys; `test_extremePolicy_stillModePolicy` | |
| **T5** | extend `SingleStandardExchangeDETF_Info.t.sol` / Requirements | deadband incl. equality |
| **T6** | existing mint happy under allowed regime / open extremes | keep Policy path |
| **T7** | existing burn happy | keep |
| **T8** | `test_deploy_mintRevertsWhileInert` + Open inert variant | Open still `ReservePoolNotInitialized` |
| **T9** | existing PriceShift / Requirements trade drive | default ±5% |
| **T9b** | `test_infoViews_matchExecution_policy` | |
| **T10** | `test_openLive_mintAndBurnInsideFormerDeadband` | bootstrap Open; assert synth in (0.95,1.05); mint+burn succeed |
| **T11** | `test_openInert_mintBlocked` | |
| **T12** | existing Mint/Burn preview==execution | under Open and Policy-allowed |
| **T13** | `test_openMint_appliesUsageFeeAndSeigniorageSplit` | balances feeTo/protocol |
| **T13b** | `test_openLive_infoBothAllowed` | |
| **T14** | `test_noPostDeployThresholdOrModeSetter` | no selector / low-level call fails |
| **T15** | existing Guards / UnsupportedRoute | Policy deadband still applies on mint/burn routes only |
| **T16** | existing Reentrancy suite | keep extreme Policy or Open mode |
| **T17** | `test_openRoundTrip_mintThenBurn` | fees/residuals; no MintingNotAllowed/BurningNotAllowed |
| **T18** | `test_extremePolicy_reportsModePolicy` | `thresholdMode()==Policy` |
| **T19** | `test_openWithNonDefaultStoredThresholds_neverDeadbandRevert` | Open + mint=1.2e18 burn=0.8e18; live mint/burn ok |

**New file (recommended):**

`test/foundry/spec/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_ThresholdMode.t.sol`

Holds Open-focused T3, T4, T10–T13b, T17–T19 to avoid bloating Deploy/Mint.

### 9.3 Keep green (Policy baseline)

- `SingleStandardExchangeDETF_Deploy.t.sol`
- `SingleStandardExchangeDETF_Info.t.sol` — update coupling if live-gated: inert false; live Policy coupling unchanged
- `SingleStandardExchangeDETF_Mint.t.sol`, `_Burn.t.sol`, `_Requirements.t.sol`, `_Guards.t.sol`, bonding, reentrancy, fuzz, invariant
- Fork matrices: add `thresholdMode: Policy` to struct literals (behavior unchanged with extremes)

### 9.4 Info test fix note

Today `SingleStandardExchangeDETF_Info.t.sol` asserts:

```text
isMintingAllowed() == (synth > mintThreshold)
```

After live coupling, assert:

```text
isMintingAllowed() == (isReserveLive && policyOrOpenAllow)
```

For Open live: both true regardless of synth. For inert: both false.

---

## 10. Production-first rules

- Inherit `TestBase_SingleStandardExchangeDETF` (→ IndexedexTest → CraneTest).
- Deploy DETF via manager registry / package path only — **no** `new` DFPkg/facets.
- **No mocks** of DETF diamond, facets, DFPkg, manager, registry, fee oracle, attached SE vaults.
- Mintable ERC20 funding + existing reentrancy hostile share for attack tests only.
- Drive synthetic for T9 via **real underlying pool trades**, not mock price.

---

## 11. Rollout order (inside F1)

1. **P0 core lib** green (if not already).
2. Repo storage + `_initialize` signature.
3. DFPkg PkgArgs / DeployConfig / resolve / validate / event emit.
4. Common mode-aware + live info helpers.
5. Info interface + `thresholdMode()` + facet selectors.
6. TestBase PkgArgs + `_deployOpenModeDetf`; fix all struct literals to compile.
7. Policy suite green (regression).
8. Open suite T1–T19 mapped cases green.
9. Update PROGRESS.md P1 → `done`.

---

## 12. Definition of done

- [ ] Trailing `thresholdMode` on `ISingleStandardExchangeDETDFPkg.PkgArgs`
- [ ] Storage + init resolve/validate both modes; invalid pair/mode revert
- [ ] `ThresholdModeSet` emitted once with resolved thresholds
- [ ] Gates use mode-aware lib + `_syntheticPrice()`; live in family
- [ ] `thresholdMode()` / live-correct `isMintingAllowed` / `isBurningAllowed`
- [ ] Facet selectors include `thresholdMode`
- [ ] Existing Policy + extreme dual-path tests green
- [ ] Open suites cover T3, T8/T11 Open, T10, T12–T13b, T17–T19
- [ ] Full mapped T1–T19 addressed or N/A with reason
- [ ] `forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**'` green
- [ ] PROGRESS.md updated

---

## 13. Out of scope

- Claim redeem / `RedemptionNotAllowed`
- Frontend
- Fee-oracle thresholds or mode
- Asymmetric modes
- Nested composition rules between outer/inner DETFs (modes independent)
- Changing first-bond synthetic ungating
- F2/F3 code (separate plans)

---

## 14. Risks specific to F1 audit

| Risk | Mitigation |
|------|------------|
| Live coupling changes Info expectations | Update Info tests; document PRD accuracy table |
| Many PkgArgs call sites (fork + nested) | Grep `PkgArgs({` and `mintThreshold:` under test/ + contracts/ |
| Event emit double in initAccount vs postDeploy | Emit only once after storage write in `_initFamilyRepo` |
| Open + residual inventory | T17 uses existing residual zero assertions from Mint/Burn |
