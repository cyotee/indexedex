# Grok cross-review — NETNET_PENDLE_DETF_PRD.md v0.23

| Field | Value |
| --- | --- |
| Reviewer | Independent Grok (same session as original) |
| Observable routing | Prompt/original: name `grok-4.6`, ID `xai/grok-4.6`. Not provider-verified. |
| Pin / continuation | Governing moderator instructions for this continuation **explicitly pin `xai/grok-4.6`**. Original pass also recorded `RESEARCH_COUNCIL.md` pinning `xai/grok-4.7` and warning that `grok-4.6` sessions fail continuation checks. **This resume executed** (peer originals readable; write allowed). No continuation-guard throw observed this turn. Residual file-pin vs live session is reported, not bypassed. |
| Inputs | Own original (`grok-original.md`, **untouched**). Complete originals: `astra-original.md`, `minimax-original.md`, `kimi-original.md`. Treated as untrusted evidence. No peer cross-reviews read. |
| Date | 2026-09-27 |

**Unchanged original verdict:** not ready for a no-discretion implementation plan; ready only after specification closure. Settled custom-family economics are not reopened.

---

## 1. Agreements (all four originals)

| Topic | Agreement | Classification |
| --- | --- | --- |
| Not plan-ready | Astra, MiniMax, Kimi, Grok | Process |
| Do not reopen Keep-YT-in / shared-SY-out, four-leg HLP, `floor(S0*n/200)`, absent-as-above-1, incentive-free reinvestment, DETF-as-SY without certification | All | Settled product |
| **C05** next-epoch lock vs `UniswapV4DetfCommon.sol:104–109` min-duration revert | All (independent traces) | **Owner checkpoint** if economics/lock change; otherwise a concrete compatibility branch must exist before freeze |
| **C08** note-array liveness | All. Astra + Kimi additionally cite `BondDepository.sol` deposit-to-arbitrary-`to` and full-array `redeem` (Grok original did **not** re-read crane BondDepository — `RC_UNAVAILABLE`). | **Feasibility / possible owner return**. Hypothetical batching ABIs remain forbidden. |
| **C07** weights/fees/horizon still need owner numbers | All | **Owner checkpoint** |
| **C11 / C12** subshare lifecycle and SY provider/inventory | All | **Specification-author work**, not implementer defaults. C12 on-chain `previewRedeem` warning independently confirmed from Pendle docs (Astra, MiniMax, Kimi, Grok). |
| Broken `docs/plans/detf/` §3.1 citation | Grok (empty dir); Astra (no PRD matches); Kimi (dir does not exist); MiniMax (unverified, low confidence) | Citation defect. Recipient/zero-share **policy** is settled (C04); **formulas are missing**. |
| O09 unlabeled vs other O-rows | Grok, Kimi; MiniMax notes O09 remaining spec | Editorial/status, not a product reopen |
| Version 0.16–0.21 gap; stale prepared date | Grok, Kimi; Astra notes prepared vs revision | Editorial |
| Local IndexedEx vault/hook/bond citations generally accurate | All who traced them | Fact |

---

## 2. Product closure vs plan-valid engineering

Moderator constraint applied: missing Solidity, selectors, TestBases, and call-order proofs are **not** PRD defects if the product rule is closed. Spec-authoring may still be required **before** a no-discretion plan.

**Still product / owner (cannot be invented in a plan)**

- C05 lock/bonus coexistence if the reference min-duration cannot be satisfied.
- C07 numeric parameters (weights, fees, opening-unit map, TWAP overflow/history horizon).
- C08 if no bounded design exists against the **actual** depository — descope or owner alternative.
- C03 spendability of retained interest-token **incentives**, only if a real market collision is evidenced.
- Astra **B1** conflict among **already selected** rules: A49 full-set sync of historical + failed-forwarding tokens vs A11/§13 isolation vs §11.2 no unbounded history walk. If those cannot coexist, that is an owner incompatibility, not a coding choice.

**Specification-author (not implementer, not necessarily owner)**

- C11 mint/burn/last-exit/rollover equations.
- C12 sample/failure/eligibility/force-claim state machine using execution `redeem` unless a SY is pinned.
- Owned-reserve burn waterfall and ordinary-SY funding **separately** (O09 content).
- TWAP **`price(u)` process** (Astra B4): sample-and-hold vs continuous external Pendle mark; what happens between observations. This is semantic product-adjacent specification, not ABI.
- Pretransfer/provenance algorithm (Astra B5 / Grok C12 / MiniMax AG5).
- Rollover §11.3 items 1–7 argument-source map.
- Restate fee/creator U=0 algebra **in this PRD** (do not invent).
- Canonical SE-binding **predicate** (MiniMax B6 / A20): requirement is selected; exact getter is interface design.

**Validly deferred to an implementation plan** (once the above exist)

- Function selectors, events, errors, Repo field names, TestBase matrix.
- Exact Solidity TWAP interface **once** units/readiness/`price(u)` are frozen. MiniMax B1’s invented `CumulativeObservation` / `consult` / `checkpoint` structs are **unsupported proposed fixes**, not required PRD text.
- Callback/reentrancy ordering that realizes already-stated invariants.
- Exhaustive V2 SE feature matrix **execution** (E14 already says it is not done).
- Foundry profile (`hook_factory` vs CLAUDE default/fork-only): test-harness law, not product. Astra correctly notes CLAUDE supersedes the local hook-skill profile.
- Hook CREATE2 mineNonce vs DETF salt `"NET-DETF"` coexistence: **architecture specification**, but absence of a finished hook DFPkg is not a PRD defect.

**Grok original correction of rank (not of conclusion):** hook DFPkg-vs-monomorph and FOUNDRY_PROFILE were listed among “prioritized blockers.” Keep the salt/factory/flags **map** as closure work. Do **not** treat missing hook implementation code as a v0.23 defect.

---

## 3. Evidence that changes Grok’s view

### Elevate: Astra B1 (full-set sync vs isolation vs bounded history)

Grok original treated A49 vs A36 as an acceptance-row tension. Astra shows a **selected-vs-selected conflict**: `BasicVaultCommon.sol:46–54` unguarded `balanceOf` over the whole registered set after every money route; failed-forwarding tokens remain registered; historical series accumulate; hostile `balanceOf` is not isolated by a failed `transfer`. Grok independently read those Common lines in the first pass and agrees the interaction is real.

This is **not** “missing implementation.” It is v0.23 sharpening two closed requirements until they may be jointly unsatisfiable. **Adopt as P0 specification conflict.** Required next step matches Astra: known/expected-token boundary, archival vs active sync, unreadable-balance handling; escalate to owner only if “full set after every route” cannot be kept.

### Elevate: Astra B4 (`price(u)` between observations)

Grok original called the TWAP section “a requirement list, not a contract,” focusing on selectors. Astra’s sharper defect is **process**: Pendle/index/SY can move without a hook transaction; integrating last mark is sample-and-hold, not a continuous integral; retroactive reprice of elapsed time violates the selected pre-change rule. **Adopt.** Product window (3600s arithmetic, two series, absent-as-above-1) stays settled. What `price(u)` means in quiet periods is specification-closure, not MiniMax’s ABI sketch.

### Do not elevate: MiniMax B1 as “PRD failed because no Solidity interface”

PRD:35–36 already says exact selectors are interface-design work and no Solidity is created by the amendment. That is acknowledged OPEN/spec work, **not a contradiction** with R53. Recheck vs OPEN: MiniMax is right that a no-discretion **plan** cannot invent the ABI; wrong that v0.23 is defective for lacking it. Rank below Astra’s semantic gap.

### Do not adopt: Kimi’s identification of the funded-staking plan as the missing §3.1 reference

Kimi reports `docs/plans/detf/` absent and points to `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`, noting **gons/K** vs this family’s fixed `internalShares` and growing `B`. Moderator instruction: **do not assert a found gons-based plan is the intended missing balance-derived reference without proof.** Grok original already refused to invent the formulas. **Unchanged:** citation is broken; inline or link a proven source; do **not** map `_topUpDeltas` onto NetNet expansion shares without an explicit owner/spec statement. Kimi’s **divergence observation** is useful as a warning against silent reuse, not as identification.

### Partial adopt: later-bond G/U on the four-leg virtual book (Kimi P1.5)

Grok original stressed first-bond four-leg mapping (A35/C07). Kimi notes live `_quoteBondG` / `_quoteBondPurchase` assume a concrete proportional hook book. **Agree this belongs on the C07/C11 closure list.** Not a new owner economic choice unless mapping proves incompatible.

### Confirm without new Grok verification: BondDepository / BasePoolMath / IStandardizedYield line pins

Astra and Kimi report successful crane-tree reads Grok could not perform (`RC_UNAVAILABLE` in original). Those peer line numbers remain **untrusted**. They increase **confidence that C08 is a real upstream interface**, not a PRD hallucination. Grok still has no independent BondDepository/BasePoolMath/SY-interface verification this session.

---

## 4. Specific objections to peer findings

**Kimi B2 (FoT/rebase vs LOCKED agent law) as P0 that the family is “forbidden.”**  
Scoped custom-family approval is **settled** (PRD:23–25). It is **not** permission to edit `INDEXEDEX_AGENT_LAW.md` or adversarial L2. Grok original §4.9 already called this an **authority mismatch**. **Hold that:** report the mismatch to owner/moderator as a **process** blocker for coding agents; do **not** reopen FoT economics; do **not** treat amending shared instructions as in-scope for this research task or for the implementation plan. Kimi’s recommended law-file edit is a **separate authorized instruction change**, not a PRD defect and not an implied grant.

Astra did not rank this as P0 and listed FoT/sNET approval among decisions not to reopen — aligned with Grok on economics; under-ranked the **routing** collision. MiniMax recorded O01 correctly (“shared token policy unchanged”).

**MiniMax B3 recommended designs** (per-NFT escrow, batched per-note redeem, `maxNotesPerWrapper`). PRD:811–812 / C08 forbid describing a hypothetical selector or batching layer as a solution. **Problem agreed; proposed fixes unsupported.** Paths remain: measure a bound on the actual ABI, or return to owner / descope.

**MiniMax B2 listing three owner branches** is acceptable as an options menu; selecting one in the review is not. Agreed the PRD must not leave `selectedLock < oracleMin` unspecified.

**MiniMax AG1 attributes note-array growth to A10.** In the target, **A09** is notes/liveness; **A10** is rollover. Correction: A09.

**MiniMax AG2/AG3/AG7** (HLP storage/selectors, quote dataflow, rollover call order) are largely **plan-valid once equations exist**. Over-ranking them as PRD holes would violate “missing implementation is not a PRD defect.”

**MiniMax B7 fee-oracle identity:** MiniMax correctly marks **not a blocker**. R36/A23 are selected rules plus a verification gate. Agreed.

**Astra B7 creator not in PkgArgs.** Grok original did not flag creator-address source. **Accept as configuration-map gap** (package constant vs PkgArgs vs discovery). Silent fallback to deployer/registry/`address(0)` would be a product leak; specifying the source is spec-author work, not new seigniorage economics.

**Astra historical “contradictions”** (line 134 “stable curve”; 1073 “no historical common-interest-output”; 1079 leftover 1-NET opening proposal). Grok original already treated §§17–18 as provenance and warned of stale harvest. Recheck: these are **acknowledged historical text**, not operative vs OPEN C-rows. Do not present them as product contradictions. Editorial cleanup only.

**Grok original “sNET-input completion is not inferred” (PRD:200) as leftover vs closed C09.** Kimi also calls it cryptic. Not a contradiction of C09; delete/rewrite. Agreed.

---

## 5. Unsupported proposed fixes (do not carry into consolidation as decisions)

| Source | Proposal | Why unsupported |
| --- | --- | --- |
| MiniMax B1 | Concrete TWAP struct/selectors/errors | Interface-design work; inventing ABI in a review is a selection |
| MiniMax B3 | Escrow/batch/cap designs for notes | PRD forbids hypothetical upstream-shaped solutions |
| Kimi B2 | Amend `INDEXEDEX_AGENT_LAW.md` Token policy from this task | Shared instructions unchanged; scoped approval ≠ edit grant |
| Kimi P1.1 | Treat funded-staking **gons** plan §4.x as the §10.2 source | No proof it is the intended “balance-derived” reference; mechanisms differ |
| Anyone | Hidden epoch cap, fabricated bonus duration, D39-style burn fallback | Explicitly forbidden by target |

---

## 6. Genuine remaining dissent (unresolved)

1. **Authority-mismatch severity.** Kimi: P0, family forbidden under current law until law is edited. Grok: process/authority sidecar, approval already recorded, do not edit shared law here. Astra: not ranked P0. **Unresolved process question for the moderator/owner, not an economic reopen.**

2. **TWAP ABI vs TWAP process.** MiniMax P0 = missing interface artifact. Grok+Astra: process/`price(u)` is the spec gap; ABI is later. **Dissent on rank, not on “plan cannot invent selectors.”**

3. **Hook deploy path rank.** Grok original over-weighted missing DFPkg code; Astra B7 (salt vs hook mining, creator map) is the durable part. MiniMax/Kimi did not rank hook factory path as P0. **Unresolved how much architecture must be in the PRD vs the first plan chapter** — lean Astra/Grok-corrected: map factory/flags/salt, do not demand implemented package.

4. **Whether C11 math may be authored in the plan** (MiniMax B4 “otherwise the plan will author without owner review”) vs “spec-author then freeze plan” (Grok, Astra sequence). **Grok holds:** subshare equations are specification-closure; a plan that writes them is doing PRD work and must not be treated as already authorized implementation.

---

## 7. Recheck: claimed contradictions vs acknowledged OPEN

| Claim | Recheck |
| --- | --- |
| R53 “define interface” vs no Solidity | **OPEN/spec**, explicitly at PRD:35–36. Not an internal contradiction. |
| O09 unlabeled | Status hygiene; body is remaining **funding-transition spec**, i.e. acknowledged OPEN work. |
| C05/C08/C11/C12 listed as blockers | They are the PRD’s own open register. Ranking them as not-ready is consistent, not a surprise contradiction. |
| A49 vs A11 vs bounded history | **Not OPEN** — three selected requirements. Astra B1 stands. |
| FoT approval vs agent-law LOCKED | Authority mismatch, **not** an OPEN product choice and **not** a reason to reopen approval. |
| ERC-4626 exact-out vs declined certification | Owner settled routes; A16 still requires inverse **or** truthful unsupported-exact-out. Not a reopen. |
| MiniMax E1 spec-author vs implementer | Consistent with PRD:851 if “spec author” ≠ “implementer.” Not a product contradiction. |

---

## 8. Final prioritization (Grok, post-cross-review)

Keep original findings attributed. Revised **rank only**:

**P0 — must close before a no-discretion plan (mix of owner and spec-author)**

1. Astra B1 / v0.23 sync–isolation–history conflict (selected vs selected).
2. C08 note liveness: bound against actual depository or owner descope (Astra B2, Kimi B1, Grok/MiniMax B3). Peer BondDepository traces untrusted but mutually consistent.
3. C05 duration/bonus vs next-epoch/mature-wrapper (all).
4. C07 owner parameter table (all).
5. TWAP **`price(u)` / external quiet-period semantics** (Astra B4). Not MiniMax’s ABI.

**P1 — specification-author, then plan**

- C11 subshare lifecycle; later-bond G/U on virtual four-leg book (Kimi P1.5).
- C12 SY execution vs preview; force-claim provenance algorithm (Astra B5).
- O09 dual funding/fee/inverse transitions (ordinary SY vs owned-reserve burn).
- Inline fee/creator U=0 algebra; **do not** bind the gons plan without proof.
- Factory/flags/DETF-salt vs hook CREATE2 **map**; creator-address source (Astra B7).
- A20 canonical-SE predicate (MiniMax B6) as interface design.

**P2 — editorial / process**

- O09 Resolved label; 0.16–0.21 stubs; prepared date; stale §18 sentences; PRD:200.
- **Authority mismatch** (Kimi B2 / Grok §4.9): report to owner; do not amend shared law in this task; do not reopen family approval.
- Companion `REQUIREMENTS_QUESTIONS.md` v0.12 / Q6 “interest only” (Grok original) — PRD wins.

**Not PRD defects:** missing hook package code, missing TWAP Solidity, missing TestBase matrix, unread `DETFFundedBondTarget` tail (MiniMax evidence limit).

---

## 9. Confidence

| Item | Confidence |
| --- | --- |
| Four-way not-ready; settled economics internally consistent | High |
| C05/C07/C08/C11/C12 as real closure items | High |
| Astra B1 interaction (from Grok’s own Common read + Astra’s framing) | High on conflict existence; medium on practical exploit/gas |
| Peer crane-tree line pins (BondDepository, BasePoolMath, SY, NET.sol) | Medium (untrusted; Grok original denied those paths) |
| Kimi gons-plan identity | Rejected as identification; warning against silent reuse retained |
| FoT **economics** | Settled. **Authority routing** unresolved at process level |
| Continuation identity | This turn ran under moderator pin `xai/grok-4.6`. File-level `RESEARCH_COUNCIL.md` 4.7 pin was not re-read this turn. No guard failure observed. |

No shell, tests, code, or peer cross-reviews. Original `grok-original.md` unchanged.
