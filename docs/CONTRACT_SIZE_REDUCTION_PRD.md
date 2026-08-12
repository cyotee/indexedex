# Product Requirements Document (PRD)

## Title

**Contract Size Reduction (EIP-170 Deployability)** — bring all production IndexedEx **Facets** under the EVM runtime bytecode limit via facet splits first, external libraries second (no business-logic efficiency refactors in this program)

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **READY-FOR-IMPLEMENTATION** — open items **LOCKED 2026-08-11** (§1.1); authorizes implementation plan + CODE |
| **Kind** | Engineering / deployability PRD (runtime size, diamond packaging, bytecode layout) |
| **Date** | 2026-08-11 |
| **Last clarified** | 2026-08-11 — owner decisions §1.1 |
| **Baseline measurement** | `yarn sizes` → `SIZES.log`; inventory → `OVERSIZE_CONTRACTS.log` |
| **Hard limit** | EIP-170 **runtime** code size ≤ **24,576** bytes (24 KiB) — **hard gate only** (no soft headroom requirement) |
| **Initcode limit** | EIP-3860 **initcode** ≤ **49,152** bytes — current oversize list is **runtime-bound**, not initcode-bound |
| **Hard constraints** | **`via_ir` forbidden**; Crane CREATE3 / FactoryService / vault-registry DFPkg paths; production-first tests; DETF role names; no `new` for facets/DFPkgs |
| **Primary skills** | `crane-architecture`, `crane-deployment`, `crane-code-style`, `crane-testing`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` |
| **Related prior art** | `PLAN_facet_split.md` (Protocol DETF view/execute split — **done**); Single SE CP Buffer Hook multi-Target pattern (deposit / withdraw / se); Weighted Buffer partial Target split (hooks / se / liquidity) |
| **Follow-on** | [`CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md`](./CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md) — execute Waves 0–7; this PRD remains law only |

### 1.1 Locked product / engineering decisions (owner-clarified 2026-08-11)

These override any earlier “default if silent” / open-question language in this document.

| ID | Decision | Law |
|----|----------|-----|
| **L-SIZE-HARD** | **Hard gate only:** runtime ≤ **24,576** bytes. No soft headroom target (not 1 KiB, not 2 KiB). | Any non-negative runtime margin is enough to ship a Facet. |
| **L-SIZE-SCOPE** | Clear **all product contracts** in the oversize inventory for this program (phased waves OK). | Full `OVERSIZE_CONTRACTS.log` family set; not a launch-only subset. |
| **L-SIZE-FACET-GATE** | **Size gate applies to Facets** (and other independently CREATE3-deployed package components). | **Ignore Target-only artifact sizes** in `SIZES.log` for G1. Targets still **must be split/thinned as needed** so inheriting Facets compile under the limit — but a standalone oversized Target artifact is not a ship blocker if no Facet inherits that full body into a deployable unit. |
| **L-SIZE-OPT1** | When both Option 1 (more Facets) and Option 2 (external libs) can clear the limit, **prefer more Facets**. | Gas-neutral packaging first; Option 2 only if Facet splits alone fail or DFPkg wiring is unreasonable. |
| **L-SIZE-NEAR** | **Near-miss Facets are out of scope** (margin 0–2 KiB, e.g. Single SE CP Deposit ~+308 B). | Do not schedule preemptive splits; do not make them worse if touching shared bases. |
| **L-SIZE-GAS** | **No gas measurement required** for Option 2. | Size win is sufficient; agents need not run gas reports or enforce % caps. |
| **L-SIZE-VENDOR** | Vendored protocol + test-only oversize (**out of scope**). | No effort on `VaultMock`, Balancer `Vault`, `*TestDeployLib`, NPM, Morpho factories, etc. |
| **L-SIZE-SURFACE** | **Stable selectors + semantics; new Facets OK.** | Keep existing diamond selectors and behavior; additive Facet cuts / packaging allowed pre-launch. |
| **L-SIZE-OPT3** | **Option 3 (business-logic efficiency refactors) is never in this program.** | Size work is packaging (Option 1) and external libraries/delegates (Option 2) only. |
| **L-SIZE-ENFORCE** | Success enforcement: **`yarn sizes` + empty product Facet oversize list**. | No CI size gate required in this program; regenerate `OVERSIZE_CONTRACTS.log` (or equivalent) with zero in-scope Facets over limit. |

---

## 2. Intent & problem statement

### 2.1 Problem

Several production IndexedEx contracts **compile** under the default Foundry profile but produce **runtime bytecode larger than 24,576 bytes**. They cannot be deployed to any live EVM chain that enforces EIP-170 (mainnet, L2s, public testnets, and most Anvil-equivalent production-shaped envs).

Baseline inventory (from `OVERSIZE_CONTRACTS.log` + parsed `SIZES.log`):

| Contract | Runtime (B) | Runtime margin (B) | Family |
|----------|------------:|-------------------:|--------|
| `UniswapV4StandardExchangeOrbitalBufferHookHooksFacet` | 46,457 | −21,881 | Uni V4 SE Orbital Buffer Hook |
| `UniswapV4StandardExchangeOrbitalBufferHookDepositFacet` | 44,442 | −19,866 | Uni V4 SE Orbital Buffer Hook |
| `UniswapV4StandardExchangeOrbitalBufferHookSeFacet` | 44,331 | −19,755 | Uni V4 SE Orbital Buffer Hook |
| `UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet` | 44,278 | −19,702 | Uni V4 SE Orbital Buffer Hook |
| `UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet` | 41,471 | −16,895 | Uni V4 SE Weighted Buffer Hook |
| `UniswapV4WeightedSwapHookHooksFacet` | 37,320 | −12,744 | Uni V4 Weighted Swap Hook |
| `UniswapV4WeightedSwapHookLiquidityFacet` | 36,079 | −11,503 | Uni V4 Weighted Swap Hook |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet` | 35,907 | −11,331 | Uni V4 SE Curve Quad Stable Buffer Hook |
| `UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet` | 32,905 | −8,329 | Uni V4 Dual SE CP Buffer Hook |
| `UniswapV4StandardExchangeWeightedDETFFacet` | 31,831 | −7,255 | Uni V4 Weighted DETF |
| `UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet` | 31,437 | −6,861 | Uni V4 Dual SE CP Buffer Hook |
| `UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet` | 31,145 | −6,569 | Uni V4 Dual SE CP Buffer Hook |
| `UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet` | 31,054 | −6,478 | Uni V4 Dual SE CP Buffer Hook |
| `MultiVaultWeightedDetfExchangeInFacet` | 29,513 | −4,937 | Balancer V3 Multi-Vault Weighted DETF |
| `AerodromeStandardExchangeOutFacet` | 29,386 | −4,810 | Aerodrome SE Out |
| `AerodromeStandardExchangeOutTarget` | 28,795 | −4,219 | Aerodrome SE Out (Target; inherited by Facet) |
| `UniswapV4StandardExchangeOutFacet` | 28,547 | −3,971 | Uni V4 SE Out |
| `MixedBufferMultiVaultStableDetfExchangeInFacet` | 28,438 | −3,862 | Balancer V3 Mixed-Buffer Multi-Vault Stable DETF |
| `UniswapV4StandardExchangeOutTarget` | 27,995 | −3,419 | Uni V4 SE Out (Target; inherited by Facet) |
| `UniswapV4StandardExchangeOrbitalDETFFacet` | 26,773 | −2,197 | Uni V4 Orbital DETF |

**Count:** 20 names in baseline `OVERSIZE_CONTRACTS.log` (18 **Facets** + 2 **Targets** that Facets inherit).

**G1 ship set (L-SIZE-FACET-GATE):** the **18 Facets** in that list. The two Target rows (`AerodromeStandardExchangeOutTarget`, `UniswapV4StandardExchangeOutTarget`) are **diagnostic inheritance sources** — shrink/split their bodies only as required so Out Facets deploy; Target artifact size alone does not block ship.

**Not in `OVERSIZE_CONTRACTS.log` but same `SIZES.log` run:** many vendored / test-only artifacts also exceed the limit (`VaultMock`, Balancer `Vault`, Morpho factories, Uniswap `NonfungiblePositionManager`, package `*TestDeployLib`, etc.). Those are **out of scope** (L-SIZE-VENDOR).

### 2.2 Why this happens (structural root causes)

IndexedEx diamonds route selectors to **Facets**. Facets are thin `IFacet` shells that **inherit** one or more **Targets**. Solidity compiles **all inherited bytecode into each Facet**, even when `facetFuncs()` only exposes a subset of selectors.

Observed patterns that drive oversize:

| Pattern ID | Description | Evidence |
|------------|-------------|----------|
| **P1 — Monotarget inheritance** | Multiple role Facets each inherit the **same** mega-Target | Orbital Buffer: four Facets all inherit `UniswapV4StandardExchangeOrbitalBufferHookTarget` (~2,573 lines / ~174 funcs). Dual SE CP: four Facets all inherit one ~1,693-line Target. Result: deposit facet ships withdraw+hooks+SE code it never exposes. |
| **P2 — Combined lifecycle Facet** | One Facet multi-inherits exchange + bond + info (+ query) Targets | `MultiVaultWeightedDetfExchangeInFacet` comment: *“Combined facet for exchange/bond/info/query (split later if size requires).”* Same shape for MixedBuffer. |
| **P3 — Deep inheritance tower** | `BondingTarget` → `ExchangeInTarget` → `ExchangeOutTarget` → fat `Common` | Weighted/Orbital DETF lifecycle Facets inherit Bonding, which already pulls in full mint/burn/exchange + Common helpers (~900+ line Commons). |
| **P4 — Fat Common / shared base** | Thin Target inherits multi-thousand-line Common used by In **and** Out | `UniswapV4StandardExchangeCommon` ~1,126 lines; `AerodromeStandardExchangeCommon` ~844 lines; Out path pays for In helpers and vice versa when both live in one inheritance tree. |
| **P5 — Route-matrix bloat** | Few external entrypoints, many parallel route bodies + preview duplicates | Aerodrome Out: 7-route matrix duplicated across `previewExchangeOut` and `exchangeOut` (~1,138-line Target). |
| **P6 — Partial split incomplete** | Package already has multi-Facet cuts, but one Target remains too large | Weighted Buffer: Hooks/Se Facets are **under** limit (~20–21 KiB); **Liquidity** alone is 41 KiB with **32** selectors (join/exit × proportional/single/flexible × preview/execute). |
| **P7 — Error / string / ABI noise** | Large custom error sets, duplicated validation, unused public surface | Secondary; rarely the sole cause of multi-10KB overshoot, but contributes after primary splits. |

### 2.3 Goals

1. **Deployability:** Every in-scope production **Facet** (and other independently CREATE3-deployed package component that appears on the product oversize list) has **runtime margin ≥ 0** after the program (L-SIZE-HARD). No soft headroom target.
2. **Preserve product law:** No change to DETF economics, thresholds, bond/claim maturity, SE accounting semantics, or hook pricing law unless required by a size fix and explicitly called out.
3. **Prefer gas-neutral layout changes:** Facet/Target splits that only change **which contract holds bytecode**, not **how many external calls users make** (L-SIZE-OPT1).
4. **Option 2 only when needed:** external libraries / delegate helpers when Option 1 alone cannot clear EIP-170 (or packaging is unreasonable). **No gas measurement gate** (L-SIZE-GAS).
5. **No Option 3** in this program (L-SIZE-OPT3).
6. **Keep diamond UX:** Users still call the **diamond address**; existing selectors/semantics stable; new Facets allowed (L-SIZE-SURFACE); DFPkg / FactoryService wires facets via CREATE3.
7. **Measurable regression gate:** `yarn sizes` shows zero in-scope **Facet** negative margins; product oversize list empty for Facets; tests for affected packages remain green on production-first TestBases (L-SIZE-ENFORCE).

### 2.4 Non-goals

- Enabling `via_ir` / IR-only compilation tricks.
- Soft headroom campaigns or preemptive near-miss Facet splits (L-SIZE-NEAR).
- **Option 3** business-logic efficiency refactors (L-SIZE-OPT3).
- Gas reports / % caps for Option 2 (L-SIZE-GAS).
- Shrinking **vendored** third-party contracts or pure **test** deploy libs / mocks (L-SIZE-VENDOR).
- Treating **Target-only** artifact sizes as ship blockers when Facets that use thinner Targets are already under limit (L-SIZE-FACET-GATE).
- Changing frontend ABIs beyond additive facet packaging (selector set on diamond may grow via new facets; existing selectors remain stable — L-SIZE-SURFACE).
- Storage layout redesign for its own sake (allowed only if inseparable from a size fix and gated by pre-launch storage tests).
- Full economic re-architecture of orbital/weighted math.
- Replacing Diamond with non-Crane patterns.
- CI enforcement of size limits (optional later; not required by L-SIZE-ENFORCE).

### 2.5 Success definition

| Gate | Criterion |
|------|-----------|
| **G1 Hard size** | No in-scope **Facet** (or independently CREATE3-deployed product component on the oversize list) with runtime size > 24,576 after `yarn sizes` (L-SIZE-HARD, L-SIZE-FACET-GATE) |
| **G2 Behavior** | Existing package TestBases / Behavior suites for touched families pass (hermetic default profile) |
| **G3 Deploy path** | DFPkg `facetAddresses` / `facetCuts` / FactoryService CREATE3 deploy methods updated; no `new` facet deploy |
| **G4 Inventory** | Product Facet oversize list empty (`OVERSIZE_CONTRACTS.log` regenerated with zero in-scope Facets over limit) (L-SIZE-ENFORCE) |
| **G5 Documentation** | Per-family size before/after table for Facets; updated component docs if facet inventory changes |

---

## 3. Definitions

| Term | Meaning |
|------|---------|
| **Runtime size** | Deployed contract code size (EIP-170) |
| **Initcode size** | Creation bytecode size (EIP-3860) |
| **Runtime margin** | `24,576 − runtime size` (negative = undeployable) |
| **Target** | Abstract/logic contract holding product functions; usually not the CREATE3 product alone |
| **Facet** | Deployable contract implementing `IFacet` + inheriting Target(s); diamond cut target |
| **Common** | Shared base with views/helpers used by multiple Targets |
| **Monotarget** | Single Target inherited by multiple role Facets (P1) |
| **Option 1 — Facet/Target split** | Move selectors + their implementing Target code into separate deployable Facets so each Facet’s bytecode only includes what it needs |
| **Option 2 — External library / delegate** | Move pure/view or self-contained logic into `library` (external functions) or a CREATE3 helper/delegate contract; Facet `DELEGATECALL`/`CALL`s it |
| **Option 3 — Logic efficiency** | Rewrite algorithms / collapse routes for smaller codegen — **out of program** (L-SIZE-OPT3); defined only so agents do not invent it as a third path |
| **View/execute split** | Special case of Option 1: previews/getters on Query Facet; state-changing ops on Execute Facet (Protocol DETF pattern) |
| **Role split** | Option 1 by domain: deposit / withdraw / hooks / SE / bond / info / liquidity |

---

## 4. Hard constraints (non-negotiable)

1. **`via_ir = false`** remains forbidden on default / CI / shared profiles. Size work must not reintroduce stack-too-deep that is only fixable by IR; use helpers/structs per Crane code style.
2. **Never `new` facets or DFPkgs.** Facets via CREATE3 / `*FactoryService`; vault & DETF packages via IndexedEx manager vault registry (`indexedexManager.deploy*DFPkg` / registry path).
3. **Production-first tests.** No mocks of SUT (vaults, DETF, manager, registry, fee oracle, facets, DFPkgs). Prefer gold TestBases: `CraneTest` → `IndexedexTest` → protocol TestBase.
4. **DETF role names only** in new code and docs (`rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`).
5. **Public diamond selectors** for existing money paths should remain reachable at the same diamond address with the **same selector** after cuts (additive new facets OK; renames only with explicit migration note).
6. **Hook flag / address mining** for Uni V4 hooks must remain valid after facet packaging changes (CREATE3 salt / flag bits / package mining law unchanged unless a package PRD already allows it).
7. **Do not silently change** fee, threshold, bond maturity, claim, or reserve accounting semantics while shrinking bytecode.

---

## 5. Scope

### 5.1 In scope (mandatory)

All contracts listed in `OVERSIZE_CONTRACTS.log` and their **owning packages**:

| Priority band | Packages / contracts | Why first |
|---------------|----------------------|-----------|
| **P0 Critical** | Uni V4 SE **Orbital** Buffer Hook (4 Facets); Uni V4 SE **Weighted** Buffer Liquidity Facet; Uni V4 **Weighted Swap** Hook (Hooks + Liquidity) | Largest overshoot; monotarget / fat liquidity Targets |
| **P0 Critical** | Uni V4 SE **Dual** CP Buffer Hook (4 Facets); Uni V4 SE **Curve Quad Stable** Liquidity Facet | Same monotarget / fat liquidity patterns; product hook packages |
| **P1 High** | Uni V4 **Weighted DETF** Facet; Uni V4 **Orbital DETF** Facet | Deep Bonding inheritance towers |
| **P1 High** | **MultiVaultWeighted** + **MixedBuffer** DETF combined Facets | Explicit combined Facets; Targets already separated |
| **P1 High** | **Aerodrome** SE Out Facet; **Uni V4** SE Out Facet | Classic SE vault Out routes; Out Target bodies are the inheritance size source (Facet is the gate) |

### 5.2 Out of scope (unless later promoted)

- Vendored protocol bytecode (Aave, Morpho, Balancer Vault/Router, Uniswap NPM/Factory, VotingEscrow, etc.)
- Test-only `*TestDeployLib`, `*Mock`, harnesses that are never CREATE3-deployed as product
- Frontend, scripts inventory cleanup unrelated to facet wiring
- New product features not required for size reduction

### 5.3 Measurement process (normative)

```bash
# From repo root (indexedex)
yarn sizes
# Produces / updates SIZES.log via: forge compile --sizes | tee SIZES.log

# Maintain OVERSIZE_CONTRACTS.log as the list of *IndexedEx product* names with negative runtime margin
# (exclude pure vendored/test names unless they are on the product deploy path)
```

Implementation agents **must** re-run `yarn sizes` after each family wave and record before/after runtime sizes.

---

## 6. Strategy ladder (normative decision order)

For **each** oversized **Facet**, implementers must apply strategies in this order. Skipping Option 1 for Option 2 requires a short written justification in the implementation plan (e.g. “monotarget already role-split; Liquidity still 41 KiB → Option 2 for weighted math”). **Option 3 is forbidden** (L-SIZE-OPT3).

### 6.1 Option 1 — Separate large functions / selector groups into Facet (+ Target) contracts **(preferred)**

**Intent:** Change **bytecode packaging**, not runtime call graphs for users. Diamond `delegatecall` to facet A vs facet B is the same cost class as today.

**Techniques:**

| Technique | When to use | Runtime gas impact |
|-----------|-------------|--------------------|
| **1a Role Target split** | Monotarget packages (Orbital, Dual): create `*DepositTarget`, `*WithdrawTarget`, `*HooksTarget`, `*SeTarget` (or finer); each Facet inherits only its Target + thin shared Common | **Neutral** (same diamond delegatecall) |
| **1b View / execute split** | Preview + execute share large internal trees (Protocol DETF pattern; Aerodrome/UniV4 Out previews) | **Neutral** for execute path if previews move out |
| **1c Lifecycle facet split** | Combined DETF Facets: separate Bonding / ExchangeIn / ExchangeOut / Info / Query Facets; stop multi-inheriting all Targets into one Facet | **Neutral** |
| **1d Liquidity surface split** | Weighted / Curve liquidity: e.g. JoinFacet vs ExitFacet, or CoreJoin vs FlexibleJoin, or Proportional vs SingleAsset | **Neutral** |
| **1e Break inheritance towers** | DETF: do **not** make Bonding inherit ExchangeIn inherit ExchangeOut; siblings inherit Common only; Facet multi-inherits **only** what it exposes | **Neutral** if Facet still multi-inherits; **win** when Facet inherits a single thin Target |

**Rules for Option 1:**

1. Shared helpers needed by multiple Targets may live in a **thin Common** (prefer views/storage accessors only) **or** be **duplicated** sparingly when duplication is cheaper than pulling a fat base (Protocol DETF accepted limited duplication).
2. `facetFuncs()` / `facetInterfaces()` / FactoryService / DFPkg cuts **must** stay consistent with the new Target ownership.
3. Internal helpers used only by one role **must not** remain on a base inherited by other roles.
4. Prefer matching existing package patterns:
   - Single SE CP Buffer: separate Deposit / Withdraw / Se Targets
   - Weighted Buffer: Hooks / Se / Liquidity Targets (extend this pattern further)
   - Protocol DETF: Query vs Execute Facets

### 6.2 Option 2 — Externalize business logic to libraries / delegates **(acceptable gas increase)**

**Intent:** Move large pure math, quote graphs, or multi-step internals out of the Facet’s runtime code.

**Techniques:**

| Technique | Gas impact | Notes |
|-----------|------------|-------|
| **2a `external` library functions** | Extra `DELEGATECALL` (~100+ gas class + calldata) | Prefer for pure/view math (sphere, weighted joins, stable invariant). Existing `*Math.sol`, `*ClaimLib.sol`, `*PullLib.sol`, `*LiquidityLib.sol` already start this; many are still **internal**-linked and inlined. |
| **2b CREATE3 ExecutionDelegate / helper** | Extra `CALL` + auth check | Pattern: `UniswapV4StandardExchangeInExecutionDelegate`. Use when library linkage still leaves Facet oversize or when stateful multi-step helpers need isolation. |
| **2c Split pure math packages** | Same as 2a | Curve stable / orbital sphere / weighted math are prime candidates once Option 1 exhausts role splits. |

**Rules for Option 2:**

1. Libraries that should shrink Facet size must expose **`external`** (or be separate contracts). `internal` library functions are **inlined** and **do not** reduce Facet size.
2. **No gas measurement or gas-cap gate** (L-SIZE-GAS). Optional notes are fine but not required.
3. Trust model: diamond-only callers for delegates; no user-facing open entry that mutates vault storage without the same guards as today.
4. Still CREATE3-deploy helpers via FactoryService where they are package components.

### 6.3 Option 3 — **Out of program** (L-SIZE-OPT3)

**Do not** refactor business logic solely for smaller codegen in this program (no route-matrix unifications that change structure of formulas, no “more efficient” algorithm rewrites, no flexible/non-flexible path merges for size).

If Options 1 and 2 still cannot clear a Facet, **stop and escalate** to the owner rather than inventing Option 3 work. Packaging may still move code between contracts without changing formulas (that remains Option 1 / 2).

---

## 7. Per-family diagnosis & recommended strategy

### 7.1 Uni V4 SE Orbital Buffer Hook (P0)

| Item | Detail |
|------|--------|
| **Contracts** | Hooks / Deposit / Se / Withdraw Facets (all ~44–46 KiB) |
| **Source of bloat** | **P1 Monotarget:** all Facets inherit `UniswapV4StandardExchangeOrbitalBufferHookTarget` (~2.5k lines: hooks + sphere swap + multipath LP + flexible SE + SE In/Out + views) |
| **Already present** | Math / Claim / PairPool libs; four Facet cuts exist but **do not isolate bytecode** |
| **Option 1 plan** | Split Target into at least: `HooksTarget`, `DepositTarget`, `WithdrawTarget`, `SeTarget` (+ optional `ViewsTarget` / query facet). Thin `OrbitalBufferHookCommon` for bindings, reserve sync, lock, buffer/unwrap primitives. Mirror Single SE CP + Weighted multi-Target layout. |
| **Option 2 plan** | If any **Facet** still over limit after role Targets: externalize sphere swap quote/execute math and multipath LP compute to `external` Math/Liquidity libs |
| **Expected win** | Role isolation alone should drop each Facet toward the size of its role subset (often well under 24 KiB if Common stays thin) |

### 7.2 Uni V4 Dual SE CP Buffer Hook (P0)

| Item | Detail |
|------|--------|
| **Contracts** | Hooks / Deposit / Se / Withdraw Facets (~31–33 KiB) |
| **Source of bloat** | **P1** single `...HookTarget` (~1.7k lines) inherited by all four Facets |
| **Option 1 plan** | Same multi-Target split as Single SE CP / Orbital; package already has Claim/Math/Pull libs |
| **Option 2** | Externalize zap split / CP quote cores if needed |
| **Note** | Smaller overshoot than Orbital → Option 1 likely sufficient |

### 7.3 Uni V4 SE Weighted Buffer Hook — Liquidity (P0)

| Item | Detail |
|------|--------|
| **Contract** | `...WeightedBufferHookLiquidityFacet` (~41 KiB) |
| **Source of bloat** | **P6:** LiquidityTarget (~1k lines) exposes **32** selectors: proportional/unbalanced/single/flexible join+exit × preview/execute |
| **Already OK** | Hooks Facet (~20.7 KiB), Se Facet (~21.1 KiB) |
| **Option 1 plan** | Split Liquidity into e.g. **JoinFacet** + **ExitFacet**, and/or **CoreLiquidityFacet** + **FlexibleLiquidityFacet** (flexible SE-share paths are a large distinct surface). Optionally view/execute split if still tight. |
| **Option 2 plan** | Make `WeightedBufferHookLiquidityLib` / Math **`external`** for join/exit quotes and commit helpers |
| **Reference** | Curve Quad Liquidity Facet has the same disease at ~36 KiB — apply the same template |

### 7.4 Uni V4 SE Curve Quad Stable Buffer Hook — Liquidity (P0)

| Item | Detail |
|------|--------|
| **Contract** | `...CurveQuadStableBufferHookLiquidityFacet` (~36 KiB) |
| **Source of bloat** | Fat LiquidityTarget (~1k lines) similar to Weighted |
| **Option 1 / 2** | Same join/exit or core/flexible split; external stable math library if needed |
| **Compare** | Balancer Quad Stable Buffer Liquidity is **under** limit (~22 KiB) — use as structural reference for successful packaging |

### 7.5 Uni V4 Weighted Swap Hook (P0)

| Item | Detail |
|------|--------|
| **Contracts** | HooksFacet (~37 KiB), LiquidityFacet (~36 KiB) |
| **Source of bloat** | Large `UniswapV4WeightedSwapHookTarget` (~1.2k lines) + liquidity surface; Hooks Facet inherits full Target |
| **Option 1 plan** | Ensure Hooks vs Liquidity use **separate Targets** (if not already fully isolated); further split liquidity; move pure weighted math to external lib |
| **Option 2** | External math / pair-pool libs as `external` |

### 7.6 Uni V4 Weighted DETF + Orbital DETF lifecycle Facets (P1)

| Item | Detail |
|------|--------|
| **Contracts** | `UniswapV4StandardExchangeWeightedDETFFacet` (~32 KiB), `...OrbitalDETFFacet` (~27 KiB) |
| **Source of bloat** | **P3:** `BondingTarget` inherits `ExchangeInTarget` inherits `ExchangeOutTarget` inherits fat `Common` (~900 lines). Lifecycle Facet inherits Bonding → entire tower. |
| **Already present** | Separate Info Facets exist and are healthy pattern |
| **Option 1 plan** | Break tower: ExchangeIn / ExchangeOut / Bonding / Compound Targets as **siblings** of Common. Lifecycle Facet should **not** inherit the full tower if size still exceeds — prefer separate **ExchangeFacet**, **BondingFacet**, **CompoundFacet** (view/execute as needed). Keep InfoFacet separate. |
| **Option 2** | Externalize compound/expansion helpers if still over after splits |
| **Compare** | Single SE DETF Facet margins are positive (~+1–3 KiB) — use as target packaging shape |

### 7.7 MultiVault Weighted + MixedBuffer Stable DETF (P1)

| Item | Detail |
|------|--------|
| **Contracts** | `MultiVaultWeightedDetfExchangeInFacet` (~29.5 KiB), `MixedBufferMultiVaultStableDetfExchangeInFacet` (~28.4 KiB) |
| **Source of bloat** | **P2:** one Facet multi-inherits Query + Bonding + Info Targets (33 selectors on MultiVault) |
| **Option 1 plan (primary)** | Split into at least: **Exchange(In/Out) Facet**, **Bonding Facet**, **Info Facet**, optional **Query Facet** — Targets **already exist**; this is mostly packaging + DFPkg cuts + FactoryService. Source comment already anticipates this. |
| **Option 2** | Unlikely needed if splits are complete |

### 7.8 Aerodrome Standard Exchange Out (P1)

| Item | Detail |
|------|--------|
| **Contracts** | OutFacet (~29 KiB) — OutTarget listed in baseline log as inheritance source only (L-SIZE-FACET-GATE) |
| **Source of bloat** | **P5 + P4:** 7-route Out matrix with preview/execute duplication; inherits Aerodrome Common |
| **Option 1 plan** | View/execute split: `OutQueryTarget/Facet` (previews) + `OutTarget/Facet` (stateful). Optionally split vault-withdraw routes vs pass-through swap routes into two execute Facets if still over. |
| **Option 2 plan** | Externalize route quote helpers / ConstProd zap math as `external` library |

### 7.9 Uniswap V4 Standard Exchange Out (P1)

| Item | Detail |
|------|--------|
| **Contracts** | OutFacet (~28.5 KiB) — OutTarget listed in baseline log as inheritance source only (L-SIZE-FACET-GATE) |
| **Source of bloat** | OutTarget is smaller in source (~363 lines) but inherits **fat** `UniswapV4StandardExchangeCommon` (~1.1k lines) shared with In paths; zap-out + position burn logic |
| **Existing pattern** | `UniswapV4StandardExchangeInExecutionDelegate` already externalizes some In zap execution |
| **Option 1 plan** | Split Common into Out-only vs In-only helpers so Out Facet does not pull In bytecode; view/execute split for Out if needed |
| **Option 2 plan** | Extend ExecutionDelegate pattern for zap-out / position liquidity burn |

---

## 8. Cross-cutting work (all families)

### 8.1 Package / deploy wiring checklist

For every new Facet:

1. Add CREATE3 deploy method on package `*_FactoryService` / component factory
2. Extend DFPkg `PkgInit` / constructor immutables / `facetAddresses` / `facetCuts` / interfaces
3. Update manager registry deploy helpers if the package is vault-registry registered
4. Update Script stages / anvil deploy scripts that construct PkgInit
5. Update TestBase facet expectations / diamond cut assertions if any hardcode facet counts
6. Update `docs/components/*` only if component docs list facet inventories

### 8.2 Compiler / size hygiene (allowed under Options 1–2)

| Practice | Effect |
|----------|--------|
| Prefer custom errors over string reverts | Smaller |
| Avoid unused public/external helpers on Facets | Smaller |
| Avoid fat constructors on Facets | Initcode (usually not binding here) |
| Do not enable IR | Hard constraint |
| Prefer `calldata` over `memory` where it does not hurt stack | Minor size/gas |
| Do not “fix” size by deleting security checks | Forbidden |

### 8.3 Near-miss policy

**Out of scope** (L-SIZE-NEAR). Do not schedule preemptive splits for Facets that already have non-negative margin. When editing shared Commons, avoid regressions that push a previously green Facet over 24,576 (verify with `yarn sizes` on touched packages).

---

## 9. Testing & verification requirements

### 9.1 Size verification

```bash
yarn sizes
# Assert: every in-scope Facet has Runtime Margin ≥ 0
# Target-only artifacts may still appear large; they are not G1 blockers (L-SIZE-FACET-GATE)
# Record table: Facet → before RT → after RT → margin
```

### 9.2 Behavioral verification (production-first)

| Layer | Requirement |
|-------|-------------|
| Package TestBases | Existing hermetic suites for each touched package remain green |
| Selector surface | Diamond still exposes required selectors; optional explicit test that `facetAddress(selector)` maps to the intended new facet |
| Preview ↔ execute | Where view/execute split: previews still match execute outcomes within existing tolerances |
| Adversarial / reentrancy | Do not drop reentrancy locks or access checks when moving code |
| Fork (optional) | Only if hermetic cannot exercise a path; `FOUNDRY_PROFILE=fork` |

### 9.3 Gas verification

**Not required** (L-SIZE-GAS). Agents may skip gas reports and % caps for both Option 1 and Option 2.

### 9.4 Forbidden verification shortcuts

- Mocking vaults / DETF / manager / facets under test
- Claiming size win from `internal` library moves without re-measuring **Facet** runtime size
- Disabling tests to “pass” deployability
- Performing Option 3 logic refactors under another name

---

## 10. Phasing recommendation (for the implementation plan)

The implementation plan (follow-on) should sequence work so each wave is independently mergeable and measurable:

| Wave | Scope | Primary option | Exit criteria |
|------|-------|----------------|---------------|
| **W0** | Tooling: script or checklist to parse `SIZES.log` → product Facet oversize list; baseline table frozen in plan | — | Reproducible Facet inventory |
| **W1** | MultiVault + MixedBuffer DETF Facet packaging splits | **1c** | Both Facets under limit |
| **W2** | Dual SE CP Hook monotarget → multi-Target | **1a** | All 4 Dual Facets under limit |
| **W3** | Orbital Buffer Hook monotarget → multi-Target (+ libs if needed) | **1a → 2a** | All 4 Orbital Facets under limit |
| **W4** | Weighted Buffer Liquidity + Curve Quad Liquidity + Weighted Swap Hook splits | **1d → 2a** | Liquidity/Hooks Facets under limit |
| **W5** | Weighted + Orbital DETF lifecycle tower break / facet split | **1e / 1c** | DETF Facets under limit |
| **W6** | Aerodrome Out + Uni V4 SE Out | **1b → 2b** | Out **Facets** under limit |
| **W7** | Docs + final `yarn sizes` gate; regenerate product Facet oversize list empty | — | G1–G5 |

Waves may parallelize across families **after** W0 if worktrees do not thrash the same Common bases.

---

## 11. Risks & mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Facet cut mismatch (selector missing / wrong facet) | User calls revert | Diamond selector tests; DFPkg facetFuncs audit |
| Shared internal used by two roles after split | Compile fail or duplicated subtle divergence | Thin Common for true shared storage accessors; parity tests for previews |
| External library storage context wrong | Critical funds risk | Prefer `DELEGATECALL` libraries; avoid `CALL` into code that assumes diamond storage unless explicitly designed |
| Hook address / flags change | Pool attach break | Do not change CREATE3 salts/flags; only facet code bodies |
| Stack-too-deep after extracting helpers | Build fail without IR | Crane struct/helper patterns; no IR |
| Scope creep into logic redesign | Delay + correctness risk | **L-SIZE-OPT3:** Option 3 forbidden; escalate if 1+2 cannot clear size |
| Cold compile time | Agent impatience | Follow monorepo forge patience / cache seed rules |

---

## 12. Acceptance criteria (PRD-level)

This PRD is satisfied when a follow-on implementation plan can be executed such that:

1. **G1–G5** in §2.5 are met for the in-scope **Facet** set.
2. Strategy ladder in §6 was followed per family (Option 1 before Option 2; **no Option 3**).
3. No `via_ir`; CREATE3 / registry deploy paths preserved.
4. `yarn sizes` is the canonical measurement; product **Facet** oversize list is empty (L-SIZE-ENFORCE).
5. Family-level before/after **Facet** size tables are recorded in the implementation plan or a short completion report.
6. Locked decisions in §1.1 were not silently overridden.

---

## 13. Open questions

**None.** All prior open items were locked 2026-08-11 in §1.1 (L-SIZE-*).

---

## 14. Appendix A — Reference patterns already in-repo

| Pattern | Location | Use as template for |
|---------|----------|---------------------|
| Protocol DETF view/execute facet split | `PLAN_facet_split.md`, `ProtocolDETF*QueryFacet` | Aerodrome/UniV4 Out; any preview-heavy Target |
| Single SE CP multi-Target Facets | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` | Orbital / Dual monotarget splits |
| Weighted Buffer multi-Target (partial) | `.../weighted/*HooksTarget`, `*SeTarget`, `*LiquidityTarget` | Extend for Liquidity sub-splits |
| In ExecutionDelegate | `UniswapV4StandardExchangeInExecutionDelegate.sol` | Option 2b for Out zap / heavy execute |
| Package external Math/Claim/Pull libs | Orbital / Dual / Weighted `*Math.sol`, `*ClaimLib.sol`, `*PullLib.sol` | Convert hot paths to **`external`** when Option 2 needed |
| Combined DETF Facet “split later” | `MultiVaultWeightedDetfExchangeInFacet.sol` | Wave 1 packaging-only win |

---

## 15. Appendix B — Baseline size snapshot (2026-08-11)

Source: `SIZES.log` produced by `yarn sizes` / `forge compile --sizes`. Limits: runtime 24,576; initcode 49,152.

All rows below have **negative runtime margin**. Initcode margins remain positive for this set.

| Rank | Contract | RT | RT margin |
|-----:|----------|---:|----------:|
| 1 | Orbital Buffer HooksFacet | 46,457 | −21,881 |
| 2 | Orbital Buffer DepositFacet | 44,442 | −19,866 |
| 3 | Orbital Buffer SeFacet | 44,331 | −19,755 |
| 4 | Orbital Buffer WithdrawFacet | 44,278 | −19,702 |
| 5 | Weighted Buffer LiquidityFacet | 41,471 | −16,895 |
| 6 | Weighted Swap HooksFacet | 37,320 | −12,744 |
| 7 | Weighted Swap LiquidityFacet | 36,079 | −11,503 |
| 8 | Curve Quad LiquidityFacet | 35,907 | −11,331 |
| 9 | Dual SE CP HooksFacet | 32,905 | −8,329 |
| 10 | Weighted DETF Facet | 31,831 | −7,255 |
| 11–13 | Dual SE CP Deposit/Se/Withdraw Facets | ~31k | ~−6.5k |
| 14 | MultiVault Weighted DETF ExchangeInFacet | 29,513 | −4,937 |
| 15–16 | Aerodrome SE Out Facet/Target | ~29k | ~−4–5k |
| 17–18 | Uni V4 SE Out Facet/Target | ~28k | ~−3–4k |
| 19 | MixedBuffer MultiVault Stable DETF ExchangeInFacet | 28,438 | −3,862 |
| 20 | Orbital DETF Facet | 26,773 | −2,197 |

---

## 16. Appendix C — Root-cause summary diagram

```
User → Diamond (proxy)
         ├─ delegatecall → FacetA (must be ≤ 24,576)
         ├─ delegatecall → FacetB (must be ≤ 24,576)
         └─ ...

Problem today (P1 example):
  DepositFacet is DepositTarget+Hooks+Withdraw+Se+Math  → 44KB
  WithdrawFacet is DepositTarget+Hooks+Withdraw+Se+Math → 44KB
  (facetFuncs only expose role selectors; bytecode still full)

Option 1 fix:
  DepositFacet is DepositTarget + ThinCommon     → small
  WithdrawFacet is WithdrawTarget + ThinCommon → small
  Shared pure math → external library only if still over (Option 2)
```

---

## 17. Document control

| Version | Date | Notes |
|---------|------|-------|
| 0.1 | 2026-08-11 | First draft from `OVERSIZE_CONTRACTS.log` / `SIZES.log` + source review of Targets, Facets, prior `PLAN_facet_split.md`, and existing multi-Target packages |
| 0.2 | 2026-08-11 | **LOCKED** owner decisions §1.1: hard-0 only; all product families; Facet gate; prefer Facets; near-miss OOS; no gas gate; vendor OOS; stable selectors + new Facets; no Option 3; yarn sizes enforcement |

**Next step:** Execute [`CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md`](./CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md) (Waves 0–7).
