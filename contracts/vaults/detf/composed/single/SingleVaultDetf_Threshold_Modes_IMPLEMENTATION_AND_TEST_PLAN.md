# SingleVaultDetf — Threshold Modes Implementation & Test Plan

## 1. Normative refs

| Resource | Path |
|----------|------|
| Product law | [`../../DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) — **formal LOCKED 2026-07-28** + **§16** encoding locks |
| Progress tracker | [`../../DETF_Threshold_Modes_PROGRESS.md`](../../DETF_Threshold_Modes_PROGRESS.md) |
| Core lib (shipped) | [`../../core/DETFThresholdPolicy.sol`](../../core/DETFThresholdPolicy.sol) |
| Gold F1 plan | [`../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| F4 plan (Wave 3 peer; already synthetic) | [`../stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Family historical plan (context only) | [`UNISWAP_V4_SINGLE_DETF_IMPLEMENTATION_PLAN.md`](./UNISWAP_V4_SINGLE_DETF_IMPLEMENTATION_PLAN.md) — **do not** re-adopt spot gates |
| Production tests | `test/foundry/spec/vaults/detf/composed/single/**` |

**Conforms to product law + §16; no re-litigation.**  
**Family:** F5 / Wave 3 — **mandatory synthetic migration** for mint/burn gates, then same Policy/Open product surface as F1–F4.  
**Depends on:** shipped P0 core lib API. Do **not** redesign the lib.

**Role names only** in plan language and proposed APIs: `rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken` / `address(this)`, `reservePool` / reserve BPT.  
**Forbidden:** re-introducing brand-era names (`RICH`, `RICHIR`, `richToken`, `wethRich`, `mintWithWeth` as generic API, etc.) into new surfaces. Existing file names (e.g. `*MintWithWeth.t.sol`) may remain until a separate rename pass; **new** helpers/APIs use role names (`mintWithRateAsset` already preferred where present).

**Family PRD conform note:** P7 one-liner only if/when a family PRD is maintained.

---

## 2. Goals / non-goals (F5 only)

### Goals

1. **Mandatory synthetic / FD migration** for **all** mint/burn **gates** and **`is*Allowed`** views (product law: never gate on reserve spot).
2. Deploy-time **Policy** (default) and **Open** via **trailing** `PkgArgs.thresholdMode`.
3. Expose configurable `mintThreshold` / `burnThreshold` on `PkgArgs` (today hardcoded) with resolve/`0` → defaults `1.05e18` / `0.95e18`.
4. Mode-aware gates via core lib 3-arg helpers; live only in family; Open short-circuit only in lib.
5. MUST: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()`.
6. Emit `ThresholdModeSet` once at init with **resolved** values.
7. Keep / rewrite Policy suites so they assert **synthetic** gates; add Open suites; dual-path extremes documented vs product Open.
8. Map T1–T19 to concrete F5 tests.

### Non-goals

- Claim redeem product redesign (`RedemptionNotAllowed` remains independent of Open)
- Superchain bridge transport product changes
- Brand-era renames of entire package (out of threshold program)
- UI / fee-oracle thresholds / asymmetric modes
- F4 / F6 / F7 / AGENTS.md
- Inventing a second multi-asset FX “numeraire” ledger — use existing `_calcSyntheticPrice()` FD formula
- Production Solidity in the **plan-only** session that authors this file

---

## 3. Current state audit (grep-backed, 2026-07-28)

### 3.1 Synthetic migration (mandatory — do this first)

#### 3.1.1 Price helpers (today)

| Helper | Location | Semantics | Used for gates today? |
|--------|----------|-----------|------------------------|
| `_calcReserveSpotPrice()` | `SingleVaultDetfCommon.sol` | Weighted-pool **spot** from reserve balances + weights (`BalancerV38020WeightedPoolMath.priceFromReserves`) | **YES — all mint/burn gates + is*Allowed** |
| `_calcSyntheticPrice()` | `SingleVaultDetfCommon.sol` | **FD / synthetic**: owned reserve BPT claim on pool balances (rate-scaled vault leg + DETF leg) ÷ `totalSupply`; zero-supply → `1e18` | **NO for gates** — only exposed as `syntheticPrice()` info view |
| `syntheticPrice()` | `SingleVaultDetfInfoTarget.sol` | returns `_calcSyntheticPrice()` | display only |

#### 3.1.2 Before → after (gates / allow)

| Call site | Before (illegal under product law) | After (required) |
|-----------|------------------------------------|------------------|
| `SingleVaultDetfExchangeInTarget.sol` mint (`mintWithRateAsset`) | `_calcReserveSpotPrice()` → `_isMintingAllowed` | `_calcSyntheticPrice()` → mode-aware `_isMintingAllowed` |
| `SingleVaultDetfExchangeInTarget.sol` burn DETF→rateAsset | spot → `_isBurningAllowed` | synthetic → mode-aware |
| `SingleVaultDetfExchangeOutTarget.sol` burn DETF→rateAsset exact-out | spot → `_isBurningAllowed` | synthetic → mode-aware |
| `SingleVaultDetfExchangeInQueryTarget.sol` `previewExchangeIn` DETF→rateAsset | spot → burn gate | synthetic → mode-aware (**keep gate-on-preview if family already gates**; parity with execution) |
| `SingleVaultDetfExchangeInQueryTarget.sol` `previewExchangeOut` DETF→rateAsset | spot → burn gate | synthetic → mode-aware |
| `SingleVaultDetfInfoTarget.sol` `isMintingAllowed` / `isBurningAllowed` | spot | synthetic + **live** + mode |
| Common `_isMintingAllowed` / `_isBurningAllowed` | 2-arg Policy wrappers | 3-arg mode-aware; live short-circuit in family |

#### 3.1.3 May keep spot (non-gate only)

| Use | Keep? |
|-----|-------|
| Internal diagnostics / future display of pool spot | **Optional** — may retain `_calcReserveSpotPrice()` for **non-gate** reads only |
| Mint/burn gates, `is*Allowed`, threshold error payloads | **Must use synthetic** — error args today named `reserveSpotPrice` should report **synthetic** (error type remains `MintingNotAllowed(syntheticPrice, mintThreshold)` per `IProtocolDETFErrors`) |

**Do not** invent a new synthetic formula. Prefer existing `_calcSyntheticPrice()` (F1 analog: fully diluted backing from owned reserve BPT claim ÷ DETF supply). If bond-NFT-held BPT must be included for parity with F1 peers, audit peers and extend FD inventory **only if** F5 production pricing already intends that — default is keep current `_calcSyntheticPrice()` math and switch gates to it.

#### 3.1.4 Tests that assert spot-based gate behavior (must rewrite)

| Test / helper | Issue |
|---------------|--------|
| `SingleVaultDetfExchangeIn_MintWithWeth.t.sol` `_assertMintEnabled` / `_driveToMintEnabled` | Uses `isMintingAllowed()` and compares `syntheticPrice()` to thresholds **while gates use spot** — after migration, drive **synthetic** regime (or Open mode); align trade driver with synthetic, not spot |
| Deploy test `assertEq(detf.mintThreshold(), 1005e15)` | Hardcoded ±0.5% band — after PkgArgs + resolve, default Policy `0,0` → **1.05e18 / 0.95e18** unless tests pass explicit custom thresholds |
| Any fixture that trades to move **spot** into band while synthetic differs | Will flake or mis-gate — rewrite to synthetic or Open |

---

### 3.2 Gate call sites (full table)

| Location | Function | Live check | Policy (today) | Price (today) |
|----------|----------|------------|----------------|---------------|
| `SingleVaultDetfExchangeInTarget.sol` | `mintWithRateAsset` | `_isInitialized()` → `ReservePoolNotInitialized` | 2-arg Policy `_isMintingAllowed` | **spot** |
| `SingleVaultDetfExchangeInTarget.sol` | `exchangeIn` DETF→rateAsset burn | (via path) | 2-arg burn | **spot** |
| `SingleVaultDetfExchangeOutTarget.sol` | `exchangeOut` DETF→rateAsset | (via path) | 2-arg burn | **spot** |
| `SingleVaultDetfExchangeInQueryTarget.sol` | `previewExchangeIn` DETF→rateAsset | `_isInitialized` | 2-arg burn | **spot** |
| `SingleVaultDetfExchangeInQueryTarget.sol` | `previewExchangeOut` DETF→rateAsset | `_isInitialized` | 2-arg burn | **spot** |
| `SingleVaultDetfCommon.sol` | `_isMintingAllowed` / `_isBurningAllowed` | **None** | 2-arg Policy lib | caller price |
| `SingleVaultDetfInfoTarget.sol` | `isMintingAllowed` / `isBurningAllowed` | **None** | same | **spot** |
| Bonding | bond paths | family | **no** primary synthetic deadband on first bond (keep) | — |
| Claim redeem / rebasing | claim paths | family | **out of threshold-mode scope** | — |

**Audit findings to fix:**

1. **Spot gates violate product law** — mandatory migration (§3.1).
2. No `thresholdMode` storage or PkgArgs field.
3. Thresholds **hardcoded** in `SingleVaultDetfDFPkg.initAccount` as `1005e15` / `995e15` — not product defaults; not overridable via PkgArgs.
4. No resolve / mint>burn validation / `ThresholdModeSet` event.
5. Info `is*Allowed` ignores **live** (PRD §4.5).
6. Common uses 2-arg Policy-only lib helpers.

### 3.3 PkgArgs / storage / init (today)

**`ISingleVaultDetfDFPkg.PkgArgs`** (today — **no thresholds/mode**):

```text
name, symbol, pairToken,
pairInitialDepositAmount, rateAssetInitialDepositAmount,
underlyingPoolKey, underlyingWidthMultiplier
```

**Init hardcode** (`SingleVaultDetfDFPkg.initAccount`):

```solidity
SingleVaultDetfRepo._initialize(
    VAULT_FEE_ORACLE_QUERY,
    BALANCER_V3_PREPAY_ROUTER,
    args.pairToken,
    RATE_ASSET,
    1005e15,  // mint — NOT product default
    995e15    // burn — NOT product default
);
```

**`SingleVaultDetfRepo.Storage`:** `mintThreshold`, `burnThreshold` (no mode).

**Factory:** `SingleVaultDetf_Component_FactoryService.buildPkgArgs` — no threshold/mode params.

### 3.4 Info / facet selectors (today)

`SingleVaultDetfInfoFacet` / `IProtocolDETF`:

```text
... syntheticPrice, mintThreshold, burnThreshold, isMintingAllowed, isBurningAllowed
```

**Missing:** `thresholdMode()`.

Both `funcs_` and `functions_` arrays (length 13 today for threshold block) need a new selector slot.

### 3.5 Tests inventory (production-first homes)

| Area | Path |
|------|------|
| Deploy | `SingleVaultDetfDFPkg_Deploy.t.sol` |
| Mint / gates | `SingleVaultDetfExchangeIn_MintWithWeth.t.sol` |
| Mint sell redeem | `SingleVaultDetf_MintSellRedeem.t.sol` |
| Production base | `SingleVaultDetf_ProductionBase.t.sol` |
| Bond / bridge | auction bond, bridge transport |
| Facet IFacet | Info / Exchange In/Out/Query / Bonding |
| Adversarial / fuzz | `adversarial/`, `fuzz/` |

No dedicated Open-mode suite yet.

---

## 4. API / storage diff

### 4.1 `PkgArgs` (append thresholds + trailing mode)

**Locked final field order:**

```solidity
struct PkgArgs {
    string name;
    string symbol;
    IERC20 pairToken;
    uint256 pairInitialDepositAmount;
    uint256 rateAssetInitialDepositAmount;
    PoolKey underlyingPoolKey;
    uint24 underlyingWidthMultiplier;
    uint256 mintThreshold;       // 0 → 1.05e18
    uint256 burnThreshold;       // 0 → 0.95e18
    ThresholdMode thresholdMode; // trailing; 0 = Policy
}
```

Remove hardcoded `1005e15` / `995e15` from init; use resolve from args.

**Tests that need the old ±0.5% band** must pass explicit `mintThreshold: 1005e15, burnThreshold: 995e15, thresholdMode: Policy` — do not treat hardcode as product default.

### 4.2 Repo storage

```solidity
struct Storage {
    // ... existing through vaultTokenWeight ...
    uint256 mintThreshold;
    uint256 burnThreshold;
    ThresholdMode thresholdMode; // NEW
    // acceptedBondTokens ...
}
```

Update `_initialize` overloads:

```text
..., mintThreshold_, burnThreshold_, ThresholdMode thresholdMode_
```

### 4.3 Event

```solidity
event ThresholdModeSet(
    ThresholdMode mode,
    uint256 mintThreshold,
    uint256 burnThreshold
);
```

Emit once after storage write in `initAccount` (or postDeploy if thresholds are only finalized then — **today thresholds write in initAccount**, so emit there with resolved values). Single emit only.

### 4.4 Info selectors

```solidity
function thresholdMode() external view returns (ThresholdMode);
// existing:
function mintThreshold() external view returns (uint256);
function burnThreshold() external view returns (uint256);
function isMintingAllowed() external view returns (bool); // live + mode + synthetic
function isBurningAllowed() external view returns (bool);
function syntheticPrice() public view returns (uint256); // remains _calcSyntheticPrice
```

Update `SingleVaultDetfInfoFacet` both selector arrays + IFacet tests.

### 4.5 FactoryService

Extend `buildPkgArgs` with mint/burn/mode parameters (or overload). Default mode Policy; thresholds `0,0` for product defaults.

---

## 5. Core lib integration (shipped API only)

| Concern | Implementation |
|---------|----------------|
| Import | `DETFThresholdPolicy`, `ThresholdMode` from core |
| Mode validate | `requireValidThresholdMode(args.thresholdMode)` |
| Resolve | `resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)` |
| Allow | 3-arg `_isMintingAllowed` / `_isBurningAllowed` |
| Live | Family: `_isInitialized()` / reserve initialized; views false if inert |
| Price for gates | **`_calcSyntheticPrice()` only** |
| Open | Lib short-circuit only |

### 5.1 Common rewrite (after synthetic migration)

```solidity
function _isMintingAllowed(SingleVaultDetfRepo.Storage storage layoutStruct_)
    internal
    view
    returns (bool)
{
    if (!_isInitialized()) return false;
    return DETFThresholdPolicy._isMintingAllowed(
        layoutStruct_.thresholdMode,
        layoutStruct_.mintThreshold,
        _calcSyntheticPrice()
    );
}

function _isBurningAllowed(SingleVaultDetfRepo.Storage storage layoutStruct_)
    internal
    view
    returns (bool)
{
    if (!_isInitialized()) return false;
    return DETFThresholdPolicy._isBurningAllowed(
        layoutStruct_.thresholdMode,
        layoutStruct_.burnThreshold,
        _calcSyntheticPrice()
    );
}
```

Update all call sites that previously passed `reserveSpotPrice` to use the new helpers (or pass `_calcSyntheticPrice()` into 3-arg wrappers). **Delete spot from gate paths.**

Execution:

```text
if (!_isInitialized()) revert ReservePoolNotInitialized();
if (!_isMintingAllowed(layoutStruct)) revert MintingNotAllowed(_calcSyntheticPrice(), layoutStruct.mintThreshold);
```

### 5.2 Target gate table

| Function | Live | Mode | Price |
|----------|------|------|-------|
| `mintWithRateAsset` | initialized | mode-aware | **synthetic** |
| DETF→rateAsset burn (In/Out) | initialized | mode-aware | **synthetic** |
| Preview In/Out burn paths | same | mode-aware | **synthetic** |
| `isMintingAllowed` / `isBurningAllowed` | false if !live | mode-aware | **synthetic** |
| First bond | family | no synthetic deadband | — |
| Claim redeem | family | out of scope | — |

---

## 6. Touch list (concrete files)

| File | Change |
|------|--------|
| `SingleVaultDetfCommon.sol` | synthetic on gates; mode-aware + live `_is*Allowed`; keep `_calcReserveSpotPrice` only if non-gate |
| `SingleVaultDetfExchangeInTarget.sol` | all mint/burn gate call sites → synthetic + mode |
| `SingleVaultDetfExchangeOutTarget.sol` | burn gate → synthetic + mode |
| `SingleVaultDetfExchangeInQueryTarget.sol` | both preview gate sites → synthetic + mode |
| `SingleVaultDetfInfoTarget.sol` | `thresholdMode()`; is*Allowed live + synthetic + mode |
| `SingleVaultDetfInfoFacet.sol` | selector arrays |
| `SingleVaultDetfRepo.sol` | storage + `_initialize` mode param |
| `SingleVaultDetfDFPkg.sol` | PkgArgs fields; resolve/validate; store mode; emit event; remove hardcode |
| `SingleVaultDetf_Component_FactoryService.sol` | `buildPkgArgs` thresholds + mode |
| `contracts/interfaces/IProtocolDETF.sol` (if needed) | optional `thresholdMode()` for F6 alignment — prefer ship on diamond now; full NatSpec is F6 |
| Specs under `test/foundry/spec/vaults/detf/composed/single/**` | rewrite spot-gate tests; Open suite; Deploy thresholds; IFacet selectors |
| Fork/matrix constructors of `SingleVaultDetf` PkgArgs | trailing fields |

---

## 7. Init / validation sequence

**Site:** `SingleVaultDetfDFPkg.initAccount`.

```text
1. requireValidThresholdMode(args.thresholdMode)
2. (mint, burn) = resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)
3. SingleVaultDetfRepo._initialize(..., mint, burn, args.thresholdMode)
4. emit ThresholdModeSet(args.thresholdMode, mint, burn) once
5. ... remainder of init (ERC20, bridge, ownable, deployment config) unchanged
```

| Case | Result |
|------|--------|
| Policy + `0,0` | store 1.05e18 / 0.95e18, mode Policy |
| Open + `0,0` | store defaults, mode Open; gates ignore thresholds |
| Open + custom thresholds | store custom; gates ignore |
| mint ≤ burn after resolve | `InvalidThresholdPair` |
| mode > Open | `InvalidThresholdMode` |
| Explicit 1005e15 / 995e15 Policy | legal custom Policy (±0.5% band) for legacy tests |

---

## 8. TestBase / deploy helpers

This family may not have a gold `TestBase_*` co-located like F1; use `SingleVaultDetf_ProductionBase.t.sol` / deploy helpers as the production path.

| Helper | Behavior |
|--------|----------|
| Default deploy | Policy + `0,0` → product ±5% defaults; `thresholdMode: Policy` |
| `_deployOpenModeDetf*` | Open + `0,0` (or custom stored thresholds) |
| Extreme Policy dual-path | Policy + mint=1, burn=max — **not** product Open |
| Legacy ±0.5% Policy | explicit thresholds 1005e15 / 995e15 if a suite still needs that band |
| Always-allow intent | product **Open**, not illegal Policy pairs |

---

## 9. Test map T1–T19 → concrete F5 tests

**New file (recommended):**

`test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ThresholdMode.t.sol`

| ID | Case | Concrete test / home |
|----|------|----------------------|
| **T1** | Policy `0,0` defaults + event | Deploy suite: mode Policy, 1.05/0.95, `ThresholdModeSet` |
| **T2** | Policy custom band | e.g. 1.10/0.90 or legacy 1005e15/995e15 |
| **T3** | Open deploy | Open suite |
| **T4** | Invalid mint ≤ burn | Deploy reverts Policy + Open |
| **T4b** | Extreme Policy 1/max | dual-path; mode Policy |
| **T5** | Live Policy deadband incl. equality | Mint suite with **synthetic** at threshold |
| **T6** | Live Policy mint above | rewrite `_assertMintEnabled` to synthetic regime |
| **T7** | Live Policy burn below | burn path under synthetic |
| **T8** | Inert blocked any mode | pre-init / not initialized |
| **T9** | Real pool trades under default ±5% | drive **synthetic** via underlying/reserve trades (not spot-only) |
| **T9b** | Info match execution | is*Allowed vs execution |
| **T10** | Open live inside deadband | mint+burn with synth in (0.95,1.05) |
| **T11** | Inert + Open blocked | |
| **T12** | Preview == execution when allowed | query + execution |
| **T13** | Open mint fee/seigniorage | |
| **T13b** | Open live info both true | |
| **T14** | No post-deploy setter | |
| **T15** | No route bypass Policy | |
| **T16** | Reentrancy `IsLocked` | adversarial |
| **T17** | Open round-trip | |
| **T18** | Extreme Policy reports Policy | |
| **T19** | Open + non-default stored thresholds | |

### 9.1 Rewrite checklist (spot → synthetic)

- [ ] `_assertMintEnabled` / `_driveToMintEnabled` use synthetic + product thresholds
- [ ] Deploy asserts product defaults **or** explicit custom band
- [ ] IFacet Info test adds `thresholdMode` selector
- [ ] Error expectations use synthetic price in `MintingNotAllowed` / `BurningNotAllowed` payloads
- [ ] Fuzz/adversarial deploys set trailing mode

### 9.2 Production-first rules

- Deploy via manager registry / package path only — **no** `new` DFPkg/facets for SUT.
- **No mocks** of DETF diamond, facets, DFPkg, manager, registry, fee oracle, underlying SE vault.
- Mintable ERC20 funding / reentrancy hostile tokens only as non-SUT harnesses.
- T9: drive synthetic via **real** underlying pool / reserve trades when possible.

---

## 10. Implementation order

1. **Synthetic migration** on all gate + is*Allowed call sites (`_calcSyntheticPrice`); leave mode Policy-only temporarily if needed for green intermediate.
2. Repo storage + `_initialize` mode + thresholds from args.
3. DFPkg `PkgArgs` mint/burn/mode; resolve/validate; emit `ThresholdModeSet`; remove hardcode.
4. Common mode-aware + live-coupled helpers.
5. Info `thresholdMode()` + facet selectors + IFacet tests.
6. FactoryService `buildPkgArgs`.
7. Fix all test PkgArgs / deploy helpers.
8. Rewrite spot-based gate tests to synthetic.
9. Policy regression green under synthetic + defaults.
10. Open suite T1–T19 mapped green.
11. Grep fork/matrix PkgArgs; update.
12. Update PROGRESS F5 implement → done (implement session).

**Suggested implement order vs F4:** implement **F4 first** (already synthetic; lower risk), then F5 (migration risk). Parallel only if human overrides.

---

## 11. Definition of done

- [ ] **Synthetic migration complete:** zero mint/burn gate or `is*Allowed` call sites use `_calcReserveSpotPrice()`
- [ ] Spot helper retained only for non-gate use (or removed if unused)
- [ ] Trailing `thresholdMode` + `mintThreshold` / `burnThreshold` on `PkgArgs`
- [ ] Storage + init resolve/validate; hardcode `1005e15`/`995e15` removed
- [ ] `ThresholdModeSet` once with resolved values
- [ ] Mode-aware lib 3-arg helpers; live in family; Open short-circuit only in lib
- [ ] `thresholdMode()` / live-correct `isMintingAllowed` / `isBurningAllowed`
- [ ] Facet selectors include `thresholdMode`
- [ ] Spot-based gate tests rewritten; Policy + Open suites green
- [ ] T1–T19 mapped or N/A with reason
- [ ] Role names only in new APIs/plan language (no brand-era APIs)
- [ ] Production-first: no SUT mocks
- [ ] Verify:

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv
# plus any fork/matrix paths that construct SingleVaultDetf PkgArgs
```

- [ ] PROGRESS.md F5 implement status updated (implement session)

---

## 12. Out of scope

- Claim redeem / Open interaction redesign
- Bridge / superchain product changes
- Full package brand rename (CHIR defaults in ERC20 name strings — leave unless separate task)
- F4 / F6 NatSpec program / F7 Seigniorage / P7 AGENTS
- Fee-oracle thresholds; asymmetric modes; UI
- Redesigning `_calcSyntheticPrice` math beyond gate migration (unless bond-NFT BPT inclusion required for FD parity — document if changed)

---

## 13. Family PRD conform note (P7)

If a dedicated SingleVaultDetf PRD is maintained, add one-liner: conforms to `DETF_Threshold_Modes_PRD` (Policy/Open + **synthetic** gates). Do not re-open product law. Historical docs that say “gate on reserve spot” are **superseded** by this program.

---

## 14. Risks specific to F5

| Risk | Plan response |
|------|----------------|
| Spot gates vs product law | Mandatory §3.1 migration; DoD forbids spot on gates |
| Synthetic ≠ spot → tests fail | Rewrite drivers/assertions to synthetic |
| Hardcoded ±0.5% thresholds | PkgArgs + product defaults; legacy band only if explicit |
| mint=1/burn=max dual-path | Map always-allow → product Open; extreme Policy stays labeled Policy |
| Brand-era names | Forbidden in new APIs/plan language |
| Scope creep F6/F7 | Explicit non-goals |
| Preview already gates | Keep parity; use synthetic + mode |
