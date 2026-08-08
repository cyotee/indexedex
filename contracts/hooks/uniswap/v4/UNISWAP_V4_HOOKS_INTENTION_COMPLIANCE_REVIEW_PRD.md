# PRD: Uniswap V4 Hooks — Intention Compliance Review (Reports Only)

**Name:** Uniswap V4 Hooks Intention Compliance Review  
**Date:** 2026-08-08  
**Status:** **LOCKED for planning** — product intentions below are the **sole source of truth** for this review program  
**Package path (program root):** `contracts/hooks/uniswap/v4/`  
**Kind:** **Analysis / documentation program only** — no production code changes, no test rewrites, no refactor PRs as deliverables of this program  

---

## 0. Purpose

Produce **one written compliance report per hook family** that answers:

> Does the **implemented** Uniswap V4 hook match the **operator’s stated original intention** for that hook?

Downstream agents will use those reports (not this PRD alone) to draft any **remediation PRDs** if divergence exists. This program **stops at reports**.

---

## 1. Authority & non-authority (critical)

| Layer | Role |
|-------|------|
| **This PRD §4–§6** (operator intentions) | **Primary and exclusive product SoT for compliance judgment** |
| **Implementation under each hook path** (`.sol`, interfaces, DFPkgs, FactoryService, TestBases under that tree) | **What is measured** |
| **External / peer references named in §4** (upstream OrbitalHook, Balancer V3 pool-stable / pool-weighted / pool-constProd, peer IndexedEx hooks) | **Behavioral reference baselines** for “mirror / reimplementation / standard buffering” |
| Co-located `*_PRD.md` / `*_IMPLEMENTATION_AND_TEST_PLAN.md` under each hook | **Not** the source of truth for pass/fail. Use only as **secondary context** (naming, deploy history, possible explanation of why code looks a certain way). If co-located PRD and §4 conflict, **§4 wins**; record the conflict as a finding (“co-located PRD diverges from operator intention”). |
| Crane / IndexedEx architecture skills (`crane-architecture`, `crane-deployment`, diamond package patterns) | **Structural reference** for “Diamond storage and Package patterns” (Orbital, and any package-shaped hooks) |
| Speculative “what the product PRD meant” | **Forbidden** as a pass criterion |

**Hard rule for all agents in this program:**

1. Do **not** treat existing hook product PRDs as normative intention.  
2. Do **not** “fix” or “improve” code to match intention.  
3. Do **not** rewrite co-located product PRDs as part of this program.  
4. Do **write** only the compliance reports (and the follow-on **implementation plan for this review**, see §8).  

---

## 2. Out of scope

| Out | Why |
|-----|-----|
| Code changes, refactors, renames, deploy path fixes | Separate remediation PRDs after reports |
| Rewriting or reconciling co-located product PRDs | May be proposed as *recommendations* inside reports only |
| DETF packages that *consume* hooks | Not this program (unless a hook report must note consumer-facing opacity) |
| Hook diamond **factory** product law (`factory/`) | Not a “hook intention” subject; may be mentioned only if a hook’s deploy shape is inseparable from intention (e.g. “must be Diamond package”) |
| Full economic audits, formal verification, gas benchmarks | Optional notes only if they affect intention fit |
| Running the full monorepo CI as a gate | Optional; reports may cite existing tests as **evidence**, not as DoD for this program |
| Creating remediation implementation plans | After reports exist, a **different** program |

---

## 3. Deliverables

### 3.1 Required report files (one per subject)

Write reports **under the program root** so they are easy to discover and dispatch:

```text
contracts/hooks/uniswap/v4/
  COMPLIANCE_REPORT_orbital.md
  COMPLIANCE_REPORT_stable_quad.md
  COMPLIANCE_REPORT_weighted.md
  COMPLIANCE_REPORT_standardExchange_single.md
  COMPLIANCE_REPORT_standardExchange_constantProduct_single.md
  COMPLIANCE_REPORT_standardExchange_dual.md
  COMPLIANCE_REPORT_standardExchange_orbital.md
  COMPLIANCE_REPORT_standardExchange_weighted.md
  COMPLIANCE_REPORT_standardExchange_stable_quad.md
  COMPLIANCE_REPORT_INDEX.md          # optional rollup; recommended after all 9 exist
```

### 3.2 Optional plan file (planner agent only)

The agent that turns this PRD into an **execution plan** should write:

```text
contracts/hooks/uniswap/v4/UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_IMPLEMENTATION_AND_TEST_PLAN.md
```

That plan must:

- Map each subject ID → subagent task → report path  
- List primary files / dirs to read per subject  
- Define parallelism (9 independent analyses preferred)  
- Forbid code mutation  
- Restate report template §7  

**No forge test suite is required** for this program. “Test” in the plan filename means **review procedure**, not Foundry tests.

### 3.3 Explicit non-deliverables

- No PRs that modify Solidity  
- No new hooks  
- No deletion of co-located PRDs  

---

## 4. Subject catalog & operator intentions (SoT)

Each subject has:

- **ID** — stable key for plans/subagents  
- **Impl path** — code under review  
- **Intention** — operator wording, expanded into **checkable criteria**  
- **Primary references** — compare against these for “mirror / reimplementation” claims  

### Shared vocabulary (use consistently in all reports)

| Term | Meaning for this program |
|------|---------------------------|
| **Pair door / multi-pool exposure** | Because Uniswap V4 pools are 2-token, multi-asset reserve designs expose **one pool per unordered pair** among configured tokens (combinatorial doors), not a single multi-asset V4 pool. |
| **No curve / routing wrapper** | Hook does not price with AMM math; it only routes vault deposit/withdraw (or equivalent) so a trade path can include SE vault IO. |
| **Holds no liquidity** | Hook does not act as an LP vault with shared reserves used for swaps; no fungible LP inventory model for traders. |
| **Standard buffering (SE buffer)** | For ≥1 configured leg: underlying asset may sit in a paired **Standard Exchange (SE) vault**; optional **Balancer V3 `IRateProvider`** rates that SE position; swaps present **pair token** (not vault share) to traders when opacity is required. |
| **Buffered amount tracking / virtual reserve** | Track how much has been **buffered into** and **withdrawn from** the SE vault. Use that tracking as the **virtual reserve** for the unpaired (or non-SE) leg accounting, and **deduct** buffered amounts from the **rated SE vault leg value** so a pure deposit into the SE vault does **not** skew the AMM price solely via share rate illusion. Price **should** still move when the **rate value** of SE-held reserve changes. |
| **Trader opacity** | Pools register for **SE vault pair token** + opposing token(s). Traders swap pair tokens; SE vault is **not** the trade surface. LPs may deposit/withdraw as **SE vault shares and/or pair token**. |
| **Native-balance LP accounting** | Liquidity contribution measured in **native balances and rated amounts**, not contingent on SE vault underlying **share price** as the LP unit of account. |
| **Diamond storage + Package patterns** | Crane/IndexedEx: Target/Repo/Facet/DFPkg (or hook diamond package), CREATE3 facets, package deploy path — not a single monomorph “god contract” as the sole storage model unless intentional legacy. |

### Shared criterion pack: **Standard buffering behavior**

Apply this pack wherever intention says “standard buffering” / “buffering and rate provider for ≥1 leg”:

| # | Criterion |
|---|-----------|
| B1 | At least one leg **may** buffer into a paired SE vault (config allows ≥1 buffered leg where product is multi-leg). |
| B2 | Optional **IRateProvider** (Balancer V3 style) may rate the SE vault reserve for the buffered leg. |
| B3 | Implementation tracks buffered/withdrawn amounts used in reserve accounting (not “wallet balance alone” as sole truth if buffering exists). |
| B4 | Rated SE vault leg used in pricing is adjusted so **deposit-into-SE alone** does not create a false price skew; rate changes of underlying **do** affect price. |
| B5 | Trader-facing pool keys use **pair tokens** (opacity); SE interaction is an LP/internal concern. |
| B6 | LPs can manage liquidity via **pair token and/or SE vault share** where buffering is configured (document exact surface if partial). |
| B7 | LP accounting is **native / rated**, not share-price-contingent for contribution weight. |

If a subject is multi-asset + buffering, also apply multi-pool door criteria from the unbuffered peer.

---

### H1 — Orbital (unbuffered)

| Field | Value |
|-------|--------|
| **ID** | `orbital` |
| **Impl path** | `contracts/hooks/uniswap/v4/orbital/` |
| **Report** | `COMPLIANCE_REPORT_orbital.md` |
| **Intention** | Reimplementation of the ethglobal Orbital hook using IndexedEx **Diamond storage and Package patterns**. |
| **Primary references** | Upstream: https://github.com/Dhruv-2003/ethglobal-buenos-aires-25/blob/main/src/OrbitalHook.sol — clone/fetch as needed for comparison. Crane diamond/DFPkg patterns in `lib/crane/` + IndexedEx package norms. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H1.1 | Core swap/liquidity **behavioral model** is recognizably the same family as upstream OrbitalHook (sphere/orbital math, not a random AMM). Document which invariants/APIs map and which do not. |
| H1.2 | Storage and modularity use **Diamond-style** Target/Repo/Facet (or equivalent package diamond), not only a single-file monomorph as the production shape. |
| H1.3 | Deploy/package wiring follows **Package (DFPkg / hook package)** patterns rather than ad-hoc `new` deploy of the product logic as the intended production path. |
| H1.4 | Material intentional deltas (fees, multi-pool doors, Permit2, immutability) are listed; each is either justified as IndexedEx adaptation or flagged as **unexplained divergence** from “reimplementation.” |

---

### H2 — Quad Stable (unbuffered)

| Field | Value |
|-------|--------|
| **ID** | `stable_quad` |
| **Impl path** | `contracts/hooks/uniswap/v4/stable/quad/` |
| **Report** | `COMPLIANCE_REPORT_stable_quad.md` |
| **Intention** | Mirror **Balancer V3 Stable pool** behavior, with primary V4-driven divergence: expose the reserve via **many pools for all combinations** of the configured tokens. |
| **Primary references** | `lib/crane/contracts/external/balancer/v3/pool-stable/` (and StableMath as used there). |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H2.1 | Pricing/invariant is StableSwap-class (amplification, multi-asset reserve), not constant-product or weighted-product. |
| H2.2 | N configured tokens ⇒ combinatorial **pair doors** (pools) covering configured token pairs; shared reserve accounting across doors. |
| H2.3 | Material math/API deltas vs Balancer stable pool are enumerated (rates, fees, join/exit, amplification updates). Each: acceptable V4 constraint vs unexplained miss. |
| H2.4 | No SE buffering required for this subject (buffering belongs to H9). Presence of buffering here is a **divergence** unless clearly optional and off by default. |

---

### H3 — Weighted (unbuffered)

| Field | Value |
|-------|--------|
| **ID** | `weighted` |
| **Impl path** | `contracts/hooks/uniswap/v4/weighted/` |
| **Report** | `COMPLIANCE_REPORT_weighted.md` |
| **Intention** | Mirror **Balancer V3 Weighted pool** behavior, with primary V4-driven divergence: multi-pool combinatorial doors for configured tokens. |
| **Primary references** | `lib/crane/contracts/external/balancer/v3/pool-weighted/` (WeightedMath / pool). |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H3.1 | Pricing is weighted-product class (normalized weights, not equal-weight-only CP unless weights are free parameters matching Balancer). |
| H3.2 | Multi-asset reserve exposed as combinatorial pair doors under V4. |
| H3.3 | Material deltas vs Balancer weighted pool enumerated and classified. |
| H3.4 | No SE buffering required (buffering is H8). |

---

### H4 — Standard Exchange single (routing wrapper)

| Field | Value |
|-------|--------|
| **ID** | `standardExchange_single` |
| **Impl path** | `contracts/hooks/uniswap/v4/standardExchange/single/` |
| **Report** | `COMPLIANCE_REPORT_standardExchange_single.md` |
| **Intention** | Simple wrap of **SE vault deposit/withdraw** for the **token ↔ SE vault** pair. **No price curve**. **Holds no liquidity**. Exists so SE vault deposit/withdrawal can sit on a **trade route**. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H4.1 | Hook path performs SE **deposit and/or withdraw** (or equivalent In/Out) for the configured vault/token pair. |
| H4.2 | **No AMM curve** applied by the hook for pricing (no CP/stable/weighted/orbital math driving the swap amount). Amounts should follow vault exchange rate / share math only. |
| H4.3 | **Does not hold liquidity** as a pool reserve / LP product (no shared LP inventory model for traders). |
| H4.4 | Product narrative/code supports inclusion in a **routing** path (PoolManager hook callbacks as bridge), not a standalone multi-asset AMM. |
| H4.5 | If code implements a pricing curve or LP reserves, that is a **fail / major divergence**. |

---

### H5 — Single SE Buffer Constant Product

| Field | Value |
|-------|--------|
| **ID** | `standardExchange_constantProduct_single` |
| **Impl path** | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` |
| **Report** | `COMPLIANCE_REPORT_standardExchange_constantProduct_single.md` |
| **Intention** | Constant-product pool similar to Balancer const-prod in Crane, **buffering one exposed token** into a paired SE vault, with optional rate provider rating the SE reserve. Track buffer in/out as virtual reserve accounting; deduct buffered amount from rated SE leg so deposits don’t skew price; rate changes **should** move price. Pools register for **pair token + opposing token** (SE opaque to traders). LPs may deposit/withdraw as SE vault **or** pair token. LP management on **native balance + rated amounts**. |
| **Primary references** | `lib/crane/contracts/protocols/dexes/balancer/v3/pool-constProd/`; SE vault interfaces as used by production SE packages. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H5.1 | Constant-product (or Balancer-equivalent CP) swap math on the two **exposed** legs. |
| H5.2 | One leg buffered into paired SE vault. |
| H5.3 | Optional IRateProvider for SE vault reserve rating. |
| H5.4 | Buffer track-in/track-out / virtual reserve accounting present and used in pricing inputs. |
| H5.5 | Rated SE leg reduced by buffered-out accounting so **buffer deposit alone** does not falsely reprice; **rate movement** can reprice. |
| H5.6 | Pool registration / pool keys are **pair token + opposing token** (trader opacity). |
| H5.7 | LP paths accept **pair token and/or SE vault share**. |
| H5.8 | LP contribution accounting is native + rated, not contingent on SE underlying value as the unit of contribution. |
| H5.9 | Standard buffering pack B1–B7 applied and scored. |

---

### H6 — Dual SE Buffer Constant Product

| Field | Value |
|-------|--------|
| **ID** | `standardExchange_dual` |
| **Impl path** | `contracts/hooks/uniswap/v4/standardExchange/dual/` |
| **Report** | `COMPLIANCE_REPORT_standardExchange_dual.md` |
| **Intention** | Like H5 (CP + standard buffering), but exposes **two pair tokens** and exchanges **between the two pair tokens** on the same constant-product curve. Liquidity management in **native balances**. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H6.1 | Both legs are pair-token-facing for trades; swap is pairTokenA ↔ pairTokenB via CP curve. |
| H6.2 | Buffering/rate provider available consistent with dual-leg SE design (score B1–B7 per configured legs). |
| H6.3 | LP management in **native balances** (and rated amounts if rates apply). |
| H6.4 | Same anti-skew buffer accounting intent as H5 when buffering is active. |
| H6.5 | Not a multi-asset orbital/weighted/stable curve. |

---

### H7 — Standard Exchange Orbital Buffer

| Field | Value |
|-------|--------|
| **ID** | `standardExchange_orbital` |
| **Impl path** | `contracts/hooks/uniswap/v4/standardExchange/orbital/` |
| **Report** | `COMPLIANCE_REPORT_standardExchange_orbital.md` |
| **Intention** | Mirror behavior of **H1 orbital** hook, plus **standard buffering + rate provider** for **≥1 leg**. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H7.1 | Orbital/sphere behavioral parity with H1 (same family math/API shape), adjusted only for buffer legs. |
| H7.2 | Buffering + optional rate provider for **≥1** leg (B1–B7). |
| H7.3 | Multi-asset door pattern preserved if H1 has multi-pool doors. |
| H7.4 | Divergences from H1 that are not buffer-related are flagged. |

---

### H8 — Standard Exchange Weighted Buffer

| Field | Value |
|-------|--------|
| **ID** | `standardExchange_weighted` |
| **Impl path** | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| **Report** | `COMPLIANCE_REPORT_standardExchange_weighted.md` |
| **Intention** | Mirror **H3 weighted** hook, plus **standard buffering** for **≥1 leg**. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H8.1 | Weighted product behavior parity with H3. |
| H8.2 | Combinatorial pair doors as in H3. |
| H8.3 | Standard buffering B1–B7 for ≥1 leg. |
| H8.4 | Non-buffer divergences from H3 flagged. |

---

### H9 — Standard Exchange Quad Stable Buffer

| Field | Value |
|-------|--------|
| **ID** | `standardExchange_stable_quad` |
| **Impl path** | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/` |
| **Report** | `COMPLIANCE_REPORT_standardExchange_stable_quad.md` |
| **Intention** | Mirror **H2 stable/quad** hook, plus **standard buffering**. |

**Checkable criteria**

| # | Criterion |
|---|-----------|
| H9.1 | StableSwap-class parity with H2. |
| H9.2 | Combinatorial pair doors as in H2. |
| H9.3 | Standard buffering B1–B7. |
| H9.4 | Non-buffer divergences from H2 flagged. |

---

## 5. Comparison method (how agents must judge)

### 5.1 Evidence hierarchy

1. **Source code** (targets, math libs, repos, facets, package args, interfaces) — primary  
2. **TestBases / hermetic specs** under the same tree or `test/foundry/spec/**` matching the package — secondary (shows intended runtime behavior)  
3. **External reference code** (upstream Orbital, Balancer pools) — baseline for “mirror”  
4. **Co-located product PRD** — tertiary context only; cite conflicts, do not use to override §4  

### 5.2 Verdict vocabulary (required)

Each criterion gets one of:

| Verdict | Meaning |
|---------|---------|
| **MEETS** | Implementation clearly satisfies the intention criterion |
| **PARTIAL** | Some but not all of the criterion; material gaps remain |
| **MISS** | Intention not met or contradicted |
| **N/A** | Criterion not applicable (must justify) |
| **UNKNOWN** | Could not determine from available code/tests (must say what was missing) |

Each **subject** gets an overall:

| Overall | When |
|---------|------|
| **COMPLIANT** | All critical intention criteria MEETS; no MISS on core product identity |
| **MOSTLY COMPLIANT** | Core identity MEETS; minor/partial gaps only |
| **DIVERGENT** | Core identity PARTIAL or MISS (wrong product shape, missing buffering, has curve when none allowed, etc.) |
| **INDETERMINATE** | Too incomplete to judge (empty package, stubs only) — still write the report |

### 5.3 Severity for divergences

| Severity | Use when |
|----------|----------|
| **P0 — Product identity** | Wrong product class (e.g. H4 has CP math; H5 has no buffering/accounting) |
| **P1 — Material behavior** | Buffering skew, opacity broken, multi-doors missing, LP units wrong |
| **P2 — Structural / package** | Missing Diamond/package patterns where required (H1); deploy anti-patterns |
| **P3 — Docs / naming / polish** | Co-located PRD conflicts, NatSpec, naming vs roles |

### 5.4 Upstream fetch (H1)

If upstream `OrbitalHook.sol` is not vendored:

- Prefer `git clone` / sparse fetch of the referenced repo into a **temp** location **or** open via web tools  
- Do **not** vendor it into IndexedEx as part of this program  
- Cite concrete functions/invariants compared  

### 5.5 Peer mirror subjects (H7–H9)

Compare SE-buffer variants to the **implemented** peer under H1/H2/H3 (code), not only to co-located PRDs. If the peer itself is divergent from Balancer/upstream, say so: “H8 mirrors H3, but H3 is already divergent from Balancer weighted” — both facts matter.

---

## 6. Agent program design

This PRD is consumed in **three roles**. No role mutates production Solidity.

### 6.1 Role A — Planner (writes the review execution plan)

**Input:** this PRD only (+ tree listing).  
**Output:**  
`contracts/hooks/uniswap/v4/UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_IMPLEMENTATION_AND_TEST_PLAN.md`

Plan must include:

1. One work item per subject H1–H9  
2. Subagent prompts that **paste or link** the subject’s §4 intention + criteria table  
3. File globs to open (impl path + references)  
4. Parallelism: H1–H9 independent; optional second wave for INDEX rollup  
5. Report path + template compliance checklist  
6. Definition of Done for the **review program** (all 9 reports + INDEX)  

### 6.2 Role B — Analyst subagents (one per subject, preferred)

**Input:** subject ID + §4 section + report path.  
**Output:** that subject’s `COMPLIANCE_REPORT_*.md` only.  
**Allowed tools:** read, grep, list, web/fetch for upstream Orbital; optional `forge test --match-path` **read-only diagnostics** (not required).  
**Forbidden:** `git commit` of code fixes, editing `.sol`, editing co-located product PRDs.

Suggested subagent type: read-only explore / general-purpose with **read-only** capability if available.

### 6.3 Role C — Rollup editor (optional)

**Input:** all nine reports.  
**Output:** `COMPLIANCE_REPORT_INDEX.md` with table:

| ID | Overall | P0 count | P1 count | Top divergence | Report path |

### 6.4 Role D — Remediation PRD author (**out of this program**)

After reports exist, a **later** agent may write per-hook fix PRDs. That agent is **not** started by this PRD’s DoD.

---

## 7. Mandatory report template

Every `COMPLIANCE_REPORT_*.md` **must** use this structure:

```markdown
# Intention Compliance Report: <ID>

- **Subject ID:**
- **Impl path:**
- **Report date:**
- **Analyst / agent:**
- **Overall verdict:** COMPLIANT | MOSTLY COMPLIANT | DIVERGENT | INDETERMINATE
- **Intention summary (from SoT PRD, not co-located PRD):** 1–3 sentences
- **Primary references used:**

## 1. Inventory

| Area | Paths / contracts | Notes |
|------|-------------------|-------|
| Math / curve | | |
| Storage / repo | | |
| Facets / targets | | |
| Package / factory | | |
| Tests | | |
| Co-located product PRD (non-authoritative) | | |

## 2. Criterion scorecard

| Criterion ID | Verdict | Evidence (file:symbol or behavior) | Notes |
|--------------|---------|--------------------------------------|-------|
| … | MEETS/PARTIAL/MISS/N/A/UNKNOWN | | |

## 3. Divergences

| ID | Severity | Summary | Evidence | Suggested remediation theme (no code) |
|----|----------|---------|----------|----------------------------------------|
| D1 | P0/P1/… | | | e.g. "remediation PRD: buffer accounting" |

## 4. Co-located PRD vs operator intention

| Topic | Co-located PRD says | Operator intention (§4) | Conflict? |
|-------|---------------------|-------------------------|-----------|

## 5. Reference baseline notes

- What was compared (Balancer / upstream / peer hook)
- Material accepted V4 limitations (pair doors, etc.)

## 6. Residual risks / open questions

- UNKNOWN criteria, missing tests, incomplete packages

## 7. Recommendations for next program (reports only → fix PRDs)

- Ordered list of remediation PRD titles to consider (no implementation)
```

---

## 8. Planner DoD (Role A)

- [ ] Execution plan file written at path in §3.2  
- [ ] Nine subagent work items mapped to report paths  
- [ ] Explicit **no code mutation** rule restated  
- [ ] Criteria tables for H1–H9 referenced from this PRD (not re-invented from co-located PRDs)  

## 9. Program DoD (after execution)

- [ ] All nine `COMPLIANCE_REPORT_*.md` exist and follow §7  
- [ ] Each report’s scorecard covers **every** criterion ID for that subject  
- [ ] Overall verdict present  
- [ ] P0/P1 divergences have evidence paths  
- [ ] `COMPLIANCE_REPORT_INDEX.md` recommended  
- [ ] **Zero** intentional production code edits in the same change set as “review complete”  

---

## 10. Suggested subagent prompt skeleton (for the plan)

```text
You are an intention-compliance analyst. You do NOT change code.

Source of truth for intention:
  contracts/hooks/uniswap/v4/UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_PRD.md
  Subject section: <ID>

Co-located product PRDs under the impl path are NOT authoritative.
If they conflict with the SoT PRD, document the conflict.

Read implementation under: <impl path>
Compare to references listed in the subject section.
Write report to: <report path>
Use the mandatory template in §7.
Score every criterion ID.
Do not create remediation code. You may only suggest remediation PRD titles.
```

---

## 11. File map (program artifacts)

```text
contracts/hooks/uniswap/v4/
  UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_PRD.md              # this file (SoT)
  UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_IMPLEMENTATION_AND_TEST_PLAN.md  # Role A
  COMPLIANCE_REPORT_orbital.md
  COMPLIANCE_REPORT_stable_quad.md
  COMPLIANCE_REPORT_weighted.md
  COMPLIANCE_REPORT_standardExchange_single.md
  COMPLIANCE_REPORT_standardExchange_constantProduct_single.md
  COMPLIANCE_REPORT_standardExchange_dual.md
  COMPLIANCE_REPORT_standardExchange_orbital.md
  COMPLIANCE_REPORT_standardExchange_weighted.md
  COMPLIANCE_REPORT_standardExchange_stable_quad.md
  COMPLIANCE_REPORT_INDEX.md
```

Implementation trees remain read-only subjects (H1–H9 paths in §4).

---

## 12. Operator intention recap (verbatim intent, compressed)

| Subject | One-line intention |
|---------|-------------------|
| `orbital/` | Reimplement ethglobal OrbitalHook with Diamond storage + Package patterns |
| `stable/quad/` | Mirror Balancer Stable; multi-pool doors for token combinations |
| `weighted/` | Mirror Balancer Weighted; multi-pool doors for token combinations |
| `standardExchange/single/` | SE deposit/withdraw route wrapper; no curve; no held liquidity |
| `standardExchange/constantProduct/single/` | Balancer-like CP; buffer one leg into SE + optional rate provider; virtual reserve / anti-skew; trader opacity; native/rated LP |
| `standardExchange/dual/` | Like single CP buffer but two pair tokens on CP; native LP |
| `standardExchange/orbital/` | Orbital + standard buffering ≥1 leg |
| `standardExchange/weighted/` | Weighted + standard buffering ≥1 leg |
| `standardExchange/stable/quad/` | Quad stable + standard buffering |

---

## 13. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v1.0** | 2026-08-08 | Initial LOCKED PRD from operator intentions; co-located product PRDs demoted for this program; reports-only DoD; nine subjects + agent roles |

---

## 14. Next step for humans / orchestrators

1. Assign **Role A** to write the review **implementation plan** from this PRD.  
2. Execute the plan with **Role B** subagents (parallel H1–H9).  
3. Optional **Role C** index.  
4. Stop. Hand reports to a separate remediation-PRD program if divergences warrant it.
