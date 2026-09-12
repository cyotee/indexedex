# Product Requirements Document (PRD)

## Title

**Struct-Audit Fixes + Audit-Critical Correctness** — implement product-law fixes and high-ROI struct hygiene identified by the 2026-08-08 pilot struct consolidation / audit readiness review

## Status

| Field | Value |
|-------|--------|
| **Status** | **DRAFT** — product law locked 2026-08-09 (this document §2); implementation plan ready |
| **Execute plan** | [`docs/STRUCT_AUDIT_FIXES_IMPLEMENTATION_PLAN.md`](./STRUCT_AUDIT_FIXES_IMPLEMENTATION_PLAN.md) — worktrees, parallel subagents, linear rebase onto `main` |
| **Kind** | Implementation PRD (code + tests); **not** another review pass |
| **Primary inputs** | [`docs/reviews/2026-08-08_struct-audit_AGGREGATE.md`](./reviews/2026-08-08_struct-audit_AGGREGATE.md), area reports `A-hooks-v4` / `A-detf-univ4` / `A-detf-core`, product decisions recorded in session 2026-08-09 |
| **Related review law** | [`docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md`](./STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md), [`docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_EXECUTE_PLAN.md`](./STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_EXECUTE_PLAN.md) |
| **Hard constraints** | **`via_ir` forbidden**; stack relief via structs / helpers / block scope only (`crane-code-style`); DETF role names only; production-first tests (no SUT mocks); vault/DETF DFPkgs via manager registry; facets via CREATE3 / FactoryService |
| **Deploy posture** | **Pre-launch** — storage layout may change with tests; label residual migration risk |
| **Compile / CI gate** | Default profile **`forge build` must succeed**; **all relevant tests must pass** |

---

## 0. Intent

### 0.1 Problem

The pilot review inventoried **128 structs** across hooks + Uni V4 DETF + DETF common and flagged both:

1. **Correctness / audit blockers** that contradict intended product law (claim redeem model, pretransfer proof, fee parity, claimRewards semantics, diamond facet gaps, preview/execute drift).
2. **Struct debt** (dead members, family-local clones of identical layouts) that raises gas and auditor cost but must not reintroduce stack-too-deep or `via_ir`.

A separate review PRD intentionally produced reports only. This PRD authorizes **implementation**.

### 0.2 Goals

1. Align **claim token**, **bond NFT**, and **DETF withdrawal fee** behavior with locked product law (§2).
2. Close **diamond facet selector holes** so every public Target entrypoint used by integrators is cut and tested.
3. Make **preview ≡ execute** (including fees) for supported routes; drop unsupported routes rather than lie in preview.
4. Land **shared equivalent structs** (e.g. `MintSplit`) and remove dead members where stack-safe.
5. Keep **default `forge build` green** and **tests green** after every work package.
6. Strip **product branding** from production code (role names / neutral copy only).

### 0.3 Non-goals

- Re-running full monorepo struct review (full mode of the review PRD) unless separately authorized.
- Enabling `via_ir` or package-specific IR profiles as a compile fix.
- Intermediate leg `minOut` enforcement (product law: final user minOut only).
- “Selling” the protocol-owned bond NFT or feeTo-owned NFT (does not happen; remove false surface).
- Archiving Uni V4 `standardExchange/single` hook packages or CP-single DETF (both intentional products).
- Frontend, research-only scripts, vendored `lib/**` product law.
- Changing fee **rates** / oracle schedules — only **who gets fee shares** and **that fees are taken** on user withdrawal.

### 0.4 Success definition

An implementer can ship stacked PRs such that:

- Locked product law is true on-chain for in-scope packages.
- Diamond APIs match Target surfaces for bond NFT + claim token.
- Default `forge build` succeeds without IR.
- Hermetic (and where needed fork) production-first tests cover every High/Blocker fix.
- Shared structs and dead-member cleanups land without stack-too-deep regression.

---

## 1. Sources of truth

| Document | Role |
|----------|------|
| This PRD | Normative product + implementation requirements |
| `docs/reviews/2026-08-08_struct-audit_*.md` | Finding IDs, evidence paths, Top 25 backlog (inputs; **superseded** where §2 contradicts) |
| `docs/HANDOFF_CI_BUILD_BLOCKER_STACK_TOO_DEEP.md` | Stack-too-deep history on SE Orbital buffer hook |
| `Claude.md` / `docs/agent/INDEXEDEX_AGENT_LAW.md` | DETF roles, deploy, testing non-negotiables |
| Crane skills | `crane-code-style`, `crane-testing`, `crane-deployment`, `indexedex-testing` |

**Supersession rule:** If a review finding recommends “gate `detfNFTSold`” or “archive standardExchange/single,” **this PRD wins**. Review IDs remain useful for traceability.

---

## 2. Locked product law (normative)

### 2.1 Rebasing claim token

| ID | Law |
|----|-----|
| **L-CLAIM-1** | Redeem / exchange-out of claim tokens **unwinds LP held under the protocol NFT bond**. The DETF must **not** rely on a standing inventory of liquid `rateAsset` as the redeem funding model. |
| **L-CLAIM-2** | There should not be “idle liquid rate asset” as the economic model for claim solvency; rateAsset movement is the **result of unwind**, not a pre-funded vault balance assumption. |
| **L-CLAIM-3** | **`pretransferred=true` always requires proof of balance increase** against stored last balance of the relevant reserve/input token (same pattern as vaults that track last reserve balances). Never trust caller-reported amounts without delta. |

### 2.2 Bond NFT lifecycle

| ID | Law |
|----|-----|
| **L-BOND-1** | **User** sell to DETF (`sellPositionToDetfNft` or family equivalent): migrate that tokenId’s principal/LP bookkeeping into the **protocol NFT reserve**, send pending rewards to the NFT owner (or designated recipient), **burn the user NFT**, and remove that position’s **reward-apportionment shares** so it accrues no further rewards. |
| **L-BOND-2** | The **protocol NFT owned by the DETF** (rebasing-claim reserve) and any **NFT owned by feeTo()** are **never sold**. That product path does not exist. |
| **L-BOND-3** | Remove false surface for “protocol NFT sold”: `markDETFNFTSold`, storage `detfNFTSold`, error `DETFNFTSold`, events/NatSpec that claim freeze-after-sale of the protocol position — **delete or fully retire** (pre-launch storage field removal preferred). Do **not** implement “gate `addToDETFNFT` when sold” as the fix for the old finding. |
| **L-BOND-4** | Protocol compound / inventory may continue to credit the protocol NFT position via `addToDETFNFT` (or equivalent) as product requires; that is not a “sold” state. |

### 2.3 Fees on user withdrawal

| ID | Law |
|----|-----|
| **L-FEE-1** | User **withdrawals** take a usage fee (all DETF families and hooks where product charges withdrawal/burn fees). |
| **L-FEE-2** | Fee is realized by **minting shares to `feeTo()`** (not silently skipped; not “return pending as success”). Align burn paths with mint fee accounting so peers match (e.g. CP-single must not omit burn fee while orbital/weighted take it). |
| **L-FEE-3** | **All previews** for fee-bearing routes must include the same fee. Preview must not understate user output or omit fee mint. |

### 2.4 claimRewards

| ID | Law |
|----|-----|
| **L-REW-1** | Caller must be the **owner** of the bond `tokenId` (or the single documented authorized party if product later adds operators — default: owner only). Otherwise **revert**. |
| **L-REW-2** | **No try/catch** that swallows claim failure and returns `pendingRewards` as if paid. Either the call is valid and executes, or it reverts. |
| **L-REW-3** | Return **0** only when the caller is allowed and there are **no rewards** to claim. |

### 2.5 Preview and minOut

| ID | Law |
|----|-----|
| **L-PREV-1** | For every supported route, **preview must equal execution** (amounts and fees). If equality cannot be maintained, **do not support the route** (remove or hard-revert with clear error). |
| **L-PREV-2** | User **minOut is enforced once at the end**, before transferring tokens to the recipient. Intermediate legs accept outputs of prior steps; do not require intermediate minOut unless an external API contract forces it. |

### 2.6 Package identity (Uni V4)

| ID | Law |
|----|-----|
| **L-PKG-1** | `contracts/hooks/.../standardExchange/single` (and related) is a **deliberate** hook family: integrate Standard Exchange operations into Uniswap V4 trade routes. It is not “legacy archive.” |
| **L-PKG-2** | `.../standardExchange/constantProduct/single` DETF is a **valid deployable** DETF family and remains in scope. |
| **L-PKG-3** | Treat hook packages and DETF packages as different products with different liquidity models; do not force one struct graph or “merge packages.” Apply fee/preview/auth law to each where applicable. |

### 2.7 Structs

| ID | Law |
|----|-----|
| **L-STRUCT-1** | If two or more DETF (or hook) packages define structs with **equivalent members and meaning**, **reuse one shared type** (prefer `contracts/vaults/detf/common/**` for DETF-wide types). |
| **L-STRUCT-2** | Remove dead / write-only members (e.g. unused harvest fields, `MintSplit.grossDetf` if never read, unused flexible outs) when stack-safe under default profile. |
| **L-STRUCT-3** | Do **not** collapse stack-critical quote / burn-preview graphs that exist to avoid stack-too-deep (e.g. orbital hook `SwapLiveCtx` / `SphereLegsWad` quote path; DETF `BurnPreviewLib` nested types) without a proven compile-safe alternative. |
| **L-STRUCT-4** | Never recommend or enable `via_ir`. |

### 2.8 Diamond facets

| ID | Law |
|----|-----|
| **L-FACET-1** | Every external/public money or documented view function on bond NFT / claim Targets that is part of the product API **must** appear in the corresponding facet’s `facetFuncs()` (and interface as needed). |
| **L-FACET-2** | Missing selector registration is a **critical bug**: Target bytecode alone is insufficient; diamonds only expose cut selectors. |
| **L-FACET-3** | Add **hermetic tests that call the diamond** (not only the Target type) for newly registered selectors. |

### 2.9 Naming and branding

| ID | Law |
|----|-----|
| **L-NAME-1** | No product brands (e.g. RICH/RICHIR/CHIR) in production helpers, SVG, comments, or user-facing strings. DETF role names only (`rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool`/`reserveBpt`, `rebasingClaimToken`). |
| **L-NAME-2** | Pre-launch storage slot string renames that change layout require tests; prefer renaming helpers/comments first if slot migration is risky. |

### 2.10 Quality gates

| ID | Law |
|----|-----|
| **L-GATE-1** | Default profile `forge build` **must succeed** (closes HANDOFF stack-too-deep if still open via structs/helpers only). |
| **L-GATE-2** | All tests for touched packages **must pass** (hermetic first; fork only when hermetic cannot exercise the path). |
| **L-GATE-3** | Production-first: no mocks of SUT (vaults, DETF, manager, registry, fee oracle, facets, DFPkgs). |

---

## 3. Finding remapping (review → this PRD)

| Review ID | Review title (short) | Disposition under this PRD |
|-----------|----------------------|----------------------------|
| A-A-detf-core-003 | pretransfer without balance proof | **Implement** per L-CLAIM-3 |
| A-A-detf-core-002 | claim redeem pre-funded rateAsset | **Implement** unwind model L-CLAIM-1/2 |
| A-A-detf-core-001 | detfNFTSold unenforced | **Superseded** → remove false sold surface L-BOND-2/3 (not gate adds) |
| A-A-detf-univ4-001 | CP burn skips usage fee | **Implement** L-FEE-1/2/3 |
| A-A-hooks-v4-001 | stack-too-deep / forge build | **Implement** L-GATE-1 (helper/struct only) |
| A-A-detf-univ4-002/003 | claimRewards soft-fail / try-catch | **Implement** L-REW-* |
| A-A-detf-univ4-004 | preview SE passthrough = 0 | **Implement** L-PREV-1 or drop route |
| A-A-hooks-v4-002 | feeWad discarded dual source | **Implement** single fee source + L-FEE-3 |
| A-A-detf-core-004 | realloc missing nonReentrant | **Implement** reentrancy parity |
| A-A-detf-core-005/006 | facet selector gaps | **Implement** L-FACET-* (critical) |
| A-A-detf-univ4-005 | intermediate minOut=0 | **Close as by-design** L-PREV-2 (document + final minOut tests) |
| A-A-detf-univ4-008 | dual single trees | **Close as by-design** L-PKG-* (no archive) |
| S-A-detf-univ4-010 / MintSplit clones | C3 shared MintSplit | **Implement** L-STRUCT-1 |
| S-A-detf-univ4-001/002, S-A-detf-core-001/002/004, S-A-hooks-v4-001 | dead members | **Implement** L-STRUCT-2 |
| S-A-hooks-v4-010 | SphereLegsWad unify | **Optional** after L-GATE-1 green |
| S-*-C6 packing | storage packing | **Deferred** to Wave C; not required for audit Highs |

---

## 4. Scope

### 4.1 In scope (Wave A–B minimum)

| Area | Paths (primary) |
|------|-----------------|
| DETF common | `contracts/vaults/detf/common/**` (bond NFT, claim token, core libs, factory helpers) |
| Uni V4 DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/**` (orbital, weighted, constantProduct/single, common nft/rebasing; listing `standardExchange/single` DETF only if still deployed/tested) |
| Hooks (compile + fee/preview touchpoints) | `contracts/hooks/uniswap/v4/**` as needed for L-GATE-1 and fee single-source |
| Interfaces | `contracts/interfaces/IDETFNFTVault.sol`, `IRebasingClaimToken.sol`, family DETF interfaces for fee/preview/claimRewards |
| Tests | Hermetic production-first suites under `test/foundry/**` matching packages; new diamond surface tests |

### 4.2 In scope later / when touched (Wave C+)

- Balancer DETF families when applying shared `MintSplit` / harvest service types (`contracts/vaults/detf/protocols/dexes/balancer/**`).
- Storage packing (C6) and brand-bearing storage slot renames.
- Optional hook struct C3 (`QuoteCtx` / `ZapWork` twins, `SphereLegsWad` Math↔Target).

### 4.3 Out of scope

- Full-mode struct re-review of routers, manager, protocols, research.
- Frontend / indexer product copy (except that contracts must not reintroduce brands).
- Economic parameter changes (fee bps, bond terms magnitudes).

---

## 5. Work packages

### WP-A1 — Facet selector parity (critical)

**Law:** L-FACET-1/2/3  

**Work:**

1. Diff `DETFNFTVaultTarget` (and claim Target) external entrypoints vs `DETFNFTVaultFacet.facetFuncs` / claim facet.
2. Register missing selectors (at minimum known gaps: `lockInfoOf`, `rewardPerShares`, `detfNFTSold` **if retained during transition**, `updateRedemptionRate`; after WP-A3 sold-surface removal, do not re-register deleted APIs).
3. Mirror family clones (e.g. ComposedStable bond NFT facet) for the same surface.
4. Tests: call each registered selector **via diamond address** from a production-first TestBase; assert non-revert on happy path and expected reverts.

**Done when:** Diamond exposes product API; tests fail if a Target external is omitted from facetFuncs (optional static assert in test).

---

### WP-A2 — Claim pretransfer balance proof

**Law:** L-CLAIM-3  

**Work:**

1. Store last relevant token balance(s) (or use existing vault-style last-balance fields) on claim token paths that accept `pretransferred`.
2. On `pretransferred=true`, require `balanceNow - lastBalance >= amount` (or equivalent delta semantics used elsewhere in IndexedEx vaults).
3. Update last balance after successful pull/consume.
4. Adversarial/negative tests: cannot burn/drain without deposit; cannot fake pretransfer.

**Done when:** Abuse path fails; legitimate pretransfer after real transfer succeeds.

---

### WP-A3 — Claim redeem = protocol NFT LP unwind

**Law:** L-CLAIM-1/2  

**Work:**

1. Replace “pay pre-funded rateAsset only” redeem/exchange-out with unwind of LP/principal held under the **protocol NFT bond** position (via DETF / bond vault / inventory policy as architecture requires).
2. Align NatSpec on `IRebasingClaimToken` and Targets with actual flow.
3. Ensure DETF is not modeled as a rateAsset piggy bank for claim holders.
4. Solvency / rounding tests: redeem after rate change; multi-claimant fairness; CEI + reentrancy.

**Done when:** Redeem pulls economic value from protocol bond reserve path; tests prove no silent underfunded transfer from random rateAsset sitting on the diamond unless produced by unwind.

---

### WP-A4 — Retire “protocol NFT sold” surface

**Law:** L-BOND-2/3/4  

**Work:**

1. Remove `markDETFNFTSold`, `detfNFTSold` view, `DETFNFTSold` error, storage field (pre-launch), events, interface methods, and family clones.
2. Fix any callers that still invoke mark-sold (claim mint / DFPkg init) to no longer depend on that flag.
3. Keep and test **user** `sellPositionToDetfNft` behavior per L-BOND-1.
4. Update interface NatSpec that claimed “freeze after protocol NFT sold.”

**Done when:** No sold-flag product; user sell + protocol compound paths tested; no dangling selectors.

---

### WP-A5 — claimRewards auth and no soft-fail

**Law:** L-REW-1/2/3  

**Work:**

1. All DETF `claimRewards` (orbital, weighted, CP-single, others in scope): revert if caller is not bond owner for `tokenId`.
2. Remove try/catch that returns `pendingRewards` on failure (CP-single and any peers).
3. Return 0 only when allowed and rewards are zero.
4. Tests: non-owner reverts; owner with zero rewards returns 0; owner with rewards receives transfer and matching return.

**Done when:** No false success amounts; auth matches law.

---

### WP-A6 — Withdrawal fee parity + previews

**Law:** L-FEE-1/2/3, L-PREV-1  

**Work:**

1. CP-single (and any peer missing fee) **take usage fee on user withdrawal/burn** by **minting fee shares to `feeTo()`** consistently with mint path accounting.
2. Thread single fee value through execute/preview (hooks: stop discarding `feeWad` while re-fetching inconsistently).
3. Every supported preview includes fee; preview amounts match execute within defined equality (exact or documented rounding rule — prefer exact for fixed inputs).
4. Routes that cannot preview honestly: remove support or revert both preview and execute.

**Done when:** CP burn fee tests green; orbital SE passthrough preview matches execute or route unsupported; gas snapshots optional.

---

### WP-A7 — Final minOut only (document + test)

**Law:** L-PREV-2  

**Work:**

1. Document intermediate `minOut=0` as intentional.
2. Tests that user minOut is enforced on final transfer; intermediate shortfalls that still meet final minOut may succeed; final shortfall reverts.

**Done when:** Tests encode L-PREV-2; no drive-by intermediate minOut spam.

---

### WP-A8 — Reentrancy / CEI on bond money paths

**Law:** parity with existing locks  

**Work:**

1. Add `nonReentrant` (or shared lock) to `reallocateDetfNftRewards` and any harvest entry missing it.
2. Prefer CEI where reward tokens are untrusted.

**Done when:** Reentrancy tests or lock-held assertions on realloc path.

---

### WP-A9 — Default forge build (stack-safe)

**Law:** L-GATE-1, L-STRUCT-3/4  

**Work:**

1. Confirm default `forge build`. If stack-too-deep remains on SE Orbital buffer Target (or imports), fix with **more helpers / structs / scopes only**.
2. Do not enable `via_ir`.
3. Record compile command and result in PR description.

**Done when:** Clean default build on CI-equivalent machine.

---

### WP-B1 — Shared equivalent structs

**Law:** L-STRUCT-1  

**Work:**

1. Introduce shared `MintSplit` (and any other fully equivalent types) under `contracts/vaults/detf/common/**`.
2. Replace family-local definitions (Uni V4 orbital/weighted/CP/legacy; Balancer families when in the same PR or follow-on).
3. Drop write-only members (`grossDetf` if unused) as part of the shared type.

**Done when:** Single definition; families import; compile + mint/bond tests green.

---

### WP-B2 — Dead member / harvest hygiene

**Law:** L-STRUCT-2  

**Work:**

1. Shrink `HarvestParams` / `RedeemParams` (drop unread `tokenId`/`recipient` where proven).
2. Drop unused orbital `WithdrawFlexibleVars` outs; optional C5 inline harvest if stack-safe.
3. Hermetic gas snapshot optional (positive direction expected; no invented %).

**Done when:** Dead fields gone; harvest/redeem/sell tests green; default build green.

---

### WP-B3 — Branding strip

**Law:** L-NAME-1/2  

**Work:**

1. Rename `buildRICHIRPkgInit` and similar helpers; clean CHIR/RICH strings in SVG/comments.
2. Slot string renames only with layout tests if still greenfield.

**Done when:** `rg` for brand tokens in in-scope production paths is clean (allow historical docs outside contracts).

---

### WP-C (deferred)

- C6 storage packing across Layouts/Storage.
- Optional hook C3 (`SphereLegsWad`, pure stable `QuoteCtx`/`ZapWork`).
- Full-mode re-review of remaining monorepo areas.

---

## 6. Testing requirements

### 6.1 Mandatory

| Gate | Requirement |
|------|-------------|
| Compile | `forge build` (default profile) green |
| Unit / integration | Production-first TestBases; `indexedexManager.deploy*DFPkg` / registry paths |
| Negative | Non-owner claimRewards; fake pretransfer; minOut fail at end; unsupported preview routes |
| Diamond surface | Every new/fixed selector called on **diamond** |
| Fee | Burn/withdraw mints fee shares to `feeTo()`; preview matches |
| Claim unwind | Redeem path exercises protocol NFT LP unwind |

### 6.2 Adversarial shortlist (recommended)

- Claim pretransfer drain attempt.
- Reenter during harvest/realloc with malicious reward token (if feasible hermetically).
- Preview/execute mismatch probes on exchangeIn/out.
- User sell then claimRewards on burned tokenId reverts.

### 6.3 Forbidden in tests

- `vm.mockCall` on SUT diamonds/vaults/manager/registry/fee oracle/facets/DFPkgs.
- Enabling `via_ir` to green the suite.

---

## 7. Implementation principles

1. **Correctness before struct cosmetics** — Wave A before Wave B.
2. **One theme per PR** (or stacked PR) — e.g. facets alone; claim pretransfer; claim unwind; fee parity; shared MintSplit.
3. **Stack-safe always** — if collapse fails compile, split helpers instead of IR.
4. **PkgInit/PkgArgs stay on interfaces.**
5. **DETF role names** in new code and renames.
6. **Document supersession** of review findings that product law closed as by-design.

---

## 8. Acceptance criteria (program done)

| # | Criterion |
|---|-----------|
| AC1 | L-CLAIM-1/2/3 implemented and tested for rebasing claim token |
| AC2 | L-BOND-1 holds for user sell; L-BOND-2/3 retired (no protocol-sold product) |
| AC3 | L-FEE-1/2/3 on in-scope DETF withdrawal/burn paths including CP-single; previews include fees |
| AC4 | L-REW-1/2/3 on in-scope DETF claimRewards |
| AC5 | L-PREV-1/2: preview≡execute or route unsupported; final minOut tested |
| AC6 | L-FACET-*: bond NFT (+ claim) diamond surface complete with diamond tests |
| AC7 | L-STRUCT-1: shared `MintSplit` (or documented exception if a family truly differs) |
| AC8 | L-STRUCT-2: known dead members from pilot Top 25 removed where safe |
| AC9 | L-NAME-1: no brands in touched production code |
| AC10 | L-GATE-1/2: default `forge build` green; touched package tests green |
| AC11 | No `via_ir` introduced |
| AC12 | PR descriptions cite this PRD + remapped finding IDs |

---

## 9. Suggested PR stack order

```text
PR1  WP-A1  Facet selectors + diamond tests          (critical, low product risk)
PR2  WP-A5  claimRewards auth + remove try/catch
PR3  WP-A2  Pretransfer balance proof
PR4  WP-A3  Claim redeem unwind                     (largest product change)
PR5  WP-A4  Retire protocol-sold surface
PR6  WP-A6  Fee parity + preview equality
PR7  WP-A7/A8  minOut docs/tests + reentrancy
PR8  WP-A9  Compile gate (if still red; else verify-only)
PR9  WP-B1  Shared MintSplit
PR10 WP-B2  Dead members / harvest
PR11 WP-B3  Brand strip
```

PRs may be combined if small, but **PR4 (unwind)** should stay isolatable for review.

---

## 10. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Claim unwind design touches DETF exchange + bond inventory | Design sketch in implementation plan; production-first tests before broad family copy |
| Stack-too-deep after struct shrink | Compile gate each PR; revert collapse, use helpers |
| Facet clone drift (ComposedStable vs common) | Same WP applies to clones; grep `facetFuncs` |
| Fee mint vs historical transfer-to-feeTo | L-FEE-2 is mint shares to feeTo; migrate peers to one pattern |
| Review docs still say “gate detfNFTSold” | This PRD supersedes; optional note in aggregate follow-up |

---

## 11. Open items (none blocking PRD)

| Item | Default if still open |
|------|------------------------|
| Exact equality epsilon for preview vs execute on multi-hop residual dust | Prefer exact for fixed fixtures; document residual dust only if mathematically forced |
| Whether listing-era Uni V4 `standardExchange/single` **DETF** remains deploy-priority | Keep code healthy if tests exist; CP-single is explicit deploy target |
| Balancer shared MintSplit in same PR as Uni V4 | Prefer Uni V4 first; Balancer in follow-on PR under L-STRUCT-1 |

---

## 12. Document control

| Version | Date | Notes |
|---------|------|-------|
| 0.1 | 2026-08-09 | Initial implementation PRD from pilot reports + product law session |

**Upstream review artifacts:**

- `docs/reviews/2026-08-08_struct-audit_AGGREGATE.md`
- `docs/reviews/2026-08-08_struct-audit_A-hooks-v4.md`
- `docs/reviews/2026-08-08_struct-audit_A-detf-univ4.md`
- `docs/reviews/2026-08-08_struct-audit_A-detf-core.md`

**Implementation plan:** [`docs/STRUCT_AUDIT_FIXES_IMPLEMENTATION_PLAN.md`](./STRUCT_AUDIT_FIXES_IMPLEMENTATION_PLAN.md) — tasks T00–T12, worktrees, parallel subagents, orchestrator FF-only rebase land onto `main`.
