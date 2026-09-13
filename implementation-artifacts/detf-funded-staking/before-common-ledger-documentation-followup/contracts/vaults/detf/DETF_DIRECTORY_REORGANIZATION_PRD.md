# PRD: DETF directory reorganization (`common/` + Balancer V3 family tree)

| Field | Value |
|-------|--------|
| **Status** | **LOCKED for implement** — layout and pass boundaries agreed 2026-07-31 |
| **Date** | 2026-07-31 |
| **Target** | Reorganize `contracts/vaults/detf/**` so shared DETF infrastructure lives under `common/`, and Balancer V3–backed family packages live under `protocols/dexes/balancer/v3/` |
| **This pass** | **Move (and dead-code delete) only** — no Solidity type renames except where a file/path move requires import path updates |
| **Deferred** | Type renames (`DETDFPkg` → `DETFDFPkg`, `IDetf` → `IDETF`, family type casing / short names) assessed in a **follow-on PRD/pass** |
| **Risk posture** | Medium import churn; **no intentional product behavior change**; CREATE3 salts unchanged in this pass (type names stay) |

---

## 0. Locked decisions (2026-07-31)

| Topic | Decision |
|-------|----------|
| **Shared code** | Components common to most or all true DETFs live under `contracts/vaults/detf/common/` |
| **Family code** | Components specific to a DETF family live under `contracts/vaults/detf/protocols/dexes/balancer/v3/` because all **current** true DETFs use Balancer V3 as the reserve pricing engine |
| **Family folder names** | **Keep current type-aligned names** for this pass (e.g. `standardExchange/single`, `multi-vault-weighted`, `mixedBuffer`, `stable/common` leaf names as today under the new root). Assess product renames **after** the move |
| **Uniswap V4 path** | **Keep** empty placeholder `contracts/vaults/detf/protocols/dexes/uniswap/v4/` for later work (no family package in this pass) |
| **`reusable/`** | Move under `common/factory/` (not left as a sibling of `common/`) |
| **Program markdown (family-specific)** | Move under **mirrored** trees: `docs/detf/balancer/v3/<family-path>/` (same leaf shape as code). **No flat dump** under `balancer/v3/` |
| **Co-located family docs** | **Delete** all co-located family **PRDs and plan files** next to packages (§5.3 inventory). Do **not** move, archive, or stub. **Exception:** numbered compound/expansion stages 00–09 and shared PROGRAM/PRD/handoff — those **move** to `docs/detf/` (mirrored for family stages) |
| **Stubs after doc moves** | **None.** Update all links (PROGRAM, AGENTS, inventories). No `README` / path stubs under `contracts/vaults/detf/` for moved compound/expansion law |
| **Verification** | **Full four-family test suites** (not smoke-only). See §10 / §8 P4 |
| **Pool inventory paths** | Update `docs/DETF_POOL_INTEGRATION_INVENTORY.md` path columns **in the same PR** as the move |
| **Foundry test tree** | **Mirror fully** under `test/foundry/**/vaults/detf/**` to match code layout (`common/`, `protocols/dexes/balancer/v3/...`). See §7.2 |
| **Markdown link updates** | **Repo-wide** path grep for moved/deleted `detf` paths (research, scripts README, plans, etc.) — not only AGENTS / PROGRAM / pool inventory. See §7 |
| **Missing Threshold Modes PRD** | `DETF_Threshold_Modes_PRD.md` is **not on disk**; do **not** recreate. **Drop** broken AGENTS link; point threshold law at code (`DETFThresholdPolicy`) + `docs/detf/` shared law. Rewrite AGENTS so family PRDs are **not** “normative” after co-located deletes |
| **`standardExchange/uniV4Single/`** | **Leave untouched** this pass (PRD-only scaffold; no Solidity). Not moved, not deleted, not under Balancer tree until a separate PRD |
| **Delivery shape** | **Single PR** covering P0–P4 (no stacked partial layouts on main) |
| **This pass scope** | **Move only** (+ agreed dead-code deletes + co-located PRD/plan deletes + test-tree mirror + repo-wide link fixes). **No type renames** in this pass |
| **Accepted rename law (later pass)** | (1) All `DETDFPkg` → `DETFDFPkg` (typo fix). (2) Shared surface `IDetf` → `IDETF`. Not executed until a dedicated rename pass |
| **Product law** | Unchanged: true DETF rules in AGENTS.md; threshold modes (via code + `docs/detf/`); protocol compound + natural expansion; opacity of SE legs |

### 0.1 Clarifications locked 2026-07-31 (post-draft)

| # | Question | Lock |
|---|----------|------|
| 1 | Docs tree shape under `docs/detf/balancer/v3/` | **Mirrored** family paths only |
| 2 | Co-located family PRDs **and** plan files | **Delete both** (PRDs + implementation / threshold / adversarial / fuzz / removal plans next to packages). Confirmed again: delete, do not relocate |
| 3 | Pointers after moving shared program law | **No stubs** — update links only |
| 4 | Forge verification bar | **Full four-family test suites** |

### 0.2 Clarifications locked 2026-07-31 (pre-implement Q&A)

| # | Question | Lock |
|---|----------|------|
| 5 | `standardExchange/uniV4Single/` (PRD-only; no Solidity) | **Leave untouched** outside this pass — do not move, delete, or place under `protocols/dexes/balancer/v3/` |
| 6 | Foundry test tree `test/foundry/**/vaults/detf/**` | **Yes — mirror full test tree** to `common/` and `protocols/dexes/balancer/v3/<family-path>/` (spec + fork as applicable) |
| 7 | AGENTS cites missing `DETF_Threshold_Modes_PRD.md` | **Update AGENTS** — drop the missing path; point at code + `docs/detf` only; do not recover/recreate the file this pass |
| 8 | Non-code link update width | **Repo-wide** path grep for moved/deleted detf paths (research, scripts, plans, etc.); still no full historical consolidation rewrite |
| 9 | Delivery shape for P0–P4 | **Single PR** covering all phases |
| 10 | Threshold policy plan destination (§5.4) | **Flat** `docs/detf/` (not `docs/detf/common/`) |

---

## 1. Problem statement

The DETF tree grew organically and is hard to navigate:

1. **Shared vs family is mixed.** Core libs, bond NFT, claim token, inventory policies, and factory helpers sit as peer top-level dirs next to incomplete scaffolding (`dual/`), empty bases (`DETFCommon.sol`), and historical parents (`composed/`, `standardExchange/`).
2. **`composed/` is not a topology.** Multi-vault weighted and multi-vault stables live under `composed/`, while single-SE lives under `standardExchange/` — not because single-SE is less “composed,” but because of historical product names.
3. **Empty dual inheritance** (`DualDETFCommon` → `DualEmbeddedDETFCommon` → protocol stubs) has no production surface and confuses agents/docs into treating dual as a live family.
4. **Program markdown clutters the Solidity root** (stages 00–09 + compound/expansion law next to packages).
5. **Scaffold dirs already exist** (`common/`, `protocols/dexes/balancer/v3/`, `protocols/dexes/uniswap/v4/`) but are empty — this PRD fills them intentionally.

Without a layout law, agents re-invent trees, leave dual stubs “for later,” and misplace new families.

---

## 2. Goals / non-goals

### Goals (this program)

1. Establish a durable **two-axis layout**:
   - **`common/`** — shared true-DETF infrastructure and pure libs.
   - **`protocols/dexes/<host>/…`** — host-specific DETF family packages (today: Balancer V3 only).
2. **Move** existing production families and shared packages into that layout with **import updates only**.
3. **Delete** confirmed dead dual scaffolding, empty error-only bases, and **co-located family PRDs and plan files** (§5.3 inventory).
4. **Relocate family-specific program stage markdown** to **mirrored** `docs/detf/balancer/v3/<family-path>/`.
5. Update **AGENTS.md**, PROGRAM links, pool inventory paths, and **repo-wide** path references — **no stub files** left behind for moved docs.
6. **Mirror** Foundry test directories under `test/foundry/**/vaults/detf/**` to the new layout (§7.2).
7. Prove **behavior unchanged**: run **full** forge test suites for all four true DETF families (same TestBases / match-paths covering each family, not smoke-only).

### Non-goals (this pass)

- Renaming Solidity **types**, **interfaces**, or **CREATE3 salt-affecting** `type(X).name` values (including `SingleStandardExchangeDETDFPkg`, `IDetf`, `*Detf` vs `*DETF` family renames).
- Extracting shared logic from family `*Common.sol` bodies (DRY / consolidation program — separate).
- Converging Composed Stable family-local Bond NFT onto shared `bondNft/` (separate).
- Moving or redesigning **Seigniorage** or Balancer **pool/SE** packages under `contracts/protocols/dexes/balancer/v3/`.
- **DualLiquidity** layout was a non-goal of *this* reorg pass; superseded by [`docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_CrossVersion_Directory_Move_PRD.md`](../../../docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_CrossVersion_Directory_Move_PRD.md) (package now under `protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/`; still **not** a true DETF).
- Implementing a Uniswap V4–reserve DETF under the placeholder path.
- Moving, deleting, or adopting **`standardExchange/uniV4Single/`** (leave untouched).
- Recreating missing **`DETF_Threshold_Modes_PRD.md`** from history.
- Frontend / research **copy rewrites** beyond path fixes for moved/deleted detf locations.
- Full historical doc content sweep (`docs/DETF_CONSOLIDATION_*`, old Protocol DETF notes) beyond path updates.

### Non-goals (product)

- Changing mint/burn routes, thresholds, compound, expansion, fees, or inert→live rules.
- Making DETF diamonds protocol-owned or upgradeable.

---

## 3. Layout law

### 3.1 Axis A — `common/` (shared)

**Rule:** If most or all true DETF families use it, or it is pure shared law/math/package infrastructure, it belongs under `common/`.

**Does not belong in `common/`:**

- Family DFPkg / facets / targets / repos / TestBases.
- Family-only packages with a single consumer (e.g. Composed Stable local Bond NFT, `RebasingDETFToken`) until a second consumer exists.
- Empty inheritance shells (`DETFCommon`, `DualDETFCommon`).

### 3.2 Axis B — `protocols/dexes/…` (host-backed families)

**Rule:** Family assemblies that price against a **reserve host** live under that host’s tree.

Today all true DETFs → Balancer V3:

```text
contracts/vaults/detf/protocols/dexes/balancer/v3/<family-path>/
```

**Contrast (do not merge):**

| Tree | Role |
|------|------|
| `contracts/protocols/dexes/balancer/v3/` | Protocol infra: pools, routers, SE vaults, rate providers |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/` | **DETF product families** that use Balancer as reserve |

**Placeholder:**

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/   # empty; later work only
```

Uni V4 as an **SE leg** of a Balancer DETF stays under `contracts/protocols/dexes/uniswap/` — it does **not** require a DETF family under `detf/protocols/dexes/uniswap/v4/`.

### 3.3 Target tree (end of move pass)

```text
contracts/vaults/detf/
  DETF_DIRECTORY_REORGANIZATION_PRD.md          # this reorg PRD (layout law for the move)
  # NO stubs for moved compound/expansion docs — those live only under docs/detf/

  common/
    core/                                         # was detf/core/  (Solidity only; planning md → docs)
      DETFThresholdPolicy.sol
      DETFProtocolCompoundLib.sol
      DETFNaturalExpansionLib.sol
      DETFBondLifecycleLib.sol
      DETFBondNFTMathLib.sol
      DETFUsageFeeLib.sol
      DETFMintSplitLib.sol
      DETFPreviewLib.sol
      DETFSafeTransferLib.sol
      DETFBalancerScaleLib.sol
    bondNft/                                      # was detf/bondNft/
    claimToken/                                   # was detf/claimToken/
    inventory/                                    # was detf/inventory/
    factory/                                      # was detf/reusable/
      DetfComponentFactoryService.sol
      DetfFacetFactoryService.sol
      DetfPkgFactoryService.sol
      nft/
        IDetfSelfNftInventoryDFPkg.sol

  protocols/
    dexes/
      balancer/
        v3/
          standardExchange/
            single/                               # Solidity + TestBase only (family PRDs deleted)
          multi-vault-weighted/
          mixedBuffer/
          stable/
            common/
      uniswap/
        v4/                                       # PLACEHOLDER — empty

docs/detf/
  # shared compound/expansion product law + stages 00, 05 (see §5.2)
  balancer/
    v3/
      standardExchange/single/                    # stages 01, 06 (mirrored)
      multi-vault-weighted/                       # stages 02, 07
      mixedBuffer/                                # stages 03, 08
      stable/common/                              # stages 04, 09
```

**After moves, delete empty parents:**  
`composed/`, `core/`, `bondNft/`, `claimToken/`, `inventory/`, `reusable/`, `dual/` (after dual delete).  
`standardExchange/single/` is gone (moved). **`standardExchange/uniV4Single/` stays** (out of pass), so the `standardExchange/` parent may remain solely for that scaffold.

---

## 4. Path mapping (move pass)

Paths below are relative to `contracts/vaults/detf/` unless noted.

### 4.1 Shared → `common/`

| From | To |
|------|-----|
| `core/**` | `common/core/**` |
| `bondNft/**` | `common/bondNft/**` |
| `claimToken/**` | `common/claimToken/**` |
| `inventory/**` | `common/inventory/**` |
| `reusable/**` | `common/factory/**` |

### 4.2 Families → `protocols/dexes/balancer/v3/` (type-aligned leaves)

| From | To |
|------|-----|
| `standardExchange/single/**` | `protocols/dexes/balancer/v3/standardExchange/single/**` |
| `composed/multi-vault-weighted/**` | `protocols/dexes/balancer/v3/multi-vault-weighted/**` |
| `composed/stable/mixedBuffer/**` | `protocols/dexes/balancer/v3/mixedBuffer/**` |
| `composed/stable/common/**` | `protocols/dexes/balancer/v3/stable/common/**` |

**Out of this pass (do not move):**

| Path | Action |
|------|--------|
| `standardExchange/uniV4Single/**` | **Leave as-is** (currently PRD-only). After `single/` moves, `standardExchange/` may remain solely for `uniV4Single/` until a later PRD |

**Family-local packages move with the family** (do not lift to `common/` in this pass):

- `ComposedStableCommonDetfBondNFTVault*`
- `RebasingDETFToken*`
- Family `*_FactoryService`, Targets, Facets, Repos, DFPkgs, **TestBases**

**Do not move with the family** (delete per §5.3): co-located family `*_PRD.md` and other listed planning markdown.

### 4.3 Type names (unchanged this pass)

Examples that **keep** their current identifiers (file basename may move with path; **contract name stays**):

| Keep as-is (this pass) | Later rename law |
|------------------------|------------------|
| `SingleStandardExchangeDETDFPkg` / `ISingleStandardExchangeDETDFPkg` | → `…DETFDFPkg` / `I…DETFDFPkg` |
| `IDetf` (`contracts/interfaces/detf/IDetf.sol`) | → `IDETF` |
| `IDetfProxy`, `IDetfErrors`, inventory `IDetf*` | Assess with `IDetf` → `IDETF` pass (consistency) |
| `MultiVaultWeightedDetf*`, `MixedBufferMultiVaultStableDetf*`, `ComposedStableCommonDetf*` | Optional product renames after move |
| `SingleStandardExchangeDETF*` | Optional casing alignment after move |

**Explicit:** fixing `DETDFPkg` → `DETFDFPkg` **changes** `type(…).name` CREATE3 salts. That is **out of the move pass**.

### 4.4 Interfaces under `contracts/interfaces/`

**This pass:** update **import paths only** when they point into moved `detf/**` sources. Do **not** rename interface files (`IDetf.sol` stays until rename pass).

---

## 5. Documentation moves and deletes

### 5.1 Family-specific program / stage plans → mirrored `docs/detf/balancer/v3/`

Move **implementation-specific** compound + expansion stage plans that name a single family. **Layout is mirrored only** (no flat `docs/detf/balancer/v3/*.md` dump).

| From (`contracts/vaults/detf/`) | To |
|---------------------------------|-----|
| `01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/standardExchange/single/01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md` |
| `02_MultiVaultWeightedDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/multi-vault-weighted/02_…` |
| `03_MixedBufferMultiVaultStableDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/mixedBuffer/03_…` |
| `04_ComposedStableCommonDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/stable/common/04_…` |
| `06_SingleStandardExchangeDETF_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/standardExchange/single/06_…` |
| `07_MultiVaultWeightedDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/multi-vault-weighted/07_…` |
| `08_MixedBufferMultiVaultStableDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/mixedBuffer/08_…` |
| `09_ComposedStableCommonDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/balancer/v3/stable/common/09_…` |

Keep **original filenames** (including stage prefixes) under the mirrored directories so grep and historical references stay findable. Update `PROGRAM.md` links to the new paths.

### 5.2 Shared program law → `docs/detf/` (no stubs)

| Doc | Destination |
|-----|-------------|
| `00_DETF_Protocol_Compound_Shared_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/00_…` |
| `05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md` | `docs/detf/05_…` |
| `DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` | `docs/detf/` (product law remains normative) |
| `DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md` | `docs/detf/` — update **all** stage links to §5.1 / §5.2 paths |
| `DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md` | `docs/detf/` |

**No stubs:** do not leave placeholder files under `contracts/vaults/detf/` that only redirect to `docs/detf/`. Update AGENTS, PROGRAM, and any in-repo links. Broken old paths are intentional after the move.

### 5.3 Delete co-located family PRDs **and** plan files (confirmed)

**Lock (confirmed):** delete **both** co-located family **PRDs** and co-located family **plan files**. They are **not** moved with Solidity, **not** archived under `docs/`, and **not** replaced by stubs.

**Rule of thumb:** if a `.md` sits **inside a family package directory** (or is SingleVault removal residue under `composed/`) and is **not** a numbered 00–09 program stage living at the **detf root**, **delete it**.

#### Inventory to delete (pre-move paths)

**Single SE** (`standardExchange/single/`):

- `SingleStandardExchangeDETF_PRD.md`
- `SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md`
- `SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
- `SingleStandardExchangeDETF_ADVERSARIAL_TEST_PLAN.md`
- `SingleStandardExchangeDETF_FUZZ_INVARIANT_TEST_PLAN.md`

**MultiVault Weighted** (`composed/multi-vault-weighted/`):

- `MultiVaultWeightedDetf_PRD.md`
- `MultiVaultWeightedDetf_IMPLEMENTATION_AND_TEST_PLAN.md`
- `MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
- `MultiVaultWeightedDetf_ADVERSARIAL_TEST_PLAN.md`
- `MultiVaultWeightedDetf_FUZZ_INVARIANT_TEST_PLAN.md`

**MixedBuffer** (`composed/stable/mixedBuffer/`):

- `MixedBufferMultiVaultStableDetf_PRD.md`
- `MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md`
- `MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

**Composed Stable Common** (`composed/stable/common/`):

- `ComposedStableCommonDetf_PRD.md`
- `ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
- `ComposedStableCommonDetf_ADVERSARIAL_TEST_PLAN.md`

**SingleVault removal residue** (`composed/`):

- `SingleVaultDetf_REMOVAL_PRD.md`
- `SingleVaultDetf_REMOVAL_IMPLEMENTATION_AND_TEST_PLAN.md`

If additional co-located `*_PRD.md` / `*_PLAN.md` / `*_TEST_PLAN.md` appear under those family dirs at implement time, **delete them too** under the same rule.

#### Do not delete (move instead, or keep)

| Item | Action |
|------|--------|
| Numbered stages `00_`–`09_` at **detf root** | **Move** per §5.1–5.2 (not delete) |
| `DETF_Protocol_Compound_And_Supply_Expansion_{PRD,PROGRAM,HANDOFF…}.md` at detf root | **Move** to `docs/detf/` |
| `core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` | **Move** to `docs/detf/` per §5.4 |
| This reorg PRD (`DETF_DIRECTORY_REORGANIZATION_PRD.md`) | **Keep** |
| Solidity, TestBases, FactoryServices | **Move** with family / common |

**Normative product law after delete:** AGENTS.md common DETF expectations + `docs/detf/` compound/expansion (and threshold policy plan) + remaining code NatSpec / `DETFThresholdPolicy`. Family-specific historical PRDs and co-located plan files are intentionally retired. Do **not** cite missing or deleted family PRDs as normative.

### 5.4 Threshold policy plan under core

Move `core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` → **`docs/detf/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`** (flat under `docs/detf/`, **not** `docs/detf/common/`). Do **not** leave it under `common/core/` after the move.

### 5.5 Missing `DETF_Threshold_Modes_PRD.md`

AGENTS.md historically linked `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md`, but that file is **not present** in the tree. This pass:

- Does **not** recreate or recover it from git history.
- **Removes** the broken AGENTS link.
- Treats threshold product law as: **`DETFThresholdPolicy` + AGENTS threshold section + `docs/detf/` plans moved in this pass** (including §5.4).

---

## 6. Dead code deletes (this pass)

Delete only when nothing real inherits or imports after dual removal.

| Path | Reason |
|------|--------|
| `dual/DualDETFCommon.sol` | Empty shell |
| `dual/embedded/DualEmbeddedDETFCommon.sol` | Empty shell |
| `contracts/protocols/dexes/aerodrome/v1/vaults/exchange/standard/detf/dual/embedded/AerodromeDualEmbeddedDETFCommon.sol` | Empty; no production consumer |
| `contracts/protocols/dexes/uniswap/v2/vaults/exchange/standard/detf/dual/embedded/UniswapV2DualEmbeddedDETFCommon.sol` | Empty; no production consumer |
| Empty parent dirs under those dual paths | After file delete |
| `DETFCommon.sol` | Error-only bag; after dual gone, only Composed Stable used it — **repoint** `ComposedStableCommonDetfCommon` to inherit `IStandardExchangeErrors, IDetfErrors` (or equivalent) **without** a new empty Common |

**Do not delete in this pass:**

- `StandardExchangeSingleVaultSeigniorageDETF*` under Balancer vaults (name trap; out of scope).
- Seigniorage product under `contracts/vaults/seigniorage/`.
- Shared `bondNft/` / `claimToken/`.
- Empty `protocols/dexes/uniswap/v4/` placeholder directory (**keep**).
- `standardExchange/uniV4Single/**` (**leave untouched** this pass).

**Optional (not required):** collapse empty inventory aliases (`IDetfSelfNftInventoryPolicy`, `IDetfNftInventoryPolicy`) — defer unless zero churn; not part of move success criteria.

---

## 7. Import / agent / test updates (required with moves)

1. **All Solidity imports** pointing at old `contracts/vaults/detf/{core,bondNft,claimToken,inventory,reusable,standardExchange/single,composed,dual}/**` paths (do not rewrite `uniV4Single` as part of a forced delete).
2. **Test tree mirror** under `test/foundry/**/vaults/detf/**` per §7.2, plus co-located TestBases that move with packages.
3. **Scripts** under `scripts/foundry/**` that import family DFPkgs / factories.
4. **AGENTS.md** (and Claude pointers if any):
   - DETF family path table + key reference paths → `common/` and `protocols/dexes/balancer/v3/…`
   - Drop links to deleted family PRDs/plans
   - Drop broken `DETF_Threshold_Modes_PRD.md` link (§5.5)
   - Stop stating that co-located family PRDs “remain normative”
5. **Compound/expansion PROGRAM** and stage plan cross-links after doc moves (`docs/detf/…` mirrored paths).
6. **`docs/DETF_POOL_INTEGRATION_INVENTORY.md`** path columns for the four families — **same PR** as the move.
7. **Repo-wide markdown / comment path grep** for old `contracts/vaults/detf/{core,bondNft,claimToken,inventory,reusable,composed,standardExchange/single,dual}` paths and deleted co-located PRD/plan filenames — update **research/**, **scripts/** README, superpowers/plans, and other in-repo docs so links resolve. Non-goal remains: full rewrite of historical consolidation essays.
8. Grep gate: no remaining imports of deleted dual paths; no broken imports to old production family roots; no stubs reintroducing old doc paths under `contracts/vaults/detf/` (except intentional `uniV4Single` leave-behind).

### 7.1 Full four-family test suites (P4)

Run **full** existing suites for each true DETF family (not a single smoke test). Implementer should use the established match-path / match-contract patterns already used for each family under `test/foundry/**` and any co-located family tests, covering at least:

| Family | Suite scope |
|--------|-------------|
| SingleStandardExchangeDETF | Full match-path (or equivalent) for that family’s unit/integration/adversarial/fuzz tests that exist in-repo |
| MultiVaultWeightedDetf | Full family suite |
| MixedBufferMultiVaultStableDetf | Full family suite |
| ComposedStableCommonDetf | Full family suite |

If a family has multiple disjoint match-paths (e.g. hermetic + fork matrix), run **all** of them that are part of that family’s normal CI/dev verification surface. Document the exact `forge test` invocations in the PR description.

### 7.2 Foundry test directory mirror (required)

**Lock:** reorganize `test/foundry/**/vaults/detf/**` to **mirror** the new production layout — not imports-only under old `composed/` / `standardExchange/` test folders.

| From (illustrative) | To |
|---------------------|-----|
| `test/foundry/spec/vaults/detf/common/core/**` | `test/foundry/spec/vaults/detf/common/core/**` |
| `test/foundry/spec/vaults/detf/common/bondNft/**` | `test/foundry/spec/vaults/detf/common/bondNft/**` |
| `test/foundry/spec/vaults/detf/common/claimToken/**` | `test/foundry/spec/vaults/detf/common/claimToken/**` |
| `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**` | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**` |
| `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**` | `…/protocols/dexes/balancer/v3/multi-vault-weighted/**` |
| `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**` | `…/protocols/dexes/balancer/v3/mixedBuffer/**` |
| `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**` | `…/protocols/dexes/balancer/v3/stable/common/**` |
| `test/foundry/fork/**/vaults/detf/standardExchange/single/**` (if present) | Mirror under `…/protocols/dexes/balancer/v3/standardExchange/single/**` |

Same leaf intent for any other `test/foundry/**/vaults/detf/**` nodes that track old roots. After moves: update imports, match-path docs, and CI notes. Empty old test parents go away with the mirror.

---

## 8. Phased implementation (single PR)

| Phase | Work | Done when |
|-------|------|-----------|
| **P0** | Delete dual stubs + protocol dual Commons; remove `DETFCommon` and fix Composed Stable inheritance; **delete co-located family PRDs and plan files** (§5.3 inventory) | Build green; no Dual* imports; grep shows no remaining §5.3 files |
| **P1** | Move shared → `common/{core,bondNft,claimToken,inventory,factory}`; mirror shared tests under `test/.../detf/common/` | Imports updated; build green |
| **P2** | Move four families → `protocols/dexes/balancer/v3/...`; mirror family tests; remove empty `composed/`; remove `standardExchange/single` only (**leave `uniV4Single`**) | Family tests compile under new paths |
| **P3** | Move program markdown per §5.1–5.2 (**mirrored**); update PROGRAM + AGENTS (§5.5) + pool inventory + **repo-wide** path links; **no stubs** | Links resolve under `docs/detf/`; broken Threshold Modes PRD link gone |
| **P4** | Verification: **full four-family test suites** (§7.1) | All green; no behavior change expected |

**Delivery lock:** ship **P0–P4 as a single PR**. Do **not** land partial phase stacks on main. Do **not** mix type renames into P0–P4.

---

## 9. Follow-on rename pass (explicitly deferred)

A **separate** PRD or amendment will cover:

1. **`DETDFPkg` → `DETFDFPkg`** everywhere (file, contract, interface, factory helpers, scripts, tests). Document CREATE3 salt impact.
2. **`IDetf` → `IDETF`** (and decide companion renames: `IDetfProxy`, `IDetfErrors`, inventory interfaces, vs leave inventory as-is).
3. Optional product renames: drop “Composed”, shorten MixedBuffer, unify `Detf` vs `DETF` in type names.
4. Resolve clash with existing `contracts/interfaces/IDETF.sol` (rebasing valuation surface) **before** renaming `IDetf` → `IDETF` — e.g. rename today’s `IDETF` to `IRebasingDetfValuation` / family-specific name first.

**This move PRD does not authorize that rename pass.**

---

## 10. Success criteria

1. Target tree matches §3.3 (plus placeholder `uniswap/v4/`).
2. No **production** code under old roots: `detf/core`, `detf/bondNft`, `detf/claimToken`, `detf/inventory`, `detf/reusable`, `detf/composed`, `detf/dual`. `detf/standardExchange/single` gone (moved). **Allowed leave-behinds:** this reorg PRD; `detf/standardExchange/uniV4Single/**` (untouched).
3. **Full four-family test suites** pass (§7.1) from **mirrored** test paths (§7.2).
4. AGENTS.md family paths point at `detf/common` and `detf/protocols/dexes/balancer/v3/...`; no broken Threshold Modes PRD link; no “family PRDs remain normative” for deleted co-located files.
5. Family-specific compound/expansion stage plans live under **mirrored** `docs/detf/balancer/v3/<family-path>/`.
6. Shared compound/expansion law (and threshold policy plan) lives under **flat** `docs/detf/` with PROGRAM links updated; **no** stub files under `contracts/vaults/detf/` for those docs.
7. Co-located family **PRDs and plan files** (§5.3 inventory) are **gone** (not relocated, not archived). `uniV4Single` PRD is **not** in that inventory and stays.
8. `docs/DETF_POOL_INTEGRATION_INVENTORY.md` path columns updated in the same change set.
9. Repo-wide path links for moved/deleted production detf paths updated (§7 item 7).
10. **Zero intentional behavior change**; type names unchanged except inheritance fix for deleted `DETFCommon`.
11. `detf/protocols/dexes/uniswap/v4/` still exists as empty placeholder.
12. Delivered as **one PR** (P0–P4).

---

## 11. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Missed import / remapping | Repo-wide path grep; full forge build |
| Agents keep writing to old paths | AGENTS.md first in PR; delete old dirs so compile fails loudly |
| Accidental CREATE3 rename | Code review forbid type renames; CI greps for `DETDFPkg` still present (expected until rename pass) |
| Doc link rot | PROGRAM + stage links + **repo-wide** path grep in same PR as doc moves |
| Partial main layout | **Single PR** for P0–P4 |
| Confusing two Balancer trees | This PRD §3.2 + one-line comment in `detf/protocols/README` optional |
| Accidental `uniV4Single` delete/move | Explicit leave-behind in §4.2 / §12; review checklist |

---

## 12. Out-of-tree / do-not-touch reminder

| Location | Status |
|----------|--------|
| `contracts/protocols/dexes/balancer/v3/**` (pools, routers, SE) | **Out of scope** |
| `contracts/vaults/seigniorage/**` | **Out of scope** |
| DualLiquidity linked cross-version | **Layout move done** under `protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` (see DualLiquidity directory-move process PRD); still **not** a true DETF product |
| `contracts/vaults/detf/standardExchange/uniV4Single/**` | **Out of scope this pass** — leave untouched |
| Frontend product map | Update only if imports break (unlikely) |

---

## 13. Acceptance checklist (implementer)

- [ ] P0 dual + `DETFCommon` deleted; Composed Stable inherits errors without empty base
- [ ] Co-located family PRDs **and** plan files (§5.3 inventory) **deleted** (not moved, not archived)
- [ ] `common/{core,bondNft,claimToken,inventory,factory}` populated; old shared roots gone
- [ ] Four families under `protocols/dexes/balancer/v3/` with type-aligned leaf names (Solidity + TestBases only)
- [ ] `standardExchange/uniV4Single/**` left untouched
- [ ] `protocols/dexes/uniswap/v4/` placeholder retained
- [ ] Foundry test tree **mirrored** (§7.2); old `test/.../composed` and production-family `standardExchange/single` test roots gone
- [ ] Family-specific program stages under **mirrored** `docs/detf/balancer/v3/<family-path>/`
- [ ] Shared compound/expansion law + threshold policy plan under **flat** `docs/detf/`; **no stubs** under `contracts/vaults/detf/`
- [ ] AGENTS.md + PROGRAM + pool inventory path columns updated; Threshold Modes broken link removed
- [ ] Repo-wide markdown path updates for moved/deleted production detf paths
- [ ] Forge build green
- [ ] **Full four-family test suites** green; exact `forge test` commands listed in PR notes
- [ ] No `DETDFPkg`→`DETFDFPkg` or `IDetf`→`IDETF` renames in the diff
- [ ] Single PR delivers P0–P4

---

## 14. Related documents

| Doc | Role |
|-----|------|
| `Agents.md` / `AGENTS.md` | True DETF product law; family table paths (update with this PRD); no missing Threshold Modes PRD link |
| `docs/DETF_POOL_INTEGRATION_INVENTORY.md` | Pool ↔ family matrix (path columns; update same PR) |
| `docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` | Compound + expansion product law (after move) |
| `docs/detf/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` | Threshold policy implementation plan (after move from `core/`) |
| Future rename PRD | `DETDFPkg` / `IDETF` / optional family renames |
| Future `uniV4Single` PRD | Scaffold left under `standardExchange/uniV4Single/` until a dedicated pass |

Deleted family PRDs and co-located plan files are intentionally absent from this table. Missing historical `DETF_Threshold_Modes_PRD.md` is not restored.

---

## 15. Revision history

| Date | Change |
|------|--------|
| 2026-07-31 | Initial lock: common + balancer/v3 families; move-only pass; deferred rename law; uniswap/v4 placeholder; reusable → common/factory; family program md → docs/detf/balancer/v3 |
| 2026-07-31 | Clarifications: mirrored docs only; **delete** co-located family PRDs/planning md; **no stubs**; full four-family test suites; pool inventory path update same PR |
| 2026-07-31 | Confirmed: delete **both** co-located family PRDs **and** plan files; §5.3 expanded to full file inventory |
| 2026-07-31 | Pre-implement Q&A: leave `uniV4Single` untouched; **mirror full** Foundry test tree; drop missing Threshold Modes PRD from AGENTS; **repo-wide** link updates; **single PR** for P0–P4; threshold plan → flat `docs/detf/` (§0.2, §5.5, §7.2, §8) |
