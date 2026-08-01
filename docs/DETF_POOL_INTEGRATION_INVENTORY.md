# DETF ↔ Balancer Pool Integration Inventory

**Purpose:** Cross-reference which Balancer V3 pool types (IndexedEx-built and default Crane/Balancer) are used by which DETF families, so remaining integrations are visible at a glance.

**Date:** 2026-07-28  
**Scope:**
- IndexedEx pools: `contracts/protocols/dexes/balancer/v3/pools/`
- DETF families: `contracts/vaults/detf/**` (+ related seigniorage / dual-liquidity products that hold a Balancer reserve)
- Default Balancer V3 pool factories: Crane port under `lib/crane/contracts/external/balancer/v3/`

**Legend (usage cells):**
| Symbol | Meaning |
|--------|---------|
| **R** | Used as the DETF **reserve pool** (seigniorage / mint-burn pricing surface) |
| **I** | Used as an **intermediate** pool leg (composed routing; not the DETF self-leg reserve itself) |
| **D** | DETF package **deploys** this pool type at instance create |
| **E** | DETF package expects pool(s) **externally supplied** in `PkgArgs` (does not create them) |
| **—** | No integration |
| **(infra)** | Pool is SE/liquidity infrastructure, not a DETF product surface |

---


## 1. Executive summary

### What we have wired today

| DETF / product family | Reserve curve | Factory / pool type | Who creates the pool? |
|----------------------|---------------|---------------------|------------------------|
| **SingleStandardExchangeDETF** (`detf/protocols/dexes/balancer/v3/standardExchange/single/`) | Weighted (2-token; default 80/20) | Crane **`WeightedPoolFactory`** | **D** — DFPkg |
| **MultiVaultWeightedDetf** (`detf/protocols/dexes/balancer/v3/multi-vault-weighted/`) | Weighted (2–8 tokens: DETF + 1..7 SE shares) | Crane **`WeightedPoolFactory`** | **D** — DFPkg |
| **SingleVaultDetf** (removed; was `detf/composed/single/`) | — | — | **Removed** — use Single SE |
| **SeigniorageDETF** (legacy dual-token) | — | — | **REMOVED** |
| **ComposedStableCommonDetf** (`detf/protocols/dexes/balancer/v3/stable/common/`) | Weighted reserve of BPTs + DETF | Crane **`IWeightedPool`** + **`IStablePool`×2** | **E** — all three supplied in `PkgArgs` |
| **MixedBufferMultiVaultStableDetf** (`detf/protocols/dexes/balancer/v3/mixedBuffer/`) | Stable (MixedBuffer) | IndexedEx **`MixedBufferMultiVaultStablePool`** | **D** — via pool DFPkg |
| **DualLiquidityLinkedCrossVersionUniswapVault** (`vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/`) | Weighted (3-token dual SE + pair) | Crane **`WeightedPoolFactory`** | **D** — DFPkg |

### Gap headline

| Category | Count | Notes |
|----------|------:|-------|
| IndexedEx custom pools **with** a DETF consumer | **1** | `MixedBufferMultiVaultStablePool` → MixedBuffer DETF only |
| IndexedEx custom pools **without** a DETF consumer | **6** | Buffer / SE market pools; most explicitly mark DETF out of scope |
| Crane default pool factories **used** by DETFs | **2–3** | `WeightedPoolFactory`, `WeightedPool8020Factory`, `StablePool` (interface; factory external) |
| Crane default pool factories **unused** by DETFs | **5+** | Gyro 2CLP/ECLP, CoW, LBP, StableSurge, (no ReCLAMM port usage) |
| DETFs that **only** use vanilla weighted reserves | **4** | Single SE, MultiVault Weighted, SingleVault, Seigniorage |
| DETF that uses custom stable reserve | **1** | MixedBuffer MultiVault Stable |
| DETF with multi-pool topology (weighted + stables) | **1** | ComposedStableCommon — stable/common legs external |

---

## 2. IndexedEx custom Balancer V3 pools

Path root: `contracts/protocols/dexes/balancer/v3/pools/`

| # | Product | Path | Curve | Token layout (v1) | DFPkg present | DETF consumer | Notes |
|---|---------|------|-------|-------------------|:-------------:|---------------|-------|
| P1 | **StandardExchangeBufferPool** | `constProd/standardExchange/` | Const-prod / 2-token weighted-style buffer | 1 `bufferToken` + 1 SE `vaultShare` | Yes | **None** | Single SE buffer market; virtual buffer + SE pre-seat hooks. **Infra**, not DETF reserve. |
| P2 | **BalancerV3ConstantProductPool** | `constProd/` | Constant product | Generic 2-token | Yes | **None as DETF reserve** | Shared CP / vault-aware facets; TestBases may deploy facets via this FactoryService. |
| P3 | **MultiPairStandardExchangeBufferPool** | `weighted/multiPairBuffer/` | Weighted | Up to 4 `(buffer, share)` pairs (`T=2P`) | Yes | **None** | Multi-pair SE buffer; PRD L10: DETF/bond/claim **out of scope**. |
| P4 | **MixedLegWeightedBufferPool** | `weighted/mixedLegBuffer/` | Weighted | Unpaired `U` + pairs `P`; `2≤U+2P≤8` | Yes | **None** | Unpaired + 1:1 buffered pairs; parallel forever with MultiPair. |
| P5 | **CommonBufferMultiVaultWeightedPool** | `weighted/commonBufferMultiVault/` | Weighted | `U` unpaired + **1** shared buffer + `N` SE shares | Yes | **None** | One-to-many buffer fan-out; PRD L16: DETF **out of scope**. Natural **future** host for a weighted “common-buffer multi-vault DETF” if productized. |
| P6 | **CommonBufferMultiVaultStablePool** (“Stale”) | `stable/commonBufferMultiVault/` | Stable | **1** buffer + `N≤3` SE shares (no unpaired) | Yes | **None** | Like-kind stable buffer; PRD S23: DETF **out of scope**. Sibling of MixedBuffer without free legs. |
| P7 | **MixedBufferMultiVaultStablePool** | `stable/mixedBufferMultiVault/` | Stable | `U≥1` unpaired + **1** buffer + `N≤3` SE shares; `T≤5` | Yes | **MixedBufferMultiVaultStableDetf** (**R+D**) | Designed so unpaired leg can be DETF self-token; DETF DFPkg deploys via `mixedBufferPoolPkg`. |

### IndexedEx pool → DETF matrix

| Pool \ DETF | Single SE DETF | MultiVault Weighted | SingleVault Detf | Composed Stable Common | MixedBuffer Stable DETF | Seigniorage DETF | DualLiquidity |
|-------------|----------------|---------------------|------------------|------------------------|-------------------------|------------------|---------------|
| P1 StandardExchangeBuffer | — | — | — | — | — | — | — |
| P2 ConstantProduct | — | — | — | — | — *(TestBase facet helper only)* | — | — |
| P3 MultiPair Buffer | — | — | — | — | — | — | — |
| P4 MixedLeg Weighted Buffer | — | — | — | — | — | — | — |
| P5 CommonBuffer Weighted | — | — | — | — | — | — | — |
| P6 CommonBuffer Stable (Stale) | — | — | — | — | — | — | — |
| P7 MixedBuffer Stable | — | — | — | — | **R + D** | — | — |

---

## 3. Default Balancer V3 pools (Crane port)

Path root: `lib/crane/contracts/external/balancer/v3/`

| # | Product | Crane path | Factory | Used by DETF(s)? | Role when used |
|---|---------|------------|---------|:----------------:|----------------|
| B1 | **WeightedPool** | `pool-weighted/.../WeightedPool.sol` | **`WeightedPoolFactory`** | **Yes** | Primary **reserve** for Single SE DETF, MultiVault Weighted DETF, DualLiquidity |
| B2 | **WeightedPool 80/20** | `pool-weighted/.../WeightedPool8020Factory.sol` | **`WeightedPool8020Factory`** | **Yes** | **Reserve** for SingleVault Detf + Seigniorage DETF (fixed 80/20 create helper) |
| B3 | **StablePool** | `pool-stable/.../StablePool.sol` | **`StablePoolFactory`** | **Yes (interface)** | ComposedStableCommon: **intermediate** `stablePool` + `commonPool` legs (**E**, not created by DETF DFPkg) |
| B4 | **Gyro 2-CLP** | `pool-gyro/.../Gyro2CLPPool.sol` | `Gyro2CLPPoolFactory` | **No** | — |
| B5 | **Gyro E-CLP** | `pool-gyro/.../GyroECLPPool.sol` | `GyroECLPPoolFactory` | **No** | — |
| B6 | **CoW Pool** | `pool-cow/.../CowPool.sol` | `CowPoolFactory` | **No** | — |
| B7 | **LBPool / LBP** | `pool-weighted/.../lbp/` | LBP factories | **No** | — |
| B8 | **StableSurge** (hook + factory) | `pool-hooks/.../StableSurge*` | `StableSurgePoolFactory` | **No** | Dynamic fee stable variant |
| B9 | Vault buffers / BufferRouter | `vault/.../BufferRouter.sol` | n/a | **Indirect** | ERC-4626 buffer infrastructure for Balancer vault; not a DETF reserve type |

### Crane default pool → DETF matrix

| Pool factory \ DETF | Single SE | MultiVault Weighted | SingleVault | Composed Stable Common | MixedBuffer Stable | Seigniorage | DualLiquidity |
|---------------------|-----------|---------------------|-------------|------------------------|--------------------|-------------|---------------|
| **WeightedPoolFactory** | **R+D** | **R+D** | — | — *(may supply external weighted as R+E)* | — | — | **R+D** |
| **WeightedPool8020Factory** | — | — | **R+D** | — | — | **R+D** | — |
| **StablePoolFactory / IStablePool** | — | — | — | **I+E** (×2 legs under weighted reserve) | — | — | — |
| Gyro 2CLP / ECLP | — | — | — | — | — | — | — |
| CoW Pool | — | — | — | — | — | — | — |
| LBP / LBPool | — | — | — | — | — | — | — |
| StableSurge | — | — | — | — | — | — | — |

---

## 4. DETF family inventory (pool-centric detail)

### F1 — SingleStandardExchangeDETF

| Field | Value |
|-------|-------|
| Path | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` |
| Status | **Shipped** (threshold modes F1 green) |
| Reserve | Balancer V3 **Weighted** (typically 2 tokens: DETF + SE vault share; default weights 80/20 overridable) |
| Factory | `WeightedPoolFactory` (immutable on DFPkg from `PkgInit`) |
| Deploy | DFPkg `_createWeightedReservePool` / create via factory at postDeploy |
| Custom IndexedEx pool | **None** |
| Evidence | `SingleStandardExchangeDETDFPkg.sol`, `TestBase_SingleStandardExchangeDETF.sol`, PRD |

### F2 — MultiVaultWeightedDetf

| Field | Value |
|-------|-------|
| Path | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/` |
| Status | **Implemented** (threshold modes F2 green; PRD header may lag as DRAFT) |
| Reserve | Balancer V3 **Weighted** (DETF + 1..7 SE shares; custom weights sum `1e18`) |
| Factory | `WeightedPoolFactory` |
| Deploy | DFPkg `_createWeightedReservePool` |
| Custom IndexedEx pool | **None** |
| Evidence | `MultiVaultWeightedDetfDFPkg.sol`, `TestBase_MultiVaultWeightedDetf.sol` |

### F3 — MixedBufferMultiVaultStableDetf

| Field | Value |
|-------|-------|
| Path | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/` |
| Status | **Shipped** (threshold modes F3 green) |
| Reserve | IndexedEx **`MixedBufferMultiVaultStablePool`** (StableMath) |
| Layout | DETF unpaired + `bufferToken` + 1..3 SE vault shares |
| Deploy | DFPkg holds `IMixedBufferMultiVaultStablePoolPkg`; `_createMixedBufferReservePool` |
| Evidence | `MixedBufferMultiVaultStableDetfDFPkg.sol`, pool PRD M1–M30, DETF PRD D1–D30 |

### F4 — ComposedStableCommonDetf

| Field | Value |
|-------|-------|
| Path | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/` |
| Status | **Partial / in progress** (mint routing, bond surface, unwind query shipped; full execution checklist still open in PRD) |
| Reserve | **Weighted** pool whose legs include DETF + **stablePool BPT** + **commonPool BPT** |
| Intermediate | Two Balancer **Stable** pools (`stablePool`, `commonPool`) for like-kind vault composition |
| Deploy | **All external**: `PkgArgs` takes `IWeightedPool reservePool`, `IStablePool stablePool`, `IStablePool commonPool` — DFPkg does **not** create pools |
| Custom IndexedEx pool | **None** today (could later swap intermediate stables for CommonBuffer Stable / MixedBuffer) |
| Evidence | `ComposedStableCommonDetfDFPkg.sol` `PkgArgs`, `ComposedStableCommonDetfRepo.sol` |

### F5 — SingleVaultDetf (`composed/single`) — **REMOVED**

| Field | Value |
|-------|-------|
| Path | ~~`contracts/vaults/detf/composed/single/`~~ (removed) |
| Status | **Removed** — use Single SE family (F1) |
| Note | Gold product path is `detf/protocols/dexes/balancer/v3/standardExchange/single/` |

### F6 — SeigniorageDETF (legacy dual-token) — **REMOVED**

| Field | Value |
|-------|-------|
| Path | ~~`contracts/vaults/seigniorage/`~~ |
| Status | **REMOVED** (2026-07-31) — dual-token RBT/sRBT + underwrite NFT product deleted |
| Note | Not a true DETF family. Fee-oracle seigniorage **mint incentive** for true DETFs is unrelated and retained. Do not reintroduce this package. |

### F7 — DualLiquidityLinkedCrossVersionUniswapVault

| Field | Value |
|-------|-------|
| Path | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Status | **Implemented** |
| Product type | Dual-liquidity **Standard Exchange vault** with weighted reserve (DETF-*like*, not generic family DETF) |
| Reserve | **WeightedPoolFactory** 3-token layout (vaultA share, vaultB share, pair vault) |
| Custom IndexedEx pool | **None** |

### Dual / embedded stubs

| Path | Status |
|------|--------|
| ~~`contracts/vaults/detf/dual/`~~ | **Deleted** in directory reorg (empty Dual* commons; no production surface) |

---

## 5. Master cross-reference matrix

Rows = pool types (IndexedEx + Crane defaults).  
Columns = DETF / reserve products.  
Cells: **R** reserve, **I** intermediate, **D** deployed by DETF pkg, **E** external arg, **—** unused.

| Pool type | Single SE DETF | MultiVault Weighted | SingleVault Detf | Composed Stable Common | MixedBuffer Stable DETF | Seigniorage DETF | DualLiquidity |
|-----------|:--------------:|:-------------------:|:----------------:|:----------------------:|:-----------------------:|:----------------:|:-------------:|
| **IndexedEx P1** SE Buffer (constProd) | — | — | — | — | — | — | — |
| **IndexedEx P2** ConstantProduct pkg | — | — | — | — | — | — | — |
| **IndexedEx P3** MultiPair Buffer | — | — | — | — | — | — | — |
| **IndexedEx P4** MixedLeg Buffer | — | — | — | — | — | — | — |
| **IndexedEx P5** CommonBuffer Weighted | — | — | — | — | — | — | — |
| **IndexedEx P6** CommonBuffer Stable | — | — | — | — | — | — | — |
| **IndexedEx P7** MixedBuffer Stable | — | — | — | — | **R+D** | — | — |
| **Crane B1** WeightedPoolFactory | **R+D** | **R+D** | — | **R+E** *(typical)* | — | — | **R+D** |
| **Crane B2** WeightedPool8020Factory | — | — | **R+D** | — | — | **R+D** | — |
| **Crane B3** StablePool | — | — | — | **I+E** | — | — | — |
| **Crane B4–B8** Gyro / CoW / LBP / Surge | — | — | — | — | — | — | — |

---

## 6. Topology sketches (reserve composition)

### Single SE / MultiVault Weighted / DualLiquidity

```text
User / bond paths
        │
        ▼
   DETF diamond  ──seigniorage──►  Balancer WeightedPool (Crane factory)
        │                              legs: DETF + SE share(s) [+ dual pair]
        └── opaque IStandardExchange vaults only
```

### ComposedStableCommonDetf

```text
                    ┌── StablePool (stable leg, external) ──► SE vault shares
User mint routes ──►│
                    └── StablePool (common leg, external) ──► SE vault shares
                              │ BPT                 │ BPT
                              └──────────┬──────────┘
                                         ▼
                              WeightedPool reserve (external)
                              legs: DETF + stableBPT + commonBPT
```

### MixedBufferMultiVaultStableDetf

```text
User mint/burn / bootstrap
        │
        ▼
   DETF diamond  ──seigniorage──►  MixedBufferMultiVaultStablePool (IndexedEx)
                                   legs: DETF (unpaired) + bufferToken + SE shares[1..3]
                                   StableMath + virtual buffer routing
```

---

## 7. Integration gap analysis — what still needs building

Prioritized by product clarity (not implementation cost).

### A. DETF families that exist but do **not** use IndexedEx custom pools

Most “true DETF” work still prices on **vanilla WeightedPool**:

| Opportunity | Motivation | Building block already present? |
|-------------|------------|----------------------------------|
| **CommonBuffer Weighted DETF** | Multi-vault basket with **one shared buffer** + weighted DETF self-leg | Pool P5 exists; **no DETF package** |
| **CommonBuffer Stable (“Stale”) DETF** | Like-kind multi-vault with buffer fan-out, **no** free unpaired leg | Pool P6 exists; **no DETF package** (MixedBuffer covers unpaired case) |
| **MultiPair / MixedLeg as DETF reserve** | Buffered multi-pair markets with DETF self-leg | Pools P3/P4 exist; PRDs currently **exclude** DETF seigniorage — would need product PRD + reserve layout (unpaired DETF leg or BPT-only bond model) |
| **SE Buffer as nested SE only** | Already intended as SE market, not DETF | No DETF work required unless product wants “DETF that *is* a buffer pool” |

### B. ComposedStableCommon — external pool wiring only

| Gap | Detail |
|-----|--------|
| **No package-owned pool create** | Deployer must supply Weighted + 2 Stable instances; no typed factory path like MixedBuffer’s `mixedBufferPoolPkg` |
| **Does not use CommonBuffer Stable/Weighted** | Intermediate stables are plain `IStablePool`; could later standardize on P5/P6 for buffer-aware intermediates |
| **Execution surface incomplete** | PRD checklist still has open top-level unwind/bond polish items |

### C. Crane default pools with **zero** DETF integration

| Pool | Plausible DETF use (product speculation only) | Status |
|------|-----------------------------------------------|--------|
| Gyro 2CLP / ECLP | Concentrated / elliptic reserve for dual-asset DETF | **Not started** |
| CoW Pool | MEV-protected DETF reserve / batch flow | **Not started** |
| LBP | Bootstrap / distribution DETF (usually not seigniorage) | **Not started** |
| StableSurge | Like-kind reserve with surge fees | **Not started** |

### D. Redundant / consolidation candidates (not “missing,” but matrix noise)

| Pair | Observation |
|------|-------------|
| SingleVaultDetf vs SingleStandardExchangeDETF | Both single-SE seigniorage; differ mainly by **8020 factory** vs **general WeightedPoolFactory** + generalized SE attachment matrix |
| SeigniorageDETF vs Single* families | **REMOVED** — legacy dual-token product no longer in tree |

### E. Explicit non-goals already locked on pool PRDs

These pools intentionally do **not** implement DETF surfaces (bond NFT, claim, seigniorage). A future DETF would **consume** them as `reservePool`, not extend the pool package:

- MultiPair Buffer (L10)
- CommonBuffer Weighted (L16)
- CommonBuffer Stable (S23)
- MixedBuffer Stable (M23 — pool logic only; DETF is a **separate** package that already consumes it)

---

## 8. Suggested build order (integration only)

Derived from the matrix; product priority may override.

1. **Done:** Weighted reserve DETFs (Single SE, MultiVault Weighted) + MixedBuffer Stable DETF.  
2. **Finish:** ComposedStableCommon — complete execution surface; optionally add package-owned Stable/Weighted deploy helpers so args are not fully external.  
3. **Highest empty custom-pool × DETF cell:** **CommonBuffer Weighted DETF** (P5 + new DETF family) if multi-vault *weighted* buffer products are desired.  
4. **Sibling of MixedBuffer:** **Stale / CommonBuffer Stable DETF** only if unpaired-less layout is a first-class product (today MixedBuffer covers DETF self-leg case).  
5. **Buffer pools as SE markets only:** keep MultiPair / MixedLeg / single SE Buffer without DETF unless a PRD revises L10/out-of-scope rules.  
6. **Crane exotic curves (Gyro/CoW/Surge):** greenfield DETF families; no IndexedEx pool work required first — only factory wiring + quote math.

---

## 9. Source map (quick links)

### DETF packages

| Family | DFPkg | TestBase / law |
|--------|-------|----------------|
| Single SE | `.../balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol` | `TestBase_*`; AGENTS + `docs/detf/` |
| MultiVault Weighted | `.../balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol` | `TestBase_*`; AGENTS + `docs/detf/` |
| MixedBuffer Stable | `.../balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol` | `TestBase_*`; AGENTS + `docs/detf/` |
| Composed Stable Common | `.../balancer/v3/stable/common/ComposedStableCommonDetfDFPkg.sol` | `TestBase_*`; AGENTS + `docs/detf/` |
| Single Vault (8020) | removed | — |
| Seigniorage (legacy) | **REMOVED** | — |
| DualLiquidity | `.../uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol` | family docs under protocol tree |

### IndexedEx pools

| Product | Package |
|---------|---------|
| SE Buffer | `.../constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol` |
| Constant product | `.../constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol` |
| MultiPair | `.../weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol` |
| MixedLeg | `.../weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol` |
| CommonBuffer Weighted | `.../weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol` |
| CommonBuffer Stable | `.../stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol` |
| MixedBuffer Stable | `.../stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol` |

### Crane default factories

| Factory | Path |
|---------|------|
| WeightedPoolFactory | `lib/crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol` |
| WeightedPool8020Factory | `lib/crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol` |
| StablePoolFactory | `lib/crane/contracts/external/balancer/v3/pool-stable/contracts/StablePoolFactory.sol` |
| Gyro / CoW / hooks | `lib/crane/contracts/external/balancer/v3/pool-gyro/`, `pool-cow/`, `pool-hooks/` |

---

## 10. Change log

| Date | Note |
|------|------|
| 2026-07-28 | Initial inventory from on-disk packages, DFPkg imports, and family PRDs. One IndexedEx custom pool wired as DETF reserve (`MixedBufferMultiVaultStablePool`). All other DETF reserves are Crane Weighted (general or 8020); ComposedStableCommon also consumes external Stable pools as intermediate legs. |

---

*This file is an inventory report, not a PRD. Family and pool PRDs remain normative for product law. Update this matrix when a DFPkg gains or drops a pool factory dependency.*
