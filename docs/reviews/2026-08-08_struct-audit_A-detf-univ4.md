# Struct + Audit Readiness Review — A-detf-univ4

- **Date:** 2026-08-08
- **Agent/role:** area subagent (pilot) — A-detf-univ4
- **Scope paths:** `contracts/vaults/detf/protocols/dexes/uniswap/**` only
- **Out of scope notes:** Hook implementations under `contracts/hooks/**` (cited only as reserve/LP ABI consumers); shared `contracts/vaults/detf/common/**` types (e.g. `DETFUsageFeeLib`, bond lifecycle) as references only; `test/**`, `lib/**`, frontend
- **Status:** COMPLETE
- **Commands / tools used:**
  - `rg -n --glob '*.sol' 'struct\s+\w+' contracts/vaults/detf/protocols/dexes/uniswap`
  - Targeted reads of orbital / weighted / CP-single / legacy-single Targets, Repos, DFPkgs, common, interfaces, PRD burn-fee notes
  - `rg` for member reads (`pairNotionalWad`, `grossDetf`, burn usage fee, `claimRewards`)
  - PRD: `docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md` §§2–3, 6–7 (+ score context §8)

---

## 1. Executive summary

### Top 5 opportunities

1. **C3 — Share `MintSplit` (4 copies)** across orbital / weighted / CP-single / legacy-single Commons — identical 4×`uint256` layout; bytecode + audit clarity win.
2. **C5 — Drop dead `PairLegRating.pairNotionalWad`** (orbital + weighted): written on every mint/bond settle path, **never read**.
3. **C5 — Drop dead `MintSplit.grossDetf`** (all families): assigned, never consumed (callers already hold `gross_`).
4. **C3 — Align residual bags** (`BurnExecResidual` / `ClaimResidual` / 3-leg `BindingAmounts`) via a tiny shared naming/layout doc or library type **without** forcing one mega-context (stack-critical).
5. **C6 (pre-launch) — Repo `Storage` packing** of `bool` + binding `uint8`s next to addresses (orbital/weighted/CP) — SLOAD density on hot paths; label **storage migration risk**.

### Top 5 audit concerns

1. **CP-single burn omits usage fee** while PRD says “usage fee on burn if peer path does” and orbital/weighted implement `_takeBurnUsageFee` — economic asymmetry / fee leak to burner.
2. **`claimRewards` soft-fails** (non-holder → `return 0`; CP also `try/catch` may return `pendingRewards` without transfer) — access/observability.
3. **Internal hook legs use `minOut=0` + `block.timestamp + 1`** on add/remove/deposit/sphere while outer `minOut` is enforced only after consolidation — intermediate residual risk (mitigated by `nonReentrant`, still auditor-sensitive).
4. **Orbital `previewExchangeIn` returns `0` for SE↔SE passthrough** that `exchangeIn` executes — preview/execute asymmetry.
5. **Dual product trees** (`standardExchange/single` listing-era vs `constantProduct/single` buffer-era) share names/structs → integrator and audit navigation risk.

### Struct counts

| Metric | Count |
|--------|------:|
| Defined under allowlist | **52** |
| Recommended remove (members or whole dead fields) | **2 member types** (`pairNotionalWad`, `grossDetf`) + optional C5 residual merge |
| Recommended merge / share (C1–C3) | **~4 themes** (MintSplit, PairLegRating layout, residual naming, Core/Policy init pattern doc) |
| Do-not-collapse | **~12** (see §5) |

---

## 2. Struct inventory

| Name (file :: struct) | Kind | Visibility | Approx members | Write sites | Read sites | Lifetime | Notes |
|----------------------|------|------------|----------------|-------------|------------|----------|-------|
| `…/orbital/…Common.sol` :: `MintSplit` | result | internal-only | 4×`uint256` | `_splitMintedDetf` | mint/bond free legs, preview | call | **×4 family clone** |
| `…/orbital/…Common.sol` :: `PairLegRating` | stack-relief / result | internal | `uint8` + 2×`uint256` | `_rateTokenInToPairLeg`, `_settleToPairLeg` | mint/bond quotes | call | `pairNotionalWad` **dead** |
| `…/orbital/…Common.sol` :: `BindingAmounts` | stack-relief | internal | 3×`uint256` a0–a2 | `_packBinding` | add/remove/redeposit | call | Binding-order domain |
| `…/orbital/…ExchangeOutTarget.sol` :: `BurnExecResidual` | stack-relief | internal | aDetf,a0,a1 | `_burnAndRemoveProtocolLp` | `_settleBurnResidual` | call | Hot burn path |
| `…/orbital/…ExchangeOutTarget.sol` :: `BurnPreviewResidual` | stack-relief | internal | hook,p0,p1,lpOut,ap0,ap1 | `_loadBurnPreviewResidual` | preview consolidate | call | Preview-only |
| `…/orbital/…BondingTarget.sol` :: `ClaimResidual` | stack-relief | internal | a0,a1 | `_removeAndRedepositClaimLp` | `_settleClaimResidual` | call | Claim path (post-redeposit) |
| `…/orbital/…BurnPreviewLib.sol` :: `PostRemoveBook` | execution-context | library | 9 fields | `_loadPostRemoveBook` | sphere preview | call | **Stack-critical external lib** |
| `…/orbital/…BurnPreviewLib.sol` :: `MappedLegs` | stack-relief | library | 7 fields | `_mapLegs` | sphere math | call | Keep |
| `…/orbital/…BurnPreviewLib.sol` :: `SphereWad` | stack-relief | library | 5×`uint256` | `_sphereWad` | `sphereExactInOutWad` | call | Keep |
| `…/orbital/…Repo.sol` :: `CapitalMeta` | storage (mapping value) | library | enum+2 addr | `_setCapital` | closeBondMature | permanent | Per-tokenId |
| `…/orbital/…Repo.sol` :: `Storage` | storage | library | ~25 fields + mapping | init / runtime | all Targets | permanent | Diamond slot |
| `…/orbital/…Repo.sol` :: `CoreInit` | api (internal init) | library | ~20 | DFPkg postDeploy | `_initializeCore` | deploy | |
| `…/orbital/…Repo.sol` :: `PolicyInit` | api (internal init) | library | 6 | DFPkg | `_initializePolicy` | deploy | Shared pattern |
| `…/orbital/…DETDFPkg.sol` :: `DeployConfig` | other (transient storage) | contract | Core+policy+nonce | `processArgs` | hook/vault deploy | deploy-tx | Transient package slot |
| `…/orbital/interfaces/…` :: `PkgInit` | api | interface / public ABI | facets+pkgs | factory | constructor | deploy | **On interface ✓** |
| `…/orbital/interfaces/…` :: `PkgArgs` | api | interface | product args | deployVault | processArgs | deploy | **On interface ✓** |
| `…/weighted/…Common.sol` :: `MintSplit` | result | internal | 4×`uint256` | same pattern | mint/bond | call | Clone of orbital |
| `…/weighted/…Common.sol` :: `PairLegRating` | stack-relief | internal | `fundedProductIndex`+2×`uint256` | settle/rate | mint/bond | call | `pairNotionalWad` dead |
| `…/weighted/…ExchangeOutTarget.sol` :: `BurnExecResidual` | stack-relief | internal | aDetf + `uint256[]` | burn remove | settle | call | m-leg residual |
| `…/weighted/…Repo.sol` :: `Storage` | storage | library | fixed arrays MAX_N/M | init | all | permanent | No rateAsset (by design) |
| `…/weighted/…Repo.sol` :: `CoreInit` | api/init | library | dynamic arrays | DFPkg | init | deploy | |
| `…/weighted/…Repo.sol` :: `PolicyInit` | api/init | library | 6 | DFPkg | init | deploy | Same layout as orbital/CP |
| `…/weighted/…DETDFPkg.sol` :: `DeployConfig` | other/transient | contract | fixed arrays | processArgs | deploy | deploy-tx | |
| `…/weighted/interfaces/…` :: `PkgInit` | api | interface | facets+pkgs | factory | ctor | deploy | **On interface ✓** |
| `…/weighted/interfaces/…` :: `PkgArgs` | api | interface | m-leg arrays | deploy | processArgs | deploy | **On interface ✓** |
| `…/constantProduct/single/…Common.sol` :: `MintSplit` | result | internal | 4×`uint256` | split | mint/bond | call | Clone |
| `…/constantProduct/single/…Repo.sol` :: `Storage` | storage | library | ~18 | init | all | permanent | Single pairToken |
| `…/constantProduct/single/…Repo.sol` :: `CoreInit` | api/init | library | ~11 | DFPkg | init | deploy | |
| `…/constantProduct/single/…Repo.sol` :: `PolicyInit` | api/init | library | 6 | DFPkg | init | deploy | |
| `…/constantProduct/single/…DETDFPkg.sol` :: `DeployConfig` | other/transient | contract | ~11 | processArgs | deploy | deploy-tx | |
| `…/constantProduct/single/interfaces/…` :: `PkgInit` | api | interface | facets+pkgs | factory | ctor | deploy | **On interface ✓** |
| `…/constantProduct/single/interfaces/…` :: `PkgArgs` | api | interface | SE+pair+policy | deploy | processArgs | deploy | **On interface ✓** |
| `…/standardExchange/single/…Common.sol` :: `MintSplit` | result | internal | 4×`uint256` | split | mint/bond | call | **Legacy tree clone** |
| `…/standardExchange/single/…Repo.sol` :: `Storage` | storage | library | poolKey+listing fields | init | Targets | permanent | Listing-era product |
| `…/standardExchange/single/…Repo.sol` :: `InitParams` | api/init | library | flat all-in-one | DFPkg | `_initialize` | deploy | Pre-Core/Policy split |
| `…/standardExchange/single/…DFPkg.sol` :: `PkgInit` | api | **interface + used by contract** | facets+pkgs | factory | ctor | deploy | On `I…DFPkg` ✓ |
| `…/standardExchange/single/…DFPkg.sol` :: `PkgArgs` | api | interface | listing params | deploy | processArgs | deploy | Different expansion model |
| `…/standardExchange/single/…DFPkg.sol` :: `DeployConfig` | other/transient | contract | mirrors PkgArgs body | processArgs | deploy | deploy-tx | |
| `…/common/rebasing/…Repo.sol` :: `Storage` | storage | library | pool+pair+detf+owner | init | claim diamond | permanent | Slot **unmasked** keccak |
| `…/common/rebasing/…Common.sol` :: `OperationParams` | stack-relief | internal | op enum + ticks + liq | unlock callback | PM callback | call | |
| `…/common/rebasing/…Common.sol` :: `ManagedTicks` | result | internal | 6×`int24` | tick plan | LP ops | call | Domain-specific |
| `…/common/rebasing/…Common.sol` :: `ManagedLiquidityPlan` | result | internal | 3×liq + 2 amounts | plan | execute | call | |
| `…/common/rebasing/…Common.sol` :: `ManagedLiquidityBudgets` | result | internal | 4×budget | budget | plan | call | |
| `…/common/rebasing/…DFPkg.sol` :: `PkgInit` | api | interface | facets | factory | ctor | deploy | **On interface ✓** |
| `…/common/rebasing/…DFPkg.sol` :: `PkgArgs` | api | interface | pool/owner | deployClaim | process | deploy | |
| `…/common/nft/…Repo.sol` :: `BondPosition` | storage | library | ticks+shares+unlock | open bond | rewards/mature | permanent | |
| `…/common/nft/…Repo.sol` :: `Storage` | storage | library | pool+ledger+mappings | init | NFT diamond | permanent | Slot unmasked |
| `…/common/nft/…Common.sol` :: `OperationParams` | stack-relief | internal | op+ticks+liq | callback | PM | call | Similar name ≠ rebasing |
| `…/common/nft/…DFPkg.sol` :: `PkgInit` | api | interface | facet+factory | factory | ctor | deploy | **On interface ✓** |
| `…/common/nft/…DFPkg.sol` :: `PkgArgs` | api | interface | detf/pool | deployBondNft | process | deploy | |
| `…/common/UniV4DetfListingOracleLib.sol` :: `Observation` | storage | library | ts+cum+init | poke | TWAP | permanent | Listing oracle ring |
| `…/common/UniV4DetfListingOracleLib.sol` :: `Storage` | storage | library | ring meta | init/poke | quote | permanent | Used by **legacy** listing DETF |

**PkgInit/PkgArgs placement:** Modern families (orbital, weighted, CP-single) define them on **interfaces**. Legacy single defines them on `IUniswapV4SingleStandardExchangeDETFDFPkg` (same file as contract but interface-owned). Common rebasing/NFT DFPkgs: on interfaces. **No flag** for “contract-only” PkgInit in this area.

---

## 3. Redundant members

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-univ4-001 | Medium | struct-redundant | `PairLegRating.pairNotionalWad` never read | `…/orbital/…Common.sol:68-72,439-469,786-801`; weighted same pattern `…/weighted/…Common.sol:67-71,450-463,860-869`; **no `.pairNotionalWad` reads** under allowlist | Extra `_toWad` + MSTORE on every mint/bond settle | Remove field; compute WAD only if a future path needs it | positive | low | No (internal) | medium | Yes (impl phase) |
| S-A-detf-univ4-002 | Low | struct-redundant | `MintSplit.grossDetf` write-only | `…/orbital/…Common.sol:61-66,422-429`; consumers use only `userDetf`/`feeToDetf`/`inventoryDetf` (`…ExchangeInTarget.sol:115-121`) | One wasted store per mint/bond free-leg split | Drop member; keep 3-field split | positive | low | No | medium | Yes |
| S-A-detf-univ4-003 | Low | struct-redundant | `BurnPreviewResidual` duplicates addresses available from `Repo.Storage` | `…/orbital/…ExchangeOutTarget.sol:175-230` | Extra memory on view path only | Optional shrink to `lpOut,ap0,ap1` + load p0/p1 from storage when needed | neutral | med | No | low | No |
| S-A-detf-univ4-004 | Nit | struct-redundant | `SphereWad.R` copies `PostRemoveBook.R` | `…BurnPreviewLib.sol:21-50,136-145` | Clarity only; stack packing | Keep — stack-relief intentional | neutral | high if flattened | No | medium | No |
| S-A-detf-univ4-005 | Medium | struct-collapse | Quadruple `MintSplit` clone | orbital/weighted/CP/legacy Commons each define identical layout | Bytecode + audit drift risk | Shared library type (C3) | positive (bytecode) | low | No | medium | Yes (shared lib first) |
| S-A-detf-univ4-006 | Low | struct-collapse | Dual `PairLegRating` (orbital vs weighted) | orbital `fundedPairLeg` vs weighted `fundedProductIndex` | Naming tax for auditors | Shared type with product-index field name | neutral | low | No | medium | Later |
| S-A-detf-univ4-007 | Low | struct-collapse | Triple residual bags (BurnExec / Claim / Binding) | Orbital burn `32-36`, claim `356-359`, binding `74-78` | Cognitive load; similar 2–3 uint bags | Shared **names** (`PairResidual {a0,a1}`) only where shapes match; keep `aDetf` separate where needed | unknown | med | No | low | Later |
| S-A-detf-univ4-008 | Nit | struct-redundant | PolicyInit identical across orbital/weighted/CP Repos | e.g. orbital `105-112`, CP `72-78`, weighted `98-105` | Maintenance only | Optional shared `DETFPolicyInit` in common (out-of-area for implementation) | neutral | low | No | high | Later |

---

## 4. Collapse / consolidation proposals

### Class map

| Class | Proposal summary |
|-------|------------------|
| **C3** | Shared `MintSplit` library used by all Uni V4 SE DETF Commons |
| **C5** | Remove dead `pairNotionalWad` / `grossDetf` members |
| **C3** | Shared residual / pair-leg naming (optional, careful) |
| **C1** | Document DeployConfig ⊇ CoreInit+PolicyInit (no forced merge) |
| **C6** | Storage packing for live flags + binding indices |
| **C2** | Do **not** merge BurnPreviewLib nested graph into one mega-context |
| **C4** | Optional shrink of view-only `BurnPreviewResidual` |

### Findings table (every S-* with required gas/stack/ABI fields)

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-univ4-010 | Medium | struct-collapse | **C3** Shared `MintSplit` | 4 definitions: orbital `61-66`, weighted `60-65`, CP `49-54`, legacy `49`+ | Hot-path mint/bond; less bytecode; one NatSpec | Add `contracts/vaults/detf/common/...` type (impl out-of-area); replace local structs | positive | low | No | medium | Yes |
| S-A-detf-univ4-011 | Medium | struct-collapse / gas | **C5** Remove `pairNotionalWad` | orbital Common `68-72` writes only; no reads | Hot mint/bond: fewer MSTORE/`_toWad` | Delete member + assignments | positive | low | No | medium | Yes |
| S-A-detf-univ4-012 | Low | struct-collapse / gas | **C5** Remove `grossDetf` from MintSplit | Common `_splitMintedDetf` sets only | Micro gas + clearer result type | 3-field MintSplit | positive | low | No | medium | Yes |
| S-A-detf-univ4-013 | Low | struct-collapse | **C3** Shared orbital residual type for burn/claim pairs | `BurnExecResidual` `32-36` vs `ClaimResidual` `356-359` | Clarity; claim drops aDetf after redeposit | `struct PairResidual {uint256 a0; uint256 a1;}` + keep aDetf as local or separate | neutral | med | No | low | No |
| S-A-detf-univ4-014 | Nit | struct-collapse | **C1** DeployConfig vs CoreInit+PolicyInit | orbital DeployConfig `60-82` vs CoreInit `81-103` + PolicyInit `105-112` | Deploy-only; large overlap | Keep DeployConfig as package-local transient; document mapping in NatSpec — **do not** unify Storage init API | neutral | n/a | No | high | No |
| S-A-detf-univ4-015 | Medium | struct-split / gas | **C6** Pack orbital Storage flags | `Storage` `47-79`: `bool isReserveLive` then many addresses then `uint8` binding indices | Fewer SLOADs if packed carefully | Pre-launch pack `bool`+`uint8×3` into one slot; **tests required**; label migration risk | positive | low | **Yes — storage layout** (pre-launch allowed) | low | Later + tests |
| S-A-detf-univ4-016 | Low | struct-split | **C6** CP-single / weighted Storage packing | CP Storage `34-55`; weighted `45-76` | Same packing theme | Same as above | positive | low | Yes — storage | low | Later |
| S-A-detf-univ4-017 | Nit | struct-collapse | **C3** Legacy `InitParams` vs Core/Policy split | legacy Repo `62-82` | Consistency with modern families | Only if legacy product kept; else archive path | neutral | low | No | medium | Product decision |
| S-A-detf-univ4-018 | Low | struct-collapse | **C3** Dual `OperationParams` (NFT vs claim) | nft Common `36-42` vs rebasing `46-54` | Name collision across packages | Rename to `BondNftOpParams` / `ClaimOpParams` (clarity, not merge) | neutral | low | No | high | Nit |
| S-A-detf-univ4-019 | Medium | gas / do-not | **Anti-C2** BurnPreviewLib nested structs | `PostRemoveBook`/`MappedLegs`/`SphereWad` `21-50` | Collapsing likely reintroduces stack-too-deep | Keep; external lib already is stack/EIP-170 strategy | neutral / negative if merged | **high** | No | medium | No |
| S-A-detf-univ4-020 | Low | struct-collapse | Weighted `BurnExecResidual` uses dynamic array | weighted ExchangeOut `28-31` | Alloc cost on burn | Keep — m∈[1,7] variable; fixed MAX_M array only if measured better | unknown | med | No | low | Measure first |

### Sketches (selected)

**C3 MintSplit (after):**
```text
// shared
struct MintSplit { uint256 userDetf; uint256 feeToDetf; uint256 inventoryDetf; }
// or keep gross only if external debugging requires — currently unused
```

**C5 PairLegRating (after):**
```text
struct PairLegRating {
  uint8 fundedPairLeg; // or fundedProductIndex
  uint256 pairNotionalNative;
}
```

**C6 orbital Storage packing (illustrative — needs layout tests):**
```text
// before: bool slot; ... addresses ...; uint8×3 each may pad
// after: pack isReserveLive + detfBindingIndex + pair0BindingIndex + pair1BindingIndex
// in one word; remaining addresses unchanged order carefully with storage tests
```

---

## 5. Do-not-collapse list

| Struct | Reason |
|--------|--------|
| `I*DETDFPkg.PkgInit` / `PkgArgs` (all families) | Public deploy ABI; Crane interface rule; integrator surface |
| `Repo.Storage` (semantic field set) | Permanent diamond storage; packing OK later, **not** semantic merge with DeployConfig |
| `CapitalMeta` | Per-bond capital mode domain; distinct from residual bags |
| `BindingAmounts` | Binding-order packing for 3-leg hook; must not flatten into product-order residual |
| `PostRemoveBook` / `MappedLegs` / `SphereWad` | Stack-critical external library for burn preview post-remove book |
| `BurnExecResidual` (as a concept) | Stack-relief on burn multipath; splitting helpers already applied |
| `ManagedTicks` / `ManagedLiquidityPlan` / `ManagedLiquidityBudgets` | Distinct LP planning stages; merge hurts audit clarity |
| `BondPosition` | Storage position ledger; not a scratch bag |
| `Observation` + listing-oracle `Storage` | Ring buffer layout fixed; separate product concern |
| `DeployConfig` (package transient) | Deploy-tx scratch in package slot; collapsing into `PkgArgs` would confuse call-time vs process-time state |
| Weighted `BurnExecResidual.pairAmts[]` | Variable m legs — not the same as orbital 2-pair residual |
| Legacy listing `InitParams`/`Storage` vs CP buffer | Different product economics; do not force one type |

---

## 6. Gas notes

### Hot paths in this area

| Path | Primary files | Structs on path |
|------|---------------|-----------------|
| Mint (`exchangeIn` → DETF) | orbital/weighted/CP `ExchangeInTarget` + Common | `PairLegRating`, `MintSplit` |
| Burn (DETF → pair/share) | `ExchangeOutTarget` | `BurnExecResidual`, (orbital) `BurnPreviewResidual` + BurnPreviewLib |
| Bond open | `BondingTarget` | `PairLegRating`, `MintSplit`, `CapitalMeta` |
| Redeem claim | `BondingTarget.redeemClaim` | `ClaimResidual` |
| Close mature / sell | `BondingTarget` | residual locals / CapitalMeta |
| Compound | Common `compoundProtocolRewardsAtomic` | mostly storage + locals |
| Deploy | `*DETDFPkg` | `DeployConfig`, `PkgArgs`, Core/Policy init |

### Hermetic measurement ideas (no forged %)

```bash
# Baseline (default profile — no FOUNDRY_PROFILE=fork unless path needs it)
forge snapshot --match-contract TestBase_UniswapV4StandardExchangeOrbitalDETF
forge snapshot --match-contract TestBase_UniswapV4SingleStandardExchangeDETF
forge snapshot --match-contract TestBase_UniswapV4StandardExchangeWeightedDETF

# Targeted hot-path names (adjust to actual test names after listing):
forge test --match-contract TestBase_UniswapV4StandardExchangeOrbitalDETF --match-test 'test_.*[Mm]int|test_.*[Bb]urn|test_.*[Bb]ond|test_.*[Cc]laim' --gas-report
forge test --match-contract TestBase_UniswapV4SingleStandardExchangeDETF --match-test 'test_.*[Bb]urn|test_.*[Mm]int' --gas-report
```

**Shortlist for implementer gas before/after:**

1. Orbital mint after removing `pairNotionalWad` stores  
2. Orbital/CP mint after shared/stripped `MintSplit`  
3. Orbital burn residual path (do **not** expect win from merging BurnPreviewLib)  
4. Storage packing only with hermetic lifecycle suite green  

**Fork-only note:** Any path that requires live Uni V4 PM + real SE liquidity beyond hermetic TestBase fixtures should use `FOUNDRY_PROFILE=fork` only when hermetic cannot exercise it; prefer extending hermetic TestBases first.

---

## 7. Audit readiness findings

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| A-A-detf-univ4-001 | **High** | economic | CP-single burn skips usage fee | CP `…ExchangeOutTarget.sol:50-63` burns full `detfIn_`; orbital `59-76` / weighted `55-67` take fee; CP PRD: “Usage fee on burn if peer path does” (`…_PRD.md` ~L369) | Burners get larger LP share / residual vs peer DETFs; feeTo underpaid | Port `_takeBurnUsageFee` + preview fee split to CP-single; hermetic fee tests | n/a | n/a | No | high | **Yes** |
| A-A-detf-univ4-002 | Medium | access | `claimRewards` non-holder soft-returns 0 | orbital `332-348`; weighted ~`374-387`; CP `223-249` | Silent no-op vs custom error; harder integrators/audits | Prefer `NotBondHolder` / `NotAuthorized` revert (or document permissionless expand-only API explicitly) | n/a | n/a | Possible ABI semantics | high | Yes |
| A-A-detf-univ4-003 | Medium | economic / quality | CP `claimRewards` catch returns `pendingRewards` without transfer | CP BondingTarget `244-248` | Caller may assume rewards paid when NFT claim failed | Revert on failure or return 0; never report unpaid pending as success amount | n/a | n/a | No | high | **Yes** |
| A-A-detf-univ4-004 | Medium | economic | Orbital preview vs execute: SE passthrough | `ExchangeInTarget.sol:46-49` executes; `previewExchangeIn` `145` returns `0` for non mint/burn | UI/router minOut wrong for SE↔SE | Preview SE path via `standardExchange*.previewExchangeIn` when allowlisted | n/a | n/a | No | high | Yes |
| A-A-detf-univ4-005 | Medium | economic | Intermediate hook ops use `minAmountOut=0` | Common `_sphereExactIn` `560-568`, `_depositSingle` `586-588`, `_addLiquidity` `602-604`, `_removeLiquidity` `613-614` | Residual legs unprotected until outer minOut; multi-step MEV/ordering risk | Document intentional CEI + outer minOut; consider propagating minOut to final transfer only (current) vs intermediate — product freeze | n/a | n/a | No | medium | Document / product |
| A-A-detf-univ4-006 | Low | reentrancy | Money paths use `nonReentrant` | exchangeIn/bond/claim/sell/close entrypoints | Good baseline | Keep; ensure no unprotected external entry on facets | n/a | n/a | No | high | No |
| A-A-detf-univ4-007 | Medium | economic | Mature close dust co-join (0.1% / min 1) | orbital BondingTarget `298-310` | User residual reduced for redeposit success when book MIN-only | NatSpec + tests for max dust; cap already present | n/a | n/a | No | high | Document/tests |
| A-A-detf-univ4-008 | Medium | test-gap / quality | Dual product trees same brand | `standardExchange/single/**` vs `constantProduct/single/**` | Wrong suite/ABI reviewed at audit | Mark legacy tree archived or rename packages; inventory in audit brief | n/a | n/a | No | high | Process |
| A-A-detf-univ4-009 | Low | storage | Unmasked storage slots (NFT/claim/legacy/oracle) | e.g. rebasing Repo `18-19`; bond nft `19`; listing oracle `35-36` vs ERC7201-style masked slots on modern DETF repos | Collision risk if diamond also stores other unmasked hashes | Align to ERC7201-style slots **pre-launch** with migration tests | n/a | n/a | **Yes — storage** | medium | Pre-launch batch |
| A-A-detf-univ4-010 | Low | naming | Weighted `isAllLegsMintRich` “rich” wording | interface ~L60; Common ~347 | Mild brand/richness language (not RICH product brand) | Acceptable product language; optional rename to `isAllLegsMintEligible` for law purity | n/a | n/a | Possible ABI | medium | Nit |
| A-A-detf-univ4-011 | Medium | tokens / economic | Burn fee path: fee DETF transferred not burned (orbital) | orbital `_takeBurnUsageFee` transfers fee to feeTo then burns principal only | Correct if product is “usage fee DETF to feeTo”; confirm vs mint mint-to-feeTo | Align NatSpec with fee oracle docs; tests for supply decrease vs transfer | n/a | n/a | No | medium | Tests |
| A-A-detf-univ4-012 | Low | access | `claimLiquidity` gated to bond/claim/self | orbital `430-435` | Good | Keep; add adversarial tests for random caller | n/a | n/a | No | high | Tests |
| A-A-detf-univ4-013 | Low | dead code / quality | Deadline param discarded on burn internal | `_burnDetfExactIn(..., uint256 /* deadline_ */)` orbital ExchangeOut `46` | Deadline checked at outer `exchangeIn` only — OK if always routed | Document; never expose burn without outer check | n/a | n/a | No | high | Nit |
| A-A-detf-univ4-014 | Medium | economic | Primary mint does not realize expansion | ExchangeIn comments + Common | Debt-inclusive burn vs mint asymmetry intentional | Ensure tests encode “mint no expand / bond expands” freeze | n/a | n/a | No | high | Tests |
| A-A-detf-univ4-015 | Low | deploy | Registry path used for vault DFPkgs | `deployVault` → `VAULT_REGISTRY_DEPLOYMENT.deployVault` orbital DFPkg `131-133` | Matches Crane/IndexedEx deploy law | Keep; never bypass for registered packages | n/a | n/a | No | high | No |

---

## 8. Suggested implementation order (for later plan)

1. **Correctness first (audit High/Medium money):**  
   - A-A-detf-univ4-001 CP burn usage fee + previews/tests  
   - A-A-detf-univ4-003 CP claimRewards return semantics  
   - A-A-detf-univ4-002 claimRewards auth errors (all families)  
   - A-A-detf-univ4-004 orbital SE passthrough preview  
2. **Low-risk struct gas (no storage/ABI):**  
   - S-A-detf-univ4-011 / 001 remove `pairNotionalWad`  
   - S-A-detf-univ4-012 / 002 remove `grossDetf`  
   - Hermetic snapshot mint/bond  
3. **Shared `MintSplit` library (C3)** — S-A-detf-univ4-010 (touches `detf/common` out-of-area: coordinate with A-detf-core)  
4. **Docs / process:** dual-tree status, intermediate minOut policy, mature dust NatSpec  
5. **Pre-launch storage packing (C6)** — S-A-detf-univ4-015/016 + slot masking A-A-detf-univ4-009 with layout tests  
6. **Optional residual naming cleanup** — only if stack stays green  
7. **Never:** merge BurnPreviewLib structs; never enable `via_ir`

---

## 9. Open questions

1. Is the **legacy listing DETF** (`standardExchange/single/**`) still a launch candidate, or archive-only? Collapse recommendations diverge.  
2. Should **burn usage fee** always transfer DETF to feeTo (orbital/weighted) rather than burn fee portion? Confirm fee-oracle product law once for all Uni V4 families.  
3. Is silent `claimRewards → 0` for non-holders intentional permissionless expansion touch, or a historical soft gate?  
4. Weighted residual `uint256[]` vs fixed `uint256[MAX_M]` — worth measuring gas?  
5. Cross-area: should shared `MintSplit` / `PolicyInit` live under `contracts/vaults/detf/common/**` (A-detf-core owns landing zone)?  
6. Orbital burn preview library comments mention “via-IR tag space” historically — confirm CI still forbids `via_ir` (repo law: yes); no action beyond not reintroducing IR dependency.

---

**Done criteria:** COMPLETE — inventory of 52 structs, workstreams §§2–7 done, IDs `S-A-detf-univ4-*` / `A-A-detf-univ4-*`, no product edits, no `via_ir` recommendations.
