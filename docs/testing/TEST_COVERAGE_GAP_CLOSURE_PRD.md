# Product Requirements Document (PRD)

## Title

**Test Coverage Gap Closure** — production CODE + production-first Foundry tests that close Stage 1 coverage-audit Blocker/High gaps (PAT-I-ABS free credit, I1–I3, J1–J3, residual K1, Permit2/router hygiene, thin adversarial ports)

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **READY-FOR-IMPLEMENTATION** (Stage 2 PRD; authorizes Stage 3 only after an accepted execute plan) |
| **Kind** | Fix / gap-closure PRD |
| **Date** | 2026-08-09 |
| **Depends on Stage 1** | [`docs/testing/coverage-audit/AGGREGATE.md`](./coverage-audit/AGGREGATE.md), [`WORK_PACKAGE_BACKLOG.md`](./coverage-audit/WORK_PACKAGE_BACKLOG.md), [`areas/**`](./coverage-audit/areas/), [`PILOT_EXIT.md`](./coverage-audit/PILOT_EXIT.md), [`00_SCOPE_PARTITION.md`](./coverage-audit/00_SCOPE_PARTITION.md), runtime proof [`repro/TCA-COMMON-001/`](./coverage-audit/repro/TCA-COMMON-001/) |
| **Stage 1 audit law** | [`docs/testing/TEST_COVERAGE_AUDIT_PRD.md`](./TEST_COVERAGE_AUDIT_PRD.md) (locks **L-TCA-1…8**; WP schema §8; layers H…L3; catalog A–K) |
| **Normative backlog** | **44** formal WPs; **69/69** Blocker/High TCA IDs indexed (do not re-audit) |
| **Primary skills** | `crane-adversarial-testing` (+ `references/implementation-test-dod.md`), `crane-testing`, `indexedex-testing`, `indexedex-adversarial-testing`; hooks: `indexedex-uniswap-v4-hook-packages` |
| **Worktree / branch prefix** | `gap_cover_` (L-TCA-8) — e.g. worktree `gap_cover_i-common`, branch `gap_cover/i-common` |
| **Fork RPC** | `foundry.toml` `*_alchemy` endpoints + `ALCHEMY_KEY` (L-TCA-6); profile `FOUNDRY_PROFILE=fork` |
| **Orchestrator concurrency** | **≤ 3 subagents at a time** (L-GAPS-4); conflict-free slices only |
| **Product law (owner-locked 2026-08-09)** | §4.3 — delta credit, shared short-delivery error, hooks leftover policy, one-worktree package packing, fork BUILD_BLOCKED |
| **Execute plan** | [`docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md`](./TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md) — Stage 3 orchestrator: ≤3 worktrees, rebase+FF linear main |
| **Supersession** | This program owns I/J/K CODE+TEST WPs from the coverage-audit backlog (L-TCA-4); link struct-audit / 2026-07 IDs; do not fork a competing fix list |

---

## 2. Intent & success definition

### 2.1 Why this program exists

Stage 1 proved that IndexedEx still ships **trust-flag free credit** and **missing surface proofs** across money products:

1. **PAT-I-ABS (ship-blocking)** — `pretransferred=true` (and clones) credits caller-claimed amounts against **absolute** vault/diamond inventory without proving an inbound **balance delta**. Confirmed at runtime on `BasicVaultCommon` (`repro/TCA-COMMON-001/`). Same CODE pattern clones into DETF `_pullToken` / DualLiquidity `_receive*`, Uni V4 SE, Aave Stata free share mint, and hook CP free extract.
2. **Missing I1–I3** — almost no production-first free-mint adversarial coverage where trust flags exist; happy-path `pretransferred=true` with real transfer is **theater** (PAT-THEATER-PRE).
3. **PAT-J-OMIT / weak J1–J3** — Target APIs incomplete on facets, sparse declaration tests, missing **proxy** smoke (J3 must not call facet implementation addresses).
4. **Residual K1 / thin A–H / Permit2** — donation→pretransfer linkage, SE adversarial holes (especially Uni V2), FeeCollector money-out under-test, coordinator Permit2 abuse matrix incomplete.

Without a **serial Wave 0** on shared pull semantics and **conflict-free package slices** afterward, implementers will thrash, greenwash free mint, or merge-conflict on commons.

### 2.2 Goals

1. Close every **Blocker** and **High** WP in [`WORK_PACKAGE_BACKLOG.md`](./coverage-audit/WORK_PACKAGE_BACKLOG.md) with production CODE (when class is CODE/BOTH) and production-first Foundry tests (TEST/THEATER).
2. Keep Wave 0 commons **serial**; parallelize only **non-overlapping** package touch sets, with orchestrator **≤ 3 concurrent** worktrees.
3. Require **runtime-backed** acceptance for free-mint/extract Blockers (helper already confirmed; product e2e still RUNTIME_UNPROVEN until Stage 3 proves).
4. Hand Stage 3 agents a law document such that **PRD + backlog + linked TCA findings** are enough — no monorepo re-audit.

### 2.3 Success definition

Success is **not** “tests green on buggy free credit.” Success is:

| Criterion | Meaning |
|-----------|---------|
| **Blocker CODE closed** | Free absolute / blind pretransfer credit is impossible on touched money paths; acceptance tests fail on pre-fix code and pass post-fix |
| **I1–I3 present** | Every money pretransfer surface touched has catalog-named free-mint proofs (no transfer / short / residual reuse) |
| **J1–J3 present** | Every diamond package touched has Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ **proxy** callable |
| **No greenwash** | Theater tests asserting free credit as correct are removed or inverted; mock SUT never counts |
| **Waves respected** | Commons lands before dependent product I suites; merge order preserves conflict-free slices |
| **Evidence** | `forge test` (and fork where required) pasted in PR/worklog; repro under `docs/testing/coverage-audit/repro/<FINDING_ID>/` when useful |

**Explicit:** Stage 1 helper free-credit is **confirmed**. Product e2e Blockers labeled RUNTIME_UNPROVEN must include a **proof-first** task before severity can be marked closed as fixed.

### 2.4 Non-goals

- Re-auditing the monorepo from scratch (Stage 1 is done).
- Re-authoring MultiVault A–H gold suite (extend with I/J/K only).
- Reintroducing removed SingleVaultDetf / SeigniorageDETF products.
- Frontend / indexer / non-Foundry e2e.
- Formal verification, Echidna/Medusa campaigns, **`via_ir`**.
- Changing DETF product economics / fee schedules without `NEEDS_OWNER`.
- Deep rewrites of pure vendored `lib/**`. Shared **short-delivery error** is in scope (L-GAPS-10); full SecurePull algorithm library is **not** (L-GAPS-12).
- Opening `gap_cover_*` worktrees or implementing Stage 3 in the PRD-authoring run.

---

## 3. Normative coverage bar (import; do not weaken)

Source of truth: Stage 1 audit PRD §2, `crane-adversarial-testing`, and `implementation-test-dod.md`. Minimum close criteria for this fix program:

### 3.1 Trust-flag catalog (I) — money pretransfer

Normative **pull semantics** for vaults / DETFs / SE (not hook leftover free-balance — see §4.3):

| Rule | Behavior |
|------|----------|
| **Measure** | Observe **inbound balance delta** over the pull (before/after). Absolute `balanceOf(this)` alone is **not** delivery. |
| **Credit** | If `claimed ≤ delta`, credit **exactly `claimed`** (user-provided amount). |
| **Short** | If `claimed > delta`, **revert** with the monorepo shared short-delivery error (**L-GAPS-10**). Do not silently cap. Do not free-credit inventory. |
| **No exact-delta grief** | Do **not** require `delta == claimed` as a hard equality that reverts when extra tokens arrived (donations must not lock honest depositors). Crediting `claimed` when `claimed ≤ delta` is correct even if `delta > claimed`. |

| ID | Must prove |
|----|------------|
| **I1** | `pretransferred=true`, **no** caller transfer, vault/diamond already holds ≥ claimed amount → **delta = 0** → **shared short-delivery revert** (no free mint / free extract / free credit) |
| **I2** | Short delivery (`claimed > delta`, including partial transfer) → **exact** shared typed revert |
| **I3** | Residual after a partial path **cannot** fund a second free credit (second call without new inbound delta reverts or credits 0 path fails) |

Anti-theater: happy-path pretransfer with real funds is **not** I1–I3. I1 must not transfer tokens in-call and must not assert credit of pure inventory.

### 3.2 Surface catalog (J) — diamonds / DFPkgs

| ID | Must prove |
|----|------------|
| **J1** | Target / product interface money selectors ⊆ Facet `facetFuncs()` (controls derived from Target, not incomplete Facet copy) |
| **J2** | Selectors present in package `facetCuts` / diamond config; loupe `facetAddress(sel) != 0` |
| **J3** | Smoke-call each money selector on the **deployed proxy**, never only the facet implementation address |

### 3.3 Accounting sync (K)

Where balance-based credit exists:

| ID | Must prove |
|----|------------|
| **K1** | Donation / prior inventory cannot be consumed as another user’s deposit or pretransfer credit without explicit product law + tests |

After delta-pretransfer CODE, pure donation→pretransfer free mint should close at the pull layer; residual K may remain on product reserve-snapshot paths (test accordingly).

### 3.4 Classic adversarial / negatives (where WP requires)

- A–H P0 subset per product class (ports extend gold MultiVault / SE buffer patterns).
- Exact selectors on negatives — bare `vm.expectRevert()` is theater for acceptance.
- Preview ≡ execute where preview exists (P layer).

### 3.5 Deploy bar (non-negotiable)

- Facets: CREATE3 / `*FactoryService` / `create3Factory` — **never** `new` production facets on user paths.
- Vault / DETF DFPkgs: **IndexedEx manager vault registry** (`indexedexManager.deploy*DFPkg` / registry path) — never bypass with bare `diamondPackageFactory.deploy` for registered vault packages.
- Hook packages: production `deployHookVault` / factory path per `indexedex-uniswap-v4-hook-packages`.
- Coordinator router: production CREATE3 + DFPkg (documented intentional non-registry path in Stage 1 router report).
- Gold TestBases: `CraneTest` → `IndexedexTest` → protocol TestBase. **No mocks of SUT.**

### 3.6 DETF role names only

Use only: `rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken` / `address(this)`, `reservePool` / `reserveBpt`, `rebasingClaimToken`. Never product brands (RICH/RICHIR, etc.) in this PRD or Stage 3 worklogs.

---

## 4. Locked decisions

### 4.1 Inherited from Stage 1 (reaffirmed for fix work)

| Lock | Statement |
|------|-----------|
| **L-TCA-2** | **All money products** (vaults, DETFs, SE packages, hooks, fund routers) remain ship-blocking — do not DEFER as “not launch.” |
| **L-TCA-3** | Runtime proof required for Blocker CODE claims; static-only stays RUNTIME_UNPROVEN until Stage 3 proves. |
| **L-TCA-4** | This backlog owns I/J/K CODE+TEST WPs; supersedes competing struct-audit fix lists for those surfaces. |
| **L-TCA-5** | Fork-first products (e.g. DualLiquidity): missing fork P0 = hermetic severity. |
| **L-TCA-6** | Prefer `*_alchemy` RPC aliases + `ALCHEMY_KEY`. |
| **L-TCA-7** | Repro artifacts under `docs/testing/coverage-audit/repro/` (no secrets). |
| **L-TCA-8** | Branch/worktree prefix `gap_cover_`. |
| **L-CLAIM-3** | `pretransferred=true` credits only against **observed inbound delta**, not absolute inventory. Refined by **L-GAPS-9** (claim ≤ delta credit; claim > delta shared revert; no exact-delta lock). |

### 4.2 Process locks for the fix program (`L-GAPS-*`)

| Lock | Statement |
|------|-----------|
| **L-GAPS-1** | **Wave 0 serial on commons.** Shared short-delivery error lib + `WP-I-COMMON-001` (+ unit I suite `WP-I-COMMON-002`) land and merge **before** any product I suite that depends on fixed shared semantics may claim green on inheritors. |
| **L-GAPS-2** | **CODE before greenwash.** Class CODE/BOTH: fix production first (or red test then CODE then green). Never merge tests that assert free mint of book/inventory as correct. |
| **L-GAPS-3** | **Conflict-free slices only.** Two concurrent worktrees must not share primary production or primary test touch-set files. Same Facet / Common file → **serial**. Different packages under different trees → parallel after Wave 0 API freeze. |
| **L-GAPS-4** | **Orchestrator concurrency ≤ 3.** The Stage 3 orchestrator launches **at most three** implementer subagents (worktrees) at once. Queue remaining slices; do not spawn four+ to “go faster.” |
| **L-GAPS-5** | **Slice ownership = package path.** Each parallel CODE slice owns one product package directory (or tightly coupled Common+Targets under that package). Cross-package meta-WP `WP-I-CLONE-001` is an **API-freeze + checklist**, not a single agent rewriting all clones’ algorithms. |
| **L-GAPS-6** | **One worktree per package for CODE+I+J.** Execute plan **must** collapse a product’s CODE + I suite + optional J/K for that package into **one** `gap_cover_*` worktree. Implementors must not open a second tree on the same package for those WPs. |
| **L-GAPS-7** | **No `via_ir`.** No package-specific IR profiles. |
| **L-GAPS-8** | **Backlog is normative for WP-IDs.** PRD may refine acceptance language; must not drop Blocker/High without explicit DEFER + severity-preserving reason in the execute plan. |
| **L-GAPS-12** | **Package-local delta algorithm; shared errors only.** Do **not** extract a monorepo `SecurePullLib` that rewires all clones. Each package implements the **same delta rules** (L-GAPS-9) in place. All Wave 0/1 pull CODE sites **import and throw** the shared short-delivery error (L-GAPS-10). |
| **L-GAPS-13** | **Fork-first BUILD_BLOCKED.** DualLiquidity (and any other fork-first product) **cannot** mark Blocker/High I acceptance closed without successful fork forge using `*_alchemy` + `ALCHEMY_KEY`. Missing RPC → WP stays open (`BUILD_BLOCKED`); hermetic helper-only is insufficient for product close. |

### 4.3 Owner-locked product law (2026-08-09) — implementors must not re-decide

These answers are **normative**. Stage 3 agents apply them; they do not invent alternatives.

#### L-GAPS-9 — Delta credit law (vaults, DETFs, SE pull helpers)

| Case | Required behavior |
|------|-------------------|
| `claimed ≤ observedDelta` | Credit **exactly `claimed`**. Extra delta (e.g. concurrent donation) must **not** cause revert and must **not** be credited beyond `claimed`. |
| `claimed > observedDelta` | **Revert** short delivery with shared typed error (L-GAPS-10). No silent cap. No free credit of pre-existing inventory. |
| `pretransferred=true` and caller transferred nothing | `observedDelta = 0` → if `claimed > 0`, **revert** (I1). Absolute inventory must not satisfy delivery. |
| Why not “exact delta == claim” revert | Requiring equality (or treating surplus inventory as mismatch) lets anyone grief/lock depositors by transferring supported tokens into the vault. **Do not** implement that. |

**Rationale (owner):** Credit the user-provided amount only when it is backed by measured inbound delta; short delivery reverts; donations must not lock the vault.

> **Refinement (BasicVault family):** L-GAPS-9 pretransfer baseline for packages that book via `MultiAssetBasicVaultRepo` / `BasicVaultCommon` is durable **`U = balanceOf − reserveOfToken`** (not in-call-only `balBefore`), with full expected-hold end-sync and absorb of unclaimed surplus — see [`docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`](../vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md).

#### L-GAPS-10 — Shared monorepo short-delivery error

| Rule | Detail |
|------|--------|
| **Path (locked)** | `contracts/interfaces/ISecurePullErrors.sol` |
| **Error (locked)** | `error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);` |
| **Usage** | `import {ISecurePullErrors} from "...";` then `revert ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta);` (or inherit interface on Target if that matches local style — same selector either way). |
| **Cutover** | **All Wave 0/1 pull CODE sites** throw this selector for short delivery and free-inventory pretends (`claimed > observedDelta`). |
| **I1/I2 acceptance** | Tests assert **this** selector via `abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, …)` (not bare `expectRevert`). |
| **Exception** | None for new CODE. Existing local errors on unchanged paths may remain until that path is touched. |
| **Not** | A full SecurePull algorithm library (forbidden by L-GAPS-12). Errors only. |

Wave 0 order: **(1)** land `ISecurePullErrors.sol` → **(2)** `BasicVaultCommon` + Aerodrome override use it → **(3)** unit I suite → then product packages import the same error.

#### L-GAPS-11 — Hook leftover free-balance policy (SE buffers)

Plain language:

- Hook may hold **book** balances (committed to the linked Standard Exchange) and **leftover** balances (fees, dust, tokens someone sent without a deposit).
- **Orbital / Weighted / Balancer / Curve SE buffer hooks:** keep today’s design where **leftover** may be spent by a caller with `pretransferred` without a same-tx transfer.
- Implementors **only add safety tests** for those products (`WP-I-HOOK-SEBUF-001`): (a) unfunded call with no leftover fails; (b) committed **book** cannot be free-spent; (c) leftover cannot fund a second free spend after it is consumed (I3-class).
- **Do not** rewrite leftover spend into exclusive-caller delta in this program.
- **Still mandatory CODE:** constant-product (and Dual gates) must not free-spend the **committed book** (`WP-I-HOOK-CP-001`, `WP-I-HOOK-DUAL-001`).

---

## 5. Scope — products & ownership

### 5.1 Ship-blocking inventory (in scope)

| Product | Area report | Worst open | Primary WP-IDs |
|---------|-------------|------------|----------------|
| BasicVaultCommon (+ Aero override) | `areas/T-basic-protocol-commons.md` | Blocker epic (runtime confirmed) | `WP-I-COMMON-001`, `WP-I-COMMON-002`, `WP-I-CLONE-001` |
| MultiVaultWeightedDetf | `areas/T-detf-multi-vault.md` | Blocker PAT-I-ABS | `WP-I-DETF-MV-001/002`, `WP-J-DETF-MV-001`, `WP-K-DETF-MV-001` |
| SingleStandardExchangeDETF (Balancer) | `areas/T-detf-single-se.md` | Blocker | `WP-I-DETF-SSE-001/002`, `WP-J-DETF-SSE-001` |
| Uni V4 CP Single SE DETF | `areas/T-detf-single-se.md` | Blocker | `WP-I-DETF-SSE-CP-001`, `WP-J-DETF-SSE-CP-001` |
| Uni V4 legacy Single SE DETF | `areas/T-detf-single-se.md` | Blocker | `WP-I-DETF-SSE-UV4-001` |
| ComposedStableCommonDetf + RebasingDETFToken | `areas/T-detf-composed-stable.md` | Blocker | `WP-I-DETF-CS-001/002`, `WP-J-DETF-CS-MB-001`, `WP-G-E-DETF-CS-001` |
| MixedBufferMultiVaultStableDetf | `areas/T-detf-composed-stable.md` | Blocker | `WP-I-DETF-MB-001`, `WP-ADV-DETF-MB-001`, `WP-J-DETF-CS-MB-001` |
| DualLiquidity (removed)CrossVersion | `areas/T-detf-dual-liquidity.md` | Blocker | `WP-I-DETF-DL-001/002`, `WP-J-DETF-DL-001` |
| Aerodrome / Camelot / Uni V2 SE | `areas/T-se-aerodrome-camelot-univ2.md` | Blocker/High I | `WP-I-SE-AC-001`, `WP-J-SE-AC-001`, `WP-ADV-SE-AC-001`, `WP-H-CAM-001`, `WP-E5-AERO-001` |
| Uni V4 SE + Aave Stata SE | `areas/T-se-univ4-aave-balancer.md` | Blocker | `WP-I-CLONE-UAB-001`, `WP-I-SE-UAB-001`, `WP-ADV-SE-UAB-001`, `WP-J-SE-UAB-001` |
| Balancer SE routers / buffer | `areas/T-se-univ4-aave-balancer.md` | High J formal | `WP-J-ROUTER-UAB-001` |
| Hooks (CP / Dual / SE buffers / pure AMM) | `areas/T-hooks-v4.md` | Blocker free extract | `WP-I-HOOK-CP-001`, `WP-I-HOOK-DUAL-001`, `WP-I-HOOK-SEBUF-001`, `WP-J-HOOK-001`, `WP-ADV-HOOK-001` |
| Manager / registry / fee oracle | `areas/T-manager-fee-registry.md` | High J-OMIT | `WP-J-MGR-001`, `WP-J-MGR-002` |
| FeeCollector | `areas/T-manager-fee-registry.md` | High money-out | `WP-N-FEE-001` |
| Coordinator router + Permit2 | `areas/T-routers-permit2.md` | High I5 / J / N | `WP-I5-RTR-001`, `WP-J-RTR-001`, `WP-N-RTR-001` |
| RebasingClaimToken (foreign-token residual) | commons + SVS report | High | `WP-I-CLAIM-001` |

### 5.2 Explicitly out of scope (live products)

| Item | Reason |
|------|--------|
| **SingleVaultDetf / SeigniorageDETF** product packages | **Removed** from tree — do not re-plan dead SUTs (`areas/T-detf-single-vault-seigniorage.md`). Successor money path = Single SE DETF. Claim residual only via `WP-I-CLAIM-001`. |
| Optional areas `T-slipstream-buffer`, `T-research-contracts` | Not required for Stage 1 DoD; not ship-blocking unless later promoted. |
| Frontend, indexer, pure marketing docs | Outside Foundry money path. |

### 5.3 Medium / clustered (not dropped; lower wave)

Pilot/full Mediums (exact-selector hygiene, Camelot depth already partly High via `WP-H-CAM-001`, residual K after I, MultiVault bare expectRevert, etc.) ride Wave 2–4. Formal §8 Mediums may be expanded in the execute plan; Blocker/High WPs are mandatory first.

---

## 6. Problem statement by epic

Each epic cites TCA-* and WP-* from the Stage 1 backlog. Class: CODE | TEST | BOTH.

### Epic 1 — Wave-0 commons pull (PAT-I-ABS epicenter)

| Field | Content |
|-------|---------|
| **Problem** | `BasicVaultCommon._secureTokenTransfer` on `pretransferred=true` returns claimed amount after absolute `balanceOf >= amount` — free credit of inventory without inbound delta. Aerodrome override still returns claimed amount. Unit tests currently assert free credit as correct (theater). |
| **Evidence** | TCA-COMMON-001 (**runtime confirmed**), TCA-COMMON-002/003, TCA-SE-AC-001 (root CODE) |
| **WPs** | `WP-I-COMMON-001` (CODE), `WP-I-COMMON-002` (TEST), start alignment checklist `WP-I-CLONE-001` |
| **Blast radius** | All BasicVaultCommon inheritors (Aero/Camelot/Uni V2; Aave Out burn paths); monorepo semantic freeze for clones |
| **Class** | BOTH (CODE then TEST) |
| **Wave** | **0** (serial) |
| **Depends on** | none |

### Epic 2 — DETF package-local pull / burn

| Field | Content |
|-------|---------|
| **Problem** | Package-local `_pullToken` / blind `_secureTokenTransfer` returns `amount_` when pretransferred; burn skips transfer and may extract diamond inventory. |
| **Evidence** | TCA-DETF-MV-001/002; TCA-DETF-SSE-001…004/008; TCA-DETF-CS-001…004 |
| **WPs** | `WP-I-DETF-MV-001`, `WP-I-DETF-SSE-001`, `WP-I-DETF-SSE-CP-001`, `WP-I-DETF-SSE-UV4-001`, `WP-I-DETF-CS-001`, `WP-I-DETF-MB-001` (+ product I/J tests in epic 7/8) |
| **Blast radius** | MultiVault, Single SE (Bal + Uni V4 CP + legacy), ComposedStable/RebasingDETFToken, MixedBuffer |
| **Class** | CODE (then TEST I suites) |
| **Wave** | **1** |
| **Depends on** | Prefer Wave 0 semantics freeze (L-GAPS-1); pure package-local clones may CODE in parallel after freeze notes land |

### Epic 3 — DualLiquidity receive paths

| Field | Content |
|-------|---------|
| **Problem** | `_receive` no-ops on pretransfer; `_receiveOut` spends absolute held inventory and can refund surplus — free mint/extract + donation theft. Fork-first product. |
| **Evidence** | TCA-DETF-DL-001/002 (Blocker CODE, RUNTIME_UNPROVEN); DL-003/005 (I/K tests) |
| **WPs** | `WP-I-DETF-DL-001` (CODE), `WP-I-DETF-DL-002` (TEST fork), `WP-J-DETF-DL-001` |
| **Blast radius** | DualLiquidity (removed)CrossVersion only (package-local) |
| **Class** | BOTH |
| **Wave** | **1** |
| **Depends on** | none for CODE (package-local); fork I suite after CODE; L-TCA-5 + Alchemy |

### Epic 4 — SE BasicVaultCommon consumers + Uni V4 / Aave

| Field | Content |
|-------|---------|
| **Problem** | Aero/Camelot/UniV2 inherit free absolute pretransfer; Uni V4 SE local absolute pull; Aave Stata In free share mint with no balance check on pretransfer. |
| **Evidence** | TCA-SE-AC-001…003; TCA-SE-UAB-001/002/003 |
| **WPs** | `WP-I-COMMON-001` (root), `WP-I-SE-AC-001` (TEST I), `WP-I-CLONE-UAB-001` (CODE), `WP-I-SE-UAB-001` (TEST), `WP-E5-AERO-001` (deadline BOTH) |
| **Blast radius** | SE family + Aave Stata |
| **Class** | CODE + TEST |
| **Wave** | **0** (commons) then **1** (product CODE/TEST) |
| **Depends on** | Commons for inheritors; UAB CODE package-local after freeze |

### Epic 5 — Hooks free extract / free gates

| Field | Content |
|-------|---------|
| **Problem** | Single SE CP raw→pair `pretransferred=true` free-extracts SE book; Dual lacks free gate + I; SE buffers need free-only I1–I3. |
| **Evidence** | TCA-HOOK-001 (Blocker); HOOK-002…009 High cluster |
| **WPs** | `WP-I-HOOK-CP-001`, `WP-I-HOOK-DUAL-001`, `WP-I-HOOK-SEBUF-001`, `WP-J-HOOK-001`, `WP-ADV-HOOK-001` |
| **Blast radius** | Uni V4 hook packages |
| **Class** | BOTH / TEST |
| **Wave** | **1** (CODE/I) then **2** (classic ADV) |
| **Depends on** | none for package CODE; leftover free-balance policy **locked L-GAPS-11** (tests only on SE buffers; book free-spend still CODE) |

### Epic 6 — Claim foreign-token residual

| Field | Content |
|-------|---------|
| **Problem** | RebasingClaimToken / RebasingDETFToken foreign-token absolute credit residual (L-CLAIM-3 incomplete). |
| **Evidence** | TCA-COMMON-005, TCA-DETF-SVS-003 |
| **WPs** | `WP-I-CLAIM-001` |
| **Blast radius** | Claim token + rebasing DETF token targets |
| **Class** | BOTH |
| **Wave** | **1** |
| **Depends on** | L-CLAIM-3 product law (locked); parallelizable with commons tests after CODE paths clear |

### Epic 7 — J-surface epics (DETF, SE, hooks, manager, routers)

| Field | Content |
|-------|---------|
| **Problem** | Sparse facet declaration; missing proxy J1–J3; manager seigniorage query typo silent miss (`seeigniorageTermsTypeId`). |
| **Evidence** | TCA-DETF-MV-004, SSE-006/009, CS-007, DL-004; SE-AC-004; UAB-006/007/010; HOOK-005; MGR-001/002; RTR-003 |
| **WPs** | `WP-J-DETF-MV-001`, `WP-J-DETF-SSE-001`, `WP-J-DETF-SSE-CP-001`, `WP-J-DETF-CS-MB-001`, `WP-J-DETF-DL-001`, `WP-J-SE-AC-001`, `WP-J-SE-UAB-001`, `WP-J-ROUTER-UAB-001`, `WP-J-HOOK-001`, `WP-J-MGR-001` (BOTH), `WP-J-MGR-002`, `WP-J-RTR-001` |
| **Blast radius** | All diamond money packages + manager/oracle + coordinator |
| **Class** | TEST (+ CODE if OMIT / typo) |
| **Wave** | **1–2** |
| **Depends on** | none for pure TEST; CODE OMIT fixes stay in package slice |

### Epic 8 — Permit2 / FeeCollector / exact-selector N hygiene

| Field | Content |
|-------|---------|
| **Problem** | Coordinator missing Permit2 replay / wrong spender / token mismatch suite; bare expectRevert theater; FeeCollector money-out under-tested. |
| **Evidence** | TCA-RTR-001/002; TCA-MGR-003 |
| **WPs** | `WP-I5-RTR-001`, `WP-N-RTR-001`, `WP-N-FEE-001` |
| **Blast radius** | Coordinator router + FeeCollector |
| **Class** | TEST |
| **Wave** | **2** (router/fee; J-RTR may Wave 1) |
| **Depends on** | none |

### Epic 9 — Thin adversarial / A–H ports / property depth

| Field | Content |
|-------|---------|
| **Problem** | Uni V2 SE no adversarial; shared SE harness thin; MixedBuffer no adversarial dir; Dual/pure AMM hooks thin; ComposedStable nested G + residual E; L1/L3 still G on several products. |
| **Evidence** | TCA-SE-AC-005/006/007; CS-006/008/010/011; HOOK-006/008; UAB-007/008; stage matrices |
| **WPs** | `WP-ADV-SE-AC-001`, `WP-ADV-DETF-MB-001`, `WP-ADV-HOOK-001`, `WP-ADV-SE-UAB-001`, `WP-G-E-DETF-CS-001`, `WP-H-CAM-001` (+ Wave 3 property WPs expanded in execute plan) |
| **Blast radius** | SE + DETF + hooks |
| **Class** | TEST |
| **Wave** | **2** (A–H/K ports); **3** (L1/L3 after I CODE on that product) |
| **Depends on** | Prefer I CODE closed on product before I-named ADV cases; classic A–H can start earlier if files disjoint |

---

## 7. Work package law

### 7.1 Backlog is normative

- [`WORK_PACKAGE_BACKLOG.md`](./coverage-audit/WORK_PACKAGE_BACKLOG.md) defines all **44** WP-IDs and the **69** finding→WP index.
- This PRD **refines** waves, anti-conflict slices, concurrency, and acceptance language.
- **Do not silently drop** any Blocker/High WP. Explicit DEFER requires severity-preserving reason in the execute plan and NatSpec on the suite if partially deferred.

### 7.2 Required fields on every Blocker/High WP (Stage 1 PRD §8)

Every implementer task must still carry: WP-ID, title, severity, class, products, finding IDs, problem, production touch set, test touch set, out of scope, depends on, parallelizable with, `gap_cover_*` worktree, implementation notes, forge acceptance, anti-theater checks, wave.

### 7.3 Parallelism law (merge-conflict prevention)

| Rule | Detail |
|------|--------|
| Same production file | **Serial** (one worktree owns it) |
| Same test file | **Serial** or same worktree merges CODE+TEST |
| Different package trees | **Parallel** after Wave 0 freeze |
| Meta clone checklist | `WP-I-CLONE-001` = orchestrator checklist + per-package CODE WPs — **not** one agent rewriting all clones |
| CODE+I+J packing | **Mandatory** one worktree for a product’s CODE + I + J/K (L-GAPS-6). Execute plan collapses WP lists per package. |
| Shared error lib | Owned only by Wave 0 commons worktree first; product WPs **import** only — do not redefine |

### 7.4 Concurrency law (orchestrator)

| Rule | Detail |
|------|--------|
| **Max concurrent subagents** | **3** (L-GAPS-4) |
| **Max concurrent worktrees** | **3** active implementation worktrees |
| **Queue** | Remaining slices wait until a slot frees and merge/rebase is clean |
| **Wave 0** | Exactly **1** active CODE agent on commons (`WP-I-COMMON-001`); optional second agent only on **docs-only** clone checklist or non-overlapping TEST after 001 lands |
| **Do not** | Spawn “scout” rewrite agents that edit contracts outside their slice |

### 7.5 Complete WP-ID inventory (44 — all acknowledged)

| # | WP-ID | Wave | Class | Slice key (conflict group) |
|--:|-------|------|-------|----------------------------|
| 1 | `WP-I-COMMON-001` | 0 | CODE | `slice-common` |
| 2 | `WP-I-COMMON-002` | 0–1 | TEST | `slice-common` |
| 3 | `WP-I-DETF-MV-001` | 1 | CODE | `slice-detf-mv` |
| 4 | `WP-I-SE-AC-001` | 1 | TEST | `slice-se-ac-i` |
| 5 | `WP-J-DETF-MV-001` | 1 | TEST | `slice-detf-mv` (or `slice-detf-mv-j`) |
| 6 | `WP-I-CLONE-001` | 0–1 | CODE checklist | orchestrator meta |
| 7 | `WP-ADV-SE-AC-001` | 2 | TEST | `slice-se-ac-adv` |
| 8 | `WP-J-SE-AC-001` | 1–2 | TEST | `slice-se-ac-j` |
| 9 | `WP-I-DETF-MV-002` | 1 | TEST | `slice-detf-mv` |
| 10 | `WP-I-CLAIM-001` | 1 | BOTH | `slice-claim` |
| 11 | `WP-I-DETF-SSE-001` | 1 | CODE | `slice-detf-sse` |
| 12 | `WP-I-DETF-SSE-CP-001` | 1 | BOTH | `slice-detf-sse-cp` |
| 13 | `WP-I-DETF-SSE-UV4-001` | 1 | CODE | `slice-detf-sse-uv4` |
| 14 | `WP-I-DETF-CS-001` | 1 | CODE | `slice-detf-cs` |
| 15 | `WP-I-DETF-MB-001` | 1 | CODE | `slice-detf-mb` |
| 16 | `WP-I-DETF-DL-001` | 1 | CODE | `slice-detf-dl` |
| 17 | `WP-I-CLONE-UAB-001` | 1 | CODE | `slice-se-uab` |
| 18 | `WP-I-HOOK-CP-001` | 1 | BOTH | `slice-hook-cp` |
| 19 | `WP-J-MGR-001` | 1 | BOTH | `slice-mgr-fee` |
| 20 | `WP-I5-RTR-001` | 2 | TEST | `slice-rtr` |
| 21 | `WP-J-HOOK-001` | 1–2 | TEST | `slice-hook-j` |
| 22 | `WP-J-MGR-002` | 2 | TEST | `slice-mgr-j` |
| 23 | `WP-N-FEE-001` | 2 | TEST | `slice-fee-n` |
| 24 | `WP-I-DETF-SSE-002` | 1 | TEST | `slice-detf-sse` |
| 25 | `WP-J-DETF-SSE-001` | 1 | TEST | `slice-detf-sse` |
| 26 | `WP-J-DETF-SSE-CP-001` | 1 | TEST | `slice-detf-sse-cp` |
| 27 | `WP-I-DETF-CS-002` | 1 | TEST | `slice-detf-cs` |
| 28 | `WP-ADV-DETF-MB-001` | 2 | TEST | `slice-detf-mb` |
| 29 | `WP-J-DETF-CS-MB-001` | 1 | TEST | `slice-detf-cs-mb-j` |
| 30 | `WP-G-E-DETF-CS-001` | 2 | TEST | `slice-detf-cs` |
| 31 | `WP-I-DETF-DL-002` | 1 | TEST | `slice-detf-dl` |
| 32 | `WP-J-DETF-DL-001` | 1 | TEST | `slice-detf-dl` |
| 33 | `WP-K-DETF-MV-001` | 1 | TEST | `slice-detf-mv` |
| 34 | `WP-I-HOOK-DUAL-001` | 1 | BOTH | `slice-hook-dual` |
| 35 | `WP-I-HOOK-SEBUF-001` | 1 | TEST | `slice-hook-sebuf` |
| 36 | `WP-ADV-HOOK-001` | 2 | TEST | `slice-hook-adv` |
| 37 | `WP-H-CAM-001` | 2 | TEST | `slice-se-cam-h` |
| 38 | `WP-E5-AERO-001` | 1 | BOTH | `slice-se-aero-e5` |
| 39 | `WP-I-SE-UAB-001` | 1 | TEST | `slice-se-uab` |
| 40 | `WP-ADV-SE-UAB-001` | 2 | TEST | `slice-se-uab-adv` |
| 41 | `WP-J-SE-UAB-001` | 1 | TEST | `slice-se-uab-j` |
| 42 | `WP-J-ROUTER-UAB-001` | 2 | TEST | `slice-se-bal-router-j` |
| 43 | `WP-N-RTR-001` | 2 | TEST | `slice-rtr` |
| 44 | `WP-J-RTR-001` | 1 | TEST | `slice-rtr` |

**Slice key rule:** only one active worktree per slice key (or explicit combined worktree that owns the whole key). Never two agents on the same slice key.

---

## 8. Implementation waves (normative for Stage 3)

### 8.1 Wave table

| Wave | Contents | Serial constraints |
|------|----------|--------------------|
| **0** | (1) Shared short-delivery error lib (L-GAPS-10); (2) commons delta CODE (`WP-I-COMMON-001`); (3) unit I1–I3 / theater kill (`WP-I-COMMON-002`); (4) clone API freeze checklist (`WP-I-CLONE-001`) | **Serial** — **1** implementer until error lib + commons merge; products only import error afterward |
| **1** | Product Blocker CODE + I1–I3 + J1–J3 per package (all Wave-1 WPs in §7.5) | Parallel **by slice key** only; **≤ 3** concurrent; not same Facet/Common file |
| **2** | Remaining A–H ports, SE adversarial expand, K residual, theater kill elsewhere, Permit2 I5, FeeCollector N, manager full J, Camelot H | After Wave 0; prefer after product I CODE on that surface |
| **3** | L1/L3 property layer on products still G after I CODE | After I CODE on that product |
| **4** | P2 / stub hygiene / optional BasicVault surface | Opportunistic |

### 8.2 Conflict-free parallel batches (max 3 slots)

These batches are the **default Stage 3 schedule**. The execute plan may refine order but must not increase concurrency above 3 or recombine conflicting slices.

#### Wave 0 (serial)

| Batch | Slot agents | WPs | Worktrees |
|-------|-------------|-----|-----------|
| **W0-A** | 1 | Shared short-delivery error lib + `WP-I-COMMON-001` + `WP-I-COMMON-002` + clone freeze notes (`WP-I-CLONE-001` checklist) | `gap_cover_i-common` (single tree; L-GAPS-6) |

#### Wave 1 — product Blocker CODE + package I/J (batches of ≤3)

| Batch | Concurrent slices (≤3) | Combined WPs per slice (preferred single worktree) |
|-------|------------------------|-----------------------------------------------------|
| **W1-A** | `slice-detf-mv` · `slice-detf-sse` · `slice-detf-cs` | MV: `WP-I-DETF-MV-001`+`002`+`K`+ optional J; SSE: `WP-I-DETF-SSE-001`+`002`+J; CS: `WP-I-DETF-CS-001`+`002` |
| **W1-B** | `slice-detf-mb` · `slice-detf-dl` · `slice-detf-sse-cp` | MB CODE; DL CODE+I+J; SSE-CP BOTH+J |
| **W1-C** | `slice-detf-sse-uv4` · `slice-se-uab` · `slice-hook-cp` | UV4 CODE; UAB CODE+I (+ J in same or W1-D); Hook CP BOTH |
| **W1-D** | `slice-hook-dual` · `slice-hook-sebuf` · `slice-claim` | Dual BOTH; SEBUF I; Claim BOTH |
| **W1-E** | `slice-se-ac-i` · `slice-se-aero-e5` · `slice-mgr-fee` | SE I after commons; Aero E5; seigniorage J CODE |
| **W1-F** | J-only leftovers not merged in A–E | e.g. `WP-J-DETF-CS-MB-001`, `WP-J-SE-AC-001`, `WP-J-SE-UAB-001`, `WP-J-HOOK-001`, `WP-J-RTR-001` — pick any **3** disjoint slice keys per round |

**W1 notes:**

- **Mandatory** CODE+I+J for one product in **one** worktree (L-GAPS-6).
- `WP-I-SE-AC-001` must not start until W0 commons is merged (inheritors).
- DualLiquidity: `ALCHEMY_KEY` + `FOUNDRY_PROFILE=fork`; missing RPC → **BUILD_BLOCKED** (L-GAPS-13), WP stays open.
- Product pull CODE **imports** shared short-delivery error from W0; implements delta algorithm **in package** (L-GAPS-12).

#### Wave 2 — expand adversarial / N / Permit2 (batches of ≤3)

| Batch | Example concurrent trio |
|-------|-------------------------|
| **W2-A** | `slice-se-ac-adv` · `slice-detf-mb` (ADV remaining) · `slice-hook-adv` |
| **W2-B** | `slice-se-uab-adv` · `slice-rtr` (I5+N+J if residual) · `slice-fee-n` |
| **W2-C** | `slice-se-cam-h` · `slice-mgr-j` · `slice-se-bal-router-j` |
| **W2-D** | `slice-detf-cs` residual G/E · other High TEST leftovers |

#### Waves 3–4

Property-layer and P2 hygiene WPs: execute plan expands file-level touch sets; keep **≤ 3** concurrent; one product property suite per worktree.

### 8.3 Suggested worktree / branch naming

| Pattern | Example |
|---------|---------|
| Worktree dir | `gap_cover_<slice>` e.g. `gap_cover_i-detf-mv` |
| Branch | `gap_cover/i-detf-mv` or `gap_cover_i-detf-mv` |
| Never | Branches without `gap_cover_` prefix; two worktrees for the same slice key |

---

## 9. Testing requirements (production-first)

### 9.1 Harness & deploy

- Gold TestBases and registry / factory deploy paths only.
- No `MockStandardExchange` / `vm.mockCall` on SUT counted as closed coverage.
- DETF role names only; skills: `crane-testing`, `indexedex-testing`, `indexedex-adversarial-testing`.

### 9.2 Naming & selectors

- Catalog tests: `test_I1_*`, `test_I2_*`, `test_I3_*`, `test_J1_*`, `test_J2_*`, `test_J3_*`, `test_K1_*`, plus classic `test_A1_*` … as applicable.
- Exact revert selectors (typed encoding preferred). Bare `expectRevert()` is not acceptance for money negatives.

### 9.3 CODE WP red→green narrative

For each CODE/BOTH WP, worklog should show:

1. (Preferred) Failing I1 (or free-mint) test on pre-fix code, **or** Stage 1 repro cite for confirmed helper.
2. Production fix per **L-GAPS-9** (delta credit / short shared revert / free gate on hooks book).
3. Green forge acceptance asserting **shared short-delivery selector** where applicable; theater tests removed or inverted.

### 9.4 Fork

- DualLiquidity and other fork-first paths: `FOUNDRY_PROFILE=fork` + `--fork-url <alias>_alchemy`.
- Document `BUILD_BLOCKED` if `ALCHEMY_KEY` missing — severity retained (L-TCA-5).

### 9.5 Ship gate

`implementation-test-dod.md` is the checklist for “fixed.” Orchestrator does not mark a WP merged without forge evidence and anti-theater checks from the WP record.

---

## 10. Runtime proof requirements

| Scope | Requirement |
|-------|-------------|
| **Wave 0 commons** | Already **confirmed** (`repro/TCA-COMMON-001/`). Regression suite must keep free-credit impossible (I1–I3). |
| **Each remaining Blocker CODE product** | Hermetic proof preferred (or fork for DualLiquidity) before severity closed as fixed. Capture under `docs/testing/coverage-audit/repro/<FINDING_ID>/` when non-obvious (COMMANDS.md, forge.log, notes.md; no secrets). |
| **RUNTIME_UNPROVEN today** | MultiVault / Single SE / Composed / MixedBuffer / Dual / Uni V4 SE / Aave / Hook CP free extract — Stage 3 must prove or demote with evidence. |
| **Static-only High CODE** | May ship with strong static + failing pre-fix tests; still prefer runtime. |

---

## 11. Risks, conflicts, NEEDS_OWNER

### 11.1 Conflicts resolved by this PRD (including owner lock session)

| Conflict | Decision |
|----------|----------|
| Commons High vs product Blocker for same PAT-I-ABS | Wave-0 commons is **Blocker epic** (runtime confirmed). Product e2e remains Blocker until proven. |
| MultiVault “P0 complete” (2026-07) | Stale for I/J/K — extend gold suite; do not rewrite A–H. |
| SingleVault/Seigniorage in old reports | Removed — no live product WPs. |
| Struct-audit vs this program | L-TCA-4 / L-GAPS supersession — one backlog. |
| Credit vs strict exact-delta revert | **L-GAPS-9:** credit `claimed` iff `claimed ≤ delta`; short reverts; **no** exact-delta vault lock via donation. |
| Shared algorithm lib vs package-local | **L-GAPS-12:** package-local delta **algorithm**; **L-GAPS-10:** shared **error** only. |
| Hook leftover spendable by later caller | **L-GAPS-11:** keep design; tests only. Book free-spend remains Blocker CODE. |
| ShareInflation vs I/K on DualLiquidity | ShareInflation is **A3-class BPT only** — never count as I1–I3 or K1 pretransfer. |
| Missing Alchemy for DualLiquidity | **L-GAPS-13:** BUILD_BLOCKED; WP stays open. |
| CODE vs TEST separate worktrees | **L-GAPS-6:** one worktree packs CODE+I+J per package. |

### 11.2 Remaining NEEDS_OWNER (non-blocking for Wave 0/1 pull law)

Stage 3 agents **must not** invent product law. Items below are **out of implementor choice** for pull semantics (already locked). Escalate only if a WP truly cannot proceed:

| Topic | Source | Implementor default (do not invent alternatives) |
|-------|--------|--------------------------------------------------|
| Camelot production fork mandatory (Arbitrum) | SE AC | Ship hermetic High (`WP-H-CAM-001`); do not block Wave 1 on Camelot fork |
| Uni V4 SE-native fork mandatory | SE UAB | Hermetic I suite closes product I; fork optional later |
| FeeCollector permissionless sync/push | manager | **No CODE change** in this program; tests only on money-out (`WP-N-FEE-001`) |
| FeeCollector `pullFee` reserve resync | manager | **No CODE** unless tests prove reserve is security-critical; then escalate |
| ComposedStable nested G1 | composed-stable | If product cannot nest DETF legs, mark G N/A in suite NatSpec with path cite; else implement G1 test |
| Dual hook free residual | hooks | Free-gate unfunded path (CODE in Dual WP); leftover policy follows L-GAPS-11 style tests |
| ERC4626 “still pull when pretransferred” UX | commons | **Out of scope** for this program; delta credit law only (L-GAPS-9) |

---

## 12. Definition of Done (this fix program)

### 12.1 Program checklist

- [ ] All **Blocker** WPs merged with **runtime-backed** acceptance (helper confirmed + product proofs closed or demoted with evidence)
- [ ] All **High** WPs merged or explicitly deferred with severity-preserving reason in execute plan / suite NatSpec
- [ ] All **44** WP-IDs accounted for (merged or deferred)
- [ ] No mock SUT counted as coverage
- [ ] I1–I3 present on every money pretransfer surface touched by this program
- [ ] J1–J3 on every diamond package touched
- [ ] Wave 0 commons landed **before** dependent product I suites on inheritors
- [ ] Conflict-free slices respected; no silent same-file parallel edits
- [ ] Orchestrator never exceeded **3** concurrent implementer subagents
- [ ] `forge test` green on all touched paths; fork paths documented for DualLiquidity (and others as needed)
- [ ] Theater tests that greenwashed free credit removed or inverted
- [ ] No `via_ir`; DETF role names only; registry/CREATE3 deploy law held
- [ ] Worktrees/branches use `gap_cover_` prefix

### 12.2 Per-WP checklist (implementer)

- [ ] Read WP + TCA findings + this PRD §3 / §9
- [ ] Worktree `gap_cover_*` isolated
- [ ] CODE first if CODE/BOTH
- [ ] Acceptance forge command green; evidence in PR/worklog
- [ ] Anti-theater checks from WP record satisfied
- [ ] Touch set only (out-of-scope files untouched)

---

## 13. Handoff to execute plan / Stage 3

### 13.1 Implementer rules (Stage 3)

Implementers must:

1. Read **this PRD** + assigned WP(s) from [`WORK_PACKAGE_BACKLOG.md`](./coverage-audit/WORK_PACKAGE_BACKLOG.md) + linked TCA findings in area reports.
2. Use `gap_cover_*` worktrees/branches only.
3. Fix **CODE first** when class is CODE/BOTH; never greenwash free mint.
4. Stay inside the slice’s production/test touch set.
5. Paste forge evidence in PR/worklog; add repro artifacts when closing formerly RUNTIME_UNPROVEN Blockers.
6. Not open product-law fights — escalate NEEDS_OWNER.

### 13.2 Orchestrator rules (Stage 3)

1. Execute Wave 0 fully before Wave 1 inheritor I suites.
2. Launch **at most three** subagents at a time (L-GAPS-4).
3. Only schedule concurrent slices with **different slice keys** and non-overlapping paths (§8.2).
4. Prefer one worktree owning CODE+I+J for a single product.
5. Merge order: W0 → W1 batches A→F as listed (or equivalent non-conflicting reordering) → W2 → W3 → W4.
6. After each merge, re-verify no touch-set collisions for the next batch.

### 13.3 Prompt for the agent that writes the implementation plan

```text
You are the Stage 2 → Stage 3 execute-plan author for IndexedEx gap closure.

Read and obey:
  docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md          (this PRD — waves, L-GAPS-*, ≤3 concurrency)
  docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md    (44 WPs, full §8 fields)
  docs/testing/coverage-audit/AGGREGATE.md
  docs/testing/TEST_COVERAGE_AUDIT_PRD.md §8 / §13–14

Write:
  docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md

Must include:
  1. Topological merge order of all 44 WPs mapped to conflict-free slice keys from the PRD.
  2. Batched schedule: never more than 3 concurrent worktrees/subagents.
  3. Per-batch: WP-IDs, worktree names (gap_cover_*), branch names, primary production/test paths,
     forge acceptance commands, anti-theater checks, depends-on.
  4. Wave 0 serial commons first; then Wave 1 package CODE; Wave 2 ADV/N/Permit2; Wave 3 property.
  5. Copy-paste subagent prompts (one per slice) that include skills, deploy law, DETF role names,
     and “do not edit outside touch set.”
  6. Runtime proof tasks for each remaining Blocker CODE product.
  7. NEEDS_OWNER escalations list (do not invent economics).
  8. Final program acceptance checklist mirrored from PRD §12.

Do not implement production or permanent test code. Do not open gap_cover_* worktrees.
```

### 13.4 Stage 3 subagent prompt skeleton (for execute plan to expand)

```text
You implement WP-ID(s): <list> in worktree gap_cover_<slice> only.

Laws: TEST_COVERAGE_GAP_CLOSURE_PRD.md + WORK_PACKAGE_BACKLOG entry + linked TCA findings.
Skills: crane-testing, crane-adversarial-testing (+ implementation-test-dod), indexedex-testing,
        indexedex-adversarial-testing [+ hook package skill if hooks].

Hard rules:
- No via_ir; no mock SUT; CREATE3 + registry (or documented hook/router path).
- CODE before green tests if CODE/BOTH; I1 must not transfer; J3 on proxy only.
- DETF roles only; exact selectors; touch set only.
- Run acceptance forge commands; paste evidence.

Out of scope: any file not listed in the WP touch sets.
```

---

## 14. Revision history

| Date | Change |
|------|--------|
| 2026-08-09 | Initial gap-closure PRD from Stage 1 coverage-audit (2026-08-09 run): 8 epics, 44 WPs, waves 0–4, conflict-free slices, orchestrator max 3 concurrent subagents (L-GAPS-1…8). |
| 2026-08-09 | Owner lock session: L-GAPS-9 delta credit; L-GAPS-10 shared short-delivery error; L-GAPS-11 hook leftover tests-only; L-GAPS-6/12/13 packing, package-local algorithm, fork BUILD_BLOCKED. |

---

## Appendix A — Finding → WP traceability (Blocker/High)

All **69** IDs are indexed in [`WORK_PACKAGE_BACKLOG.md`](./coverage-audit/WORK_PACKAGE_BACKLOG.md) § “Finding → WP index”. Summary by epic:

| Theme | Finding IDs (representative) | Primary WPs |
|-------|------------------------------|-------------|
| Commons free credit | TCA-COMMON-001…005 | WP-I-COMMON-001/002, WP-I-CLONE-001, WP-I-CLAIM-001 |
| MultiVault | TCA-DETF-MV-001…005 | WP-I-DETF-MV-001/002, WP-J-DETF-MV-001, WP-K-DETF-MV-001 |
| Single SE DETF | TCA-DETF-SSE-001…009 | WP-I-DETF-SSE-001/002/CP/UV4, WP-J-DETF-SSE-* |
| Composed/MixedBuffer | TCA-DETF-CS-001…011 | WP-I-DETF-CS/MB-*, WP-J-DETF-CS-MB-001, WP-ADV-DETF-MB-001, WP-G-E-DETF-CS-001 |
| DualLiquidity | TCA-DETF-DL-001…005 | WP-I-DETF-DL-001/002, WP-J-DETF-DL-001 |
| SE Aero/Cam/V2 | TCA-SE-AC-001…008 | WP-I-COMMON-001, WP-I-SE-AC-001, WP-J-SE-AC-001, WP-ADV-SE-AC-001, WP-H-CAM-001, WP-E5-AERO-001 |
| SE UniV4/Aave | TCA-SE-UAB-001…010 | WP-I-CLONE-UAB-001, WP-I-SE-UAB-001, WP-ADV-SE-UAB-001, WP-J-SE-UAB-001, WP-J-ROUTER-UAB-001 |
| Hooks | TCA-HOOK-001…009 | WP-I-HOOK-CP/DUAL/SEBUF-001, WP-J-HOOK-001, WP-ADV-HOOK-001 |
| Manager/fee | TCA-MGR-001…003 | WP-J-MGR-001/002, WP-N-FEE-001 |
| Routers | TCA-RTR-001…003 | WP-I5-RTR-001, WP-N-RTR-001, WP-J-RTR-001 |
| Removed products residual | TCA-DETF-SVS-003 | WP-I-CLAIM-001 only |

---

## Appendix B — Quality self-check (author)

| Check | Status |
|-------|--------|
| Traceability: every Blocker theme from aggregate under an epic | Pass |
| All 44 WP-IDs listed in §7.5 | Pass |
| Wave 0 commons serial and first | Pass (L-GAPS-1) |
| Runtime confirmed helper cited; unproven products require proof tasks | Pass (§10) |
| Anti-theater I1 + J3 explicit | Pass (§3) |
| Deploy law registry + CREATE3 | Pass (§3.5) |
| DETF role names only | Pass |
| Removed SingleVault/Seigniorage not live | Pass (§5.2) |
| Actionability without re-reading all 11 areas end-to-end | Pass (PRD + backlog + TCA index) |
| Merge-conflict slices + ≤3 concurrency | Pass (L-GAPS-3/4, §8.2) |
