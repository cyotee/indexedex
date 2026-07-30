# DETF Merits — Complete Research & Writing Program

| Field | Value |
|-------|--------|
| **Status** | Phase 3 **LOCKED**; Phases 1–2 + 4 draft **done**; Phase 5 polish in progress |
| **Created** | 2026-07-29 |
| **Updated** | 2026-07-30 — Phase 3 complete; FORMAL_DEFINITIONS + LITEOPAPER_DRAFT + FIGURE_MANIFEST |
| **Campaign PRD** | [`research/scenarios/detf/singleSe/DETF_Research_PRD.md`](../../scenarios/detf/singleSe/DETF_Research_PRD.md) |
| **Phase 3 PRD (execution)** | [`research/scenarios/detf/singleSe/DETF_Research_Phase3_PRD.md`](../../scenarios/detf/singleSe/DETF_Research_Phase3_PRD.md) — harness + **D0–D9** done bar |
| **Phase 3 implementation plan** | [`research/scenarios/detf/singleSe/DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md`](../../scenarios/detf/singleSe/DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Audience** | Protocol builders, research agents, writing leads |
| **Primary deliverable** | DETF litepaper (then optional whitepaper expansion) |
| **Genre** | Design + mechanism paper with measured appendix — **not** mainnet APY marketing |
| **Canonical product narrative** | [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../../../docs/marketing/DETF_NARRATIVE_SPINE.md) |
| **Compound / expansion handoff** | [`contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md`](../../../contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md) |
| **Public education surface** | Frontend `/research` notes (`detf`, `detf-types`, `bond-vs-mint`, `rate-providers`) — must absorb expansion/compound |
| **Research methodology** | [`research/RESEARCH_PLAYBOOK.md`](../../RESEARCH_PLAYBOOK.md) |
| **Science roll-up** | [`research/MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) |
| **Product law (modes)** | [`contracts/vaults/detf/DETF_Threshold_Modes_PRD.md`](../../../contracts/vaults/detf/DETF_Threshold_Modes_PRD.md) (**LOCKED**) |
| **Product law (compound + expansion)** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) (**LOCKED**) |

**Rule:** When this program conflicts with family PRDs, threshold-modes PRD, or compound/expansion PRD on product behavior, **product PRDs win**. When it conflicts with locked chart conventions, **`research/README.md` conventions win**. When it conflicts with public claim language, **`DETF_NARRATIVE_SPINE.md` + compound/expansion handoff** win.

---

## 0. Executive summary

### 0.1 Goal

Produce a **claim-safe litepaper** (then optional whitepaper) that:

1. Defines the DETF product pattern rigorously enough for builders and skeptical readers.
2. Presents **benefits as properties** (not promised returns).
3. **Proves** what can be proven with hermetic, production-first scenarios.
4. Clearly labels design, code-tested, and measured evidence so marketing and science stay one spine.

### 0.2 Working thesis

> A DETF is a reproducible onchain product pattern—one ERC-20 share over a real multi-asset reserve, with mint/burn and synthetic valuation derived from that same reserve, bonding into protocol-owned depth, deploy-time Policy or Open rules, **keeper-free protocol compounding of protocol bond rewards into reserve BPT**, and—on **Policy** units when synthetic is rich—**time-based natural supply expansion** to bond holders—whose nested Standard Exchange legs can keep marks fair under underlying demand when rate providers are used.

### 0.3 Working titles

| Deliverable | Title (draft) |
|-------------|----------------|
| **Litepaper** | *DETF Litepaper: Reserve-Backed Onchain Shares, Nested Mark Integrity, and Bond-Ledger Rewards* |
| **Whitepaper** | *Decentralized ETF Product Patterns: Reserve-Pool Pricing, Nested Mark Integrity, Seigniorage, Expansion, and Protocol Compound* |

### 0.4 Strategic judgment (locked for this program)

| Question | Decision |
|----------|----------|
| Novel abstract math / LVR re-derivation? | **No** — cite industry work; formalize *our* definitions only |
| Another SE rate-provider mega-matrix? | **No** — reuse existing findings; do not re-run casually |
| DETF-native hermetic scenarios? | **Yes** — required to prove Policy/Open, inert→live, preview honesty; expansion negatives on Open/inert |
| Monte Carlo / multi-family APY sims? | **No** for v1 |
| Gold family for empirics | **Single Standard Exchange DETF** (`contracts/vaults/detf/standardExchange/single/`) only for v1; research attaches **Uni V2 SE** (not Aero TestBase default) |
| Synthetic drive | **Strict real trades only** on Uni V2 / SE underlyings |
| Campaign figures | **PNG F1–F4 required**; F7–F9 with stretch D7–D9 |
| D2 deadband | Flexible / N/A if already mint-allowed at t_live |
| **Natural expansion** | Policy + live + synth > mintThreshold only; **Open never**; bond ledger only; deploy-time params |
| **Protocol compound** | Protocol NFT rewards → protocol BPT (single-sided DETF join); users claim free DETF; no APY promise |
| Expansion/compound in litepaper | **Design formalization required**; **measured** D8/D9 preferred but may cite product law + unit tests if stretch deferred—**never invent** |
| Product type map (taxonomy) | **Four** live families: Single SE · multi-vault weighted · multi-vault stable (composed) · mixed-buffer multi-vault stable |
| **Removed package** | `contracts/vaults/detf/composed/single` (**SingleVaultDetf**) — **out of research universe**. Do not SUT, cite as gold path, use as behavioral research reference, or list as a product type. |
| Four DETF types in paper | **Taxonomy / design chapter** for the four live families only — not four full empirical programs |
| DualLiquidity role | Supporting composition evidence only — **not** hero product |

### 0.5 Program at a glance

```text
Phase 0  Brief + claim matrix + scope lock
Phase 1  Harvest existing SE (and optional DualLiquidity) evidence + figures
Phase 2  Light formalization (synthetic, gates, residual) — writing, not new theory
Phase 3  DETF research harness + scenarios D0–D7
Phase 4  Litepaper draft + figures + internal review
Phase 5  Public polish (PDF, frontend R4, claim alignment)
Phase 6  Whitepaper expansion (optional)
Phase 7  Fork validation + academic upgrades (optional / last)
```

---

## 1. Context inventory

### 1.1 What already exists (do not rediscover)

#### A. Hermetic research (measured)

| Area | Location | Headline |
|------|----------|----------|
| Uni V2 SE Mode A | `research/scenarios/uniswapV2Se/MODE_A_FINDINGS.md` | SE rates re-mark with Uni demand; fee vs price P&L split |
| Uni V2 SE Mode C | `research/scenarios/uniswapV2Se/MODE_C_FINDINGS.md` | Modest volume: no free Balancer residual under rates-on |
| Rate providers R+ vs R− | `research/scenarios/uniswapV2Se/rateProviderCompare/` | R+ residual ≈ 0; R− residual scales; fee is arb presentation threshold |
| DualLiquidity v1/v2 | `research/scenarios/dualLiquidityLinkedCrossVersion/` | Nested linked liquidity; rates/preview; volume attribution |
| Marketing roll-up | `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` | Publishable claim spine for SE + DualLiquidity |

#### B. Product education (pitched, partially unmeasured for DETF core)

| Surface | Path | Role |
|---------|------|------|
| Research index | `/research` | Premier: create DETFs; Protocol DETF secondary |
| DETF overview | `/research/detf` | Benefits, Policy/Open, hierarchy |
| Types | `/research/detf-types` | Four **live** compositions (no `composed/single`) |
| Bond vs mint | `/research/bond-vs-mint` | Liquid share vs seigniorage path — **needs expansion/compound update** |
| Rate providers | `/research/rate-providers` | Accuracy vs reprice + SE evidence |
| Content source | `frontend/app/content/research/articles/*.ts` | Claim-safe TS modules |
| Design note | `frontend/RESEARCH_SECTION_DESIGN.md` | R1–R4 delivery |
| Compound/expansion handoff | `contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md` | Docs/UI law summary (**2026-07-30**) |

#### C. Normative product law

| Doc | Role |
|-----|------|
| `docs/marketing/DETF_NARRATIVE_SPINE.md` | Public story + disclaimers |
| `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` | Policy/Open, synthetic gates (**LOCKED**) |
| `contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` | Protocol compound + natural expansion (**LOCKED**) |
| AGENTS.md DETF section | Role names, inert→live, testing expectations |
| Family PRDs under `contracts/vaults/detf/**` | Per-package rules |

#### D. Prior art in-repo (cite carefully)

| Artifact | Path | Use |
|----------|------|-----|
| Liquidity Trees litepaper | `docs/research/Pachira - Liquidity Trees Litepaper.pdf` | Nested liquidity ancestry |
| IL resolution proof | `docs/research/Impermanent Loss Resolution Proof.pdf` | Optional background only |

#### E. DETF hermetic gap (closed Phase 3)

Prior playbook Tier 5 noted DETF research not started. **Closed 2026-07-30:** Single SE + Uni V2 D0–D9, FINDINGS RQ1–RQ10, figures F1–F4 + F7–F9. See `research/scenarios/detf/singleSe/FINDINGS.md`. Remaining work is writing polish (Phases 4–5), not re-running the harness.

---

## 2. Claims matrix (what the paper will defend)

Every paragraph in the litepaper should map to a row. Empty measured cells must be either filled in Phase 3 or demoted to design / future work.

| ID | Claim (aligned with public pitch) | Evidence class today | Target class for litepaper | Primary phase |
|----|-----------------------------------|----------------------|----------------------------|---------------|
| **C1** | One ERC-20 share over a real multi-asset reserve (not dashboard NAV) | Design + code | Design formalization | 0, 2, 4 |
| **C2** | Pricing engine = reserve pool (balances, weights, fees, rate providers) | Design + code | Definition + synthetic series (D*) | 2, 3, 4 |
| **C3** | Deploy inert; first successful bond → live + protocol-owned depth | Tests / PRD | Hermetic D0–D1 | 3, 4 |
| **C4** | Policy price-gates mint/burn from synthetic; Open does not (fees may still apply) | PRD + code | Hermetic D2–D5 | 3, 4 |
| **C5** | Instances immutable / unowned after deploy (normal operation) | Product law | Design + short threat note | 2, 4 |
| **C6** | Closed-form vault-share ↔ DETF: preview ≈ execution | Unit/integration tests | One measured table (D3 path) | 3, 4 |
| **C7** | Nested SE legs with rates on keep mid×rate residual ≈ 0 under Uni-driven demand | **Measured** | Lead empirical appendix | 1, 4 |
| **C8** | Residual lag ≠ free arb; fills when residual clears fee stack | **Measured** | Same appendix | 1, 4 |
| **C9** | Mint = liquid DETF; bond = protocol depth + seigniorage/claim path; bond ledger receives rewards (not free DETF-only holders for expansion) | Education + PRD | D7 + accounting diagram | 3, 4 |
| **C10** | Four **live** composition types for different baskets (one pattern, many packages) — **not** including removed `composed/single` | Design | Taxonomy chapter | 4, 6 |
| **C11** | Premier offer = create DETFs; Protocol DETF = fee-share path (amounts not guaranteed) | Narrative | Product hierarchy section only | 4 |
| **C12** | **Natural supply expansion:** Policy + live + synthetic > mintThreshold may mint free DETF over time to **bond** effective shares; **Open never**; inert/non-rich never | Product law + tests | Design required; D5 negatives; D8 measured preferred | 2, 3, 4 |
| **C13** | **Protocol compound:** protocol NFT rewards auto-sink into **protocol-owned reserve BPT** (single-sided DETF join); users still claim free DETF; claim backing **can** improve (not guaranteed) | Product law + tests | Design required; D9 measured preferred | 2, 3, 4 |

### 2.1 Non-claims (must appear in paper and stay off figures)

Do **not** research or write toward these as proven results:

- Registered securities ETF / legal ownership of offchain underlyings  
- Guaranteed APY, peg, rebase, or “(3,3)” performance  
- Open = free / no fees / invented returns / **natural expansion**  
- Expansion pays **all** DETF holders (unlocked free DETF)  
- User bonds auto-compound into the pool (they **claim** free DETF)  
- Protocol compound guarantees claim redemption growth / fixed coupon  
- Keeper or team required for product to work  
- Protocol DETF fee size as a promise  
- Mainnet reprice volume guaranteed under rates off  
- DualLiquidity as the DETF seigniorage product  
- Zero threshold args imply Open  
- Policy thresholds guarantee stability or yield  
- Olympus legal/product affiliation  

---

## 3. Benefits the paper will present

Present benefits as **properties** with an evidence class. Never as performance guarantees.

| Benefit | Evidence class | Supporting claim IDs |
|---------|----------------|----------------------|
| ETF-shaped basket exposure without a discretionary PM | Design | C1, C10 |
| Mint, burn, and synthetic share one pricing engine (the reserve) | Design + DETF scenarios | C2, C4 |
| Clear inert/live state; bonding builds protocol-owned depth | DETF scenarios | C3, C9 |
| Explicit monetary policy (Policy vs Open) at deploy | DETF scenarios + formalization | C4 |
| No admin rewrite of a live instance as product model | Design / threat note | C5 |
| Nested vault-share legs can track live claim value (rates on) | Measured SE | C7 |
| Lag can invite reprice volume (rates off) without free lunch | Measured SE | C8 |
| Liquid path (mint) vs seigniorage path (bond/claim) | Design + D7 | C9 |
| **Capital seigniorage** vs **natural expansion when rich** (labeled separately) | Design + D5/D8 | C12, C9 |
| **Protocol compound** deepens protocol reserve BPT (claim backing *can* improve) | Design + D9 | C13 |
| Keeper-free accrual / compound (no bot required for correct product) | Design | C12, C13 |
| Composable package types for different baskets | Taxonomy | C10 |
| Platform: stand up many DETFs; optional protocol fee path | Product hierarchy | C11 |

---

## 4. Math program (minimal)

### 4.1 What we will *not* do

- Re-derive LVR / AMM theory  
- Design new exact-out solvers or approximate search routes  
- Optimal fee or threshold calibration theory  
- Game-theoretic equilibrium of Open vs Policy  
- IL “resolution” as a DETF selling point without a new, scoped paper  

### 4.2 What we *will* formalize (documentation-grade math)

Time budget: **~1–2 writing days**, not a multi-week math project.

| Item | Deliverable | Notes |
|------|-------------|-------|
| **Synthetic price** | Definition matching PRD/code | Rate-scaled claim on owned reserve BPT (incl. bond NFT vault when peers do) ÷ DETF `totalSupply`; abstract 1e18 peg narrative |
| **Policy gates** | Inequalities | Mint iff synthetic > mintThreshold; burn iff synthetic < burnThreshold; equality = deadband; defaults via `DETFThresholdPolicy` |
| **Open mode** | Explicit non-gate | Threshold getters may still store resolved values; gates always pass when live; **no natural expansion** |
| **Natural expansion eligibility** | Predicate | Policy ∧ live ∧ synthetic > mintThreshold; time-based accrual to bond effective shares; deploy-time rate/caps |
| **Protocol compound** | Mechanism sketch | Protocol NFT free DETF rewards → single-sided DETF reserve join → protocol BPT ↑ (best-effort) |
| **Residual / fairness** | Identity used in SE research | e.g. residual ≈ mid_index × rate_index − 1 under stated conventions |
| **Preview honesty** | Statement of closed-form routes | Error 0 or documented few-wei only when multi-leg forces it |

Store formal snippets in:

```text
research/papers/detf-litepaper/FORMAL_DEFINITIONS.md
```

(Created in Phase 2.)

---

## 5. Simulation / scenario program

### 5.1 Reuse (no new runs unless parameters change)

| Study | Reproduce command (if needed) | Use in paper |
|-------|-------------------------------|--------------|
| Mode A | `./research/run_mode_a.sh` | 1–2 figures: re-mark with demand |
| Rate provider compare | `./research/run_rate_provider_compare.sh` | Lead appendix: R+ vs R− residual; fee threshold |
| High-vol fee threshold | already complete | Cite mul25 fills finding; do not re-run casually |
| DualLiquidity | optional | One short box max; composition only |

**Anti-pattern:** Expanding SE Mode B/C or fee ladders “because the paper feels thin.” Fix thinness with DETF D-scenarios, not more SE noise.

### 5.2 New DETF scenarios (gold family: Single SE DETF)

Production-first rules (non-negotiable):

- Real DETF diamond / DFPkg / manager / registry / fee oracle path  
- Real SE vault legs (protocol ports or fork fixtures as appropriate)  
- No mocks of SUT  
- Role names only (`rateAsset`, `vaultShare`, `detfToken`, …)  
- JSONL via research telemetry pattern; `meta.json` stamped; `NOTES.md` required  
- Policy proofs use **default resolved thresholds**, driven by **real underlying trades** where possible  

| ID | Scenario | Drive | Success criteria | Claims |
|----|----------|-------|------------------|--------|
| **D0** | Deploy inert | Deploy | Not live; user mint blocked; **no expansion** after warp | C3, C12 |
| **D1** | First bond → live | Bond vault shares (family path) | Live; protocol-owned depth / bond principal accounting | C3, C9 |
| **D2** | Policy mint blocked in deadband | Live + synthetic in band | Mint blocked; **no expansion** if deadband | C4, C12 |
| **D3** | Policy mint allowed | Underlying demand moves synthetic **above** mintThreshold | Mint succeeds; **preview == execution**; label capital seigniorage vs expansion | C2, C4, C6 |
| **D4** | Policy burn blocked / allowed | Symmetric below burnThreshold | Burn only when allowed; no expansion when not rich | C4, C12 |
| **D5** | Open control | Same shocks, Open deploy + warp | Mint/burn ungated; fees honest; **no natural expansion** | C4, C12 |
| **D6** | Capital seigniorage dilution (stretch) | Sequence of allowed Policy mints | Supply, synthetic, composition; **not** expansion path | C2 |
| **D7** | Bond vs mint books (stretch) | Parallel minter vs bonder | Free DETF vs bond rewards; expansion eligibility | C9, C12 |
| **D8** | Natural expansion positive (stretch) | Policy + rich (real trades) + time | Bond pendingRewards ↑; Open twin does not | C12 |
| **D9** | Protocol compound (stretch) | Accrue protocol rewards → compound | Protocol BPT ↑; user still claims free DETF | C13 |

### 5.3 Minimum figure pack (litepaper)

| Fig | Content | Source phase |
|-----|---------|--------------|
| F1 | Lifecycle: inert → bond → live | D0–D1 |
| F2 | Synthetic vs peg + mint/burn threshold bands + allowed regions | D2–D4 |
| F3 | Underlying demand → synthetic (Policy world) | D3 |
| F4 | Preview vs execution (table or scatter) | D3 |
| F5 | R+ vs R− residual (SE appendix) | Phase 1 harvest |
| F6 | Fee-as-arb / residual vs fills (SE appendix) | Phase 1 harvest |
| F7 | Bond vs mint holdings / reward eligibility | D7 (stretch) |
| F8 | Expansion: Policy rich + time vs Open no-accrual | D5 + D8 |
| F9 | Protocol compound: protocol BPT before/after | D9 (stretch) |
| F10 | Reserve composition stack over capital mints (optional) | D6 |

### 5.4 Explicitly out of scope for v1 simulations

- Monte Carlo multi-seed APY / expansion “yield curves” for marketing  
- All four live DETF families full matrices  
- Any work on removed `composed/single` / SingleVaultDetf  
- Mainnet performance attribution / claim APY  
- Claiming DualLiquidity Mode C as DETF seigniorage  
- Parameter optimization of thresholds for “best peg”  
- Open-mode expansion demos (product forbids it)  

---

## 6. Writing deliverables

### 6.1 Litepaper outline (Phase 4)

Target: **8–12 pages** (PDF or Markdown→PDF).

| § | Section | Content | Claims |
|---|---------|---------|--------|
| 0 | Abstract | Problem, approach, 2–3 results, limitations | — |
| 1 | Introduction | ETF-shaped demand; failure modes of manager / off-pool NAV / opaque rebalancer | C1 |
| 2 | Background | Nested SE + Balancer rate providers; LVR citation (fees vs adverse selection) | C7, C8 |
| 3 | DETF model | Roles, reserve, synthetic, lifecycle, Policy/Open, bond/mint | C1–C5, C9 |
| 3b | **Rewards: capital seigniorage, natural expansion, protocol compound** | Bond ledger; Policy-only expansion; protocol BPT sink; Open never expands | C12, C13, C9 |
| 4 | Merits | One property per subsection; evidence class labeled | All benefits table |
| 5 | Nested mark integrity (measured) | R+/R−; residual; fee threshold | C7, C8 |
| 6 | DETF scenarios (measured) | D0–D5 (D6–D9 if ready) | C2–C4, C6, C9, C12–C13 |
| 7 | Composition types (short) | Four **live** families only; choose-by-basket table; no `composed/single` | C10 |
| 8 | Product hierarchy | Create DETFs vs Protocol DETF; no fee promises | C11 |
| 9 | Limitations & risks | Hermetic, fee transferability, not registered ETF, IL/LVR on legs, no expansion APY | Non-claims |
| 10 | Future work | Multi-family, LVR series, fork validation, full D8/D9 if deferred | Phase 6–7 |
| 11 | Conclusion | Restate properties, not performance | — |
| A | Methodology appendix | Reproduce commands, fixture notes, `meta.json` contract | — |

**Write order:** §3–3b–4 and formal definitions first → §5–6 figures → §7–9 → §1–2 → abstract last.

### 6.2 Whitepaper expansion (Phase 6)

Target: **15–25 pages**. Litepaper body + :

- Deeper related work (Set/Index/OHM-class/ETF wrappers — careful language; expansion analogy ≠ affiliation)  
- Threat model (immutability, abandonment, malicious legs, residual-as-mev, expansion dilution)  
- Full type appendix with composition diagrams  
- D6–D9 if deferred from litepaper  
- Optional multi-vault weighted single scenario  
- Full methodology and limitations  

### 6.3 Repo writing artifacts (tracked)

```text
research/papers/detf-litepaper/
  RESEARCH_AND_WRITING_PROGRAM.md   # this file
  BRIEF.md                          # Phase 0
  FORMAL_DEFINITIONS.md             # Phase 2
  OUTLINE.md                        # Phase 0/4
  CLAIMS_MATRIX.md                  # living mirror of §2
  LITEPAPACK_DRAFT.md                # Phase 4 (or .tex if preferred)
  FIGURE_MANIFEST.md                # path + caption + claim id
  REVIEW_NOTES.md                   # Phase 4/5 feedback log

research/scenarios/detf/singleSe/
  DETF_Research_PRD.md              # Phase 3
  DETF_Research_IMPLEMENTATION_AND_TEST_PLAN.md
  FINDINGS.md                       # after runs
  AGENT_RESEARCH_REPORT.md          # handoff when locked
```

### 6.4 Frontend / marketing alignment (Phase 5)

| Action | Purpose |
|--------|---------|
| Keep spine language in lockstep with litepaper non-claims | One public story |
| Update `/research/detf`, `/research/bond-vs-mint`, Policy/Open copy per compound/expansion handoff | Expansion = Policy only; protocol compound → BPT; users claim free DETF |
| Optional R4: hand-picked PNGs under `frontend/public/research/` | Site mirrors paper figures |
| Do **not** dump engineer FINDINGS into UI | Claim-safe notes only |
| Update `MARKETING_AND_PERFORMANCE_FINDINGS.md` when DETF scenarios lock | Science roll-up |

---

## 7. Phases (complete program)

---

### Phase 0 — Brief, matrix, and scope lock

**Goal:** Decide what the paper will and will not say before any new harness or prose sprawl.

**Duration (guideline):** 1–2 days.

**Work:**

1. Author `BRIEF.md`:
   - Research question (one sentence)  
   - Audience + venue (industry litepaper vs internal memo → public PDF)  
   - 2–4 lead claims  
   - Non-claims list (copy from spine)  
   - Gold family: Single SE DETF  
   - Interim path? (design + SE only) vs full (DETF scenarios required) — **default: full litepaper with Phase 3**  
2. Freeze `CLAIMS_MATRIX.md` from §2.  
3. Author `OUTLINE.md` (litepaper § map).  
4. Decide figure budget (target F1–F6 minimum).  

**Exit criteria:**

- [ ] Brief reviewed by product owner  
- [ ] Every public pitch claim maps to C1–C13 or is rejected  
- [ ] Explicit “no Monte Carlo / no APY” scope line in brief  

**Outputs:** `BRIEF.md`, `CLAIMS_MATRIX.md`, `OUTLINE.md`

---

### Phase 1 — Harvest existing measured evidence

**Goal:** Lock the nested integrity appendix without re-running large matrices.

**Duration:** 2–4 days.

**Work:**

1. Read (do not rewrite):  
   - `rateProviderCompare/AGENT_RESEARCH_REPORT.md`  
   - `FINDINGS.md` (incl. high-vol)  
   - Mode A findings  
2. Select **hand-picked** figures for the paper (paths into `FIGURE_MANIFEST.md`):  
   - Fairness / residual R+ vs R−  
   - Fee-threshold / probes at high vol (where fills appear)  
   - Optional Mode A price index + normalized P&L (one demand direction)  
3. Write 1-page “Nested mark integrity” memo captions (mechanism, not “line went up”).  
4. Optional one-paragraph DualLiquidity box (composition only).  
5. If plots missing locally: regenerate with documented runners; stamp `meta.json`.  

**Exit criteria:**

- [ ] F5 and F6 paths + captions locked  
- [ ] Transferability caveats written (research fee 5% ≠ all production fees)  
- [ ] No new SE scenario code  

**Outputs:** `FIGURE_MANIFEST.md` (SE entries), caption drafts for §5

---

### Phase 2 — Light formalization

**Goal:** Math that is *definitions of our system*, not novel theory.

**Duration:** 1–2 days (can overlap Phase 3 start).

**Work:**

1. Write `FORMAL_DEFINITIONS.md`:  
   - Role table (rateAsset, vaultShare, reserveBpt, detfToken, protocol NFT, …)  
   - Synthetic price  
   - Policy / Open predicates  
   - **Natural expansion eligibility** predicate  
   - **Protocol compound** sink sketch  
   - Residual metric (SE appendix)  
   - Liveness predicate  
2. Cross-check against `DETFThresholdPolicy`, compound/expansion PRD, and Single SE gold paths.  
3. Align wording with frontend research notes + handoff (Open = no price restrictions **and** no expansion; users claim free DETF).  

**Exit criteria:**

- [ ] Definitions reviewable against PRD/code without ambiguity  
- [ ] No conflict with **LOCKED** threshold-modes or compound/expansion PRDs  

**Outputs:** `FORMAL_DEFINITIONS.md`

---

### Phase 3 — DETF research harness and scenarios

**Goal:** Produce measured evidence for DETF-specific claims C2–C4, C6, C9, C3, and C12 negatives (C12/C13 positive paths preferred via D8/D9).

**Duration:** ~1–2 weeks depending on harness reuse from gold TestBases (day-scale target if reuse is high).

#### Phase 3a — PRD + plan

1. Campaign PRD at `research/scenarios/detf/singleSe/DETF_Research_PRD.md` (**includes compound/expansion**)  
2. Implementation notes in PRD (peel plan only if bulk) — **Uni V2 SE** attachment  
3. Telemetry schema: synthetic, thresholds, live flag, supply, reserve balances, preview/execution, bond state, **pendingRewards**, **protocol BPT** when available  

#### Phase 3b — Harness

1. Foundry research scripts under `scripts/foundry/research/detf/singleSe/` (or agreed path)  
2. Runner shell: `research/run_detf_single_se.sh`  
3. Plot scripts only if new chart *kinds* needed (prefer reuse + small new plotters)  
4. Production deploy path only  

#### Phase 3c — Execute D0–D5 (litepaper minimum)

Run order: D0 → D1 → D2 → D3 → D4 → D5.

Policy default thresholds; drive synthetic via **real Uni V2 trades only** for D3/D4.  
D0/D2/D5 include **expansion negative** checks; D5 **must** show Open never expands.

#### Phase 3d — Optional D6–D9 (if time; else whitepaper / product-law citation)

Capital dilution (D6), bond vs mint (D7), expansion positive (D8), protocol compound (D9).

#### Phase 3e — Findings lock

1. `FINDINGS.md` + `NOTES.md` per run  
2. `AGENT_RESEARCH_REPORT.md` one-paragraph answers (include expansion/compound)  
3. Append rows to `research/SCENARIO_LOG.md`  
4. Update `MARKETING_AND_PERFORMANCE_FINDINGS.md` with DETF section when locked  

**Exit criteria (litepaper minimum):**

- [ ] D0–D5 complete with series + notes + **PNG F1–F4**  
- [ ] Preview==execution documented on at least one successful Policy mint  
- [ ] Open twin demonstrates non-gating **and no natural expansion**  
- [ ] Expansion negatives documented; positive expansion/compound either measured or explicitly deferred with product-law citation  
- [ ] Agents can reuse findings without re-running full pack  

**Outputs:** scenarios tree, `out/detf/singleSe/**` (generated), FINDINGS, figure paths for F1–F4

---

### Phase 4 — Litepaper draft and internal review

**Goal:** First complete prose draft grounded only in Phases 0–3 evidence.

**Duration:** 3–5 days writing + review loop.

**Work:**

1. Draft `LITEOBACK_DRAFT.md` (or LaTeX) per §6.1.  
2. Insert figures with captions that state **mechanism**.  
3. Label every merit: Design / Measured (SE) / Measured (DETF) / Product.  
4. Limitations section equal weight to merits.  
5. Cold-read by someone who does not know DETF.  
6. Adversarial pass: every absolute claim checked against non-claims.  

**Exit criteria:**

- [ ] Reader can restate: what a DETF is; pool-as-pricing-engine; Policy vs Open; expansion = Policy+rich only; protocol compound → BPT; rates-on ≠ yield; 4–6 figures make sense  
- [ ] Zero invented APY / Open expansion / all-holder rebase  
- [ ] Source paths cited for measured claims  
- [ ] Capital seigniorage vs natural expansion labeled separately  

**Outputs:** draft litepaper, `REVIEW_NOTES.md`, updated figure manifest

---

### Phase 5 — Public polish and distribution

**Goal:** Ship a public-facing artifact without breaking claim safety.

**Duration:** 2–4 days.

**Work:**

1. PDF export + version stamp (date, git commit).  
2. Optional: host path / docs link / research site teaser.  
3. Frontend R4 (optional): copy hand-picked figures to `frontend/public/research/` and reference from notes **only if** captions stay claim-safe.  
4. Align `/research/detf` and rate-providers language if paper refined wording.  
5. Changelog entry in this program file status table.  

**Exit criteria:**

- [ ] Public PDF or stable Markdown release tag  
- [ ] Marketing may cite only claims present in paper limitations+body  
- [ ] No contradiction with narrative spine  

**Outputs:** release PDF/Markdown, optional frontend figure pack

---

### Phase 6 — Whitepaper expansion (optional)

**Goal:** Deeper industry / systems document after litepaper is stable.

**Duration:** 1–3 weeks part-time.

**Work:**

1. Expand related work and comparison tables (ETF wrappers, index tokens, OHM-class, pure 4626 baskets, DualLiquidity as nested SE composition — careful).  
2. Complete D6–D7 if skipped.  
3. Type appendix (four **live** families only) with diagrams (reuse detf-types composition diagrams). Never document removed `composed/single`.  
4. Optional single Multi-Vault Weighted scenario (distinct leg valuations).  
5. Optional Mixed-Buffer bootstrap scenario if product priority.  
6. Threat model section.  
7. Full methodology appendix.  

**Exit criteria:**

- [ ] Whitepaper adds depth without new overclaims  
- [ ] Litepaper remains the short public entry; whitepaper is long form  

**Outputs:** whitepaper draft/PDF, expanded scenarios if any

---

### Phase 7 — Validation and academic upgrades (optional / last)

**Goal:** Raise external credibility without changing product claims.

| Track | Work | When |
|-------|------|------|
| **Fork validation** | Same telemetry schema on Base (or target) fork | After hermetic DETF story solid |
| **LVR / hedged LP series** | SE book fee vs adverse selection upgrade | Only if seeking academic-grade LP economics |
| **Multi-protocol Mode A** | Aero / Camelot SE same matrix | After Single SE DETF paper ships |
| **Monte Carlo regimes** | Only for internal risk memos, not litepaper claims | Explicitly non-marketing |

**Exit criteria:** Separate findings docs; do **not** silently rewrite litepaper claims.

---

## 8. Workstreams mapped to phases

| Workstream | Name | Phases | Owns |
|------------|------|--------|------|
| **WS0** | Scope & claims | 0 | Brief, matrix, non-claims |
| **WS1** | Foundation rails (reuse SE) | 1 | Nested integrity appendix |
| **WS2** | Formalization | 2 | Definitions |
| **WS3** | DETF scenarios | 3 | D0–D7, FINDINGS |
| **WS4** | Writing | 4–5 | Litepaper + release |
| **WS5** | Expansion | 6–7 | Whitepaper + fork/LVR |

Dependency graph:

```text
WS0 ──► WS1 ──► WS4
  │       ▲
  └──► WS2 ──┘
  │
  └──► WS3 ──► WS4 ──► WS5
```

WS1 and WS2 can run in parallel after WS0.  
WS3 is the critical path for a “proves DETF claims” litepaper.  
**Emergency interim paper:** WS0 + WS1 + WS2 + WS4 with DETF claims labeled *design/code-tested only* — only if Phase 3 is delayed; label the paper accordingly.

---

## 9. Operating procedure (session checklist)

Inherited from `RESEARCH_PLAYBOOK.md`; apply to all new DETF runs:

1. State the question in one sentence.  
2. Pick the lowest tier that answers it.  
3. One drive variable per run.  
4. Production-first deploy.  
5. Export via research telemetry (not ad-hoc logs as plot source).  
6. Plot offline; stamp meta.  
7. Write `NOTES.md` before calling a run “done.”  
8. If confused, simplify — do not add features.  

**Writing sessions:**

1. One claim per subsection.  
2. Prefer definitions and invariants over adjectives.  
3. Separate design merits from measured results with labels.  
4. Keep a “Not claiming” box near strong sentences.  

---

## 10. Success criteria

### 10.1 Litepaper done

- [ ] C7–C8 measured and figured  
- [ ] C1–C5 formalized in plain + precise language  
- [ ] C3–C4, C6 measured via D0–D5 (or paper explicitly scoped down and labeled)  
- [ ] C9 at least design-complete; D7 preferred  
- [ ] C10 taxonomy present without false empirics  
- [ ] C11 product hierarchy present without fee promises  
- [ ] **C12** expansion formalized; Open/inert negatives measured (D5/D0); positive path D8 or product-law + unit-test citation  
- [ ] **C13** protocol compound formalized; D9 measured preferred or product-law + unit-test citation  
- [ ] Capital seigniorage vs natural expansion **labeled separately** in prose  
- [ ] Limitations section complete (incl. no expansion APY / no claim coupon)  
- [ ] Reproduce path exists for every measured figure  
- [ ] Aligns with narrative spine, compound/expansion handoff, and frontend research notes  

### 10.2 Whitepaper done (optional)

- [ ] All litepaper criteria  
- [ ] Related work + threat model  
- [ ] Type appendix  
- [ ] D6–D9 complete  
- [ ] Methodology appendix sufficient for external engineer reproduction  

### 10.3 Program anti-goals

- [ ] No mainnet APY as proof of merits  
- [ ] No Open expansion / all-holder rebase marketing  
- [ ] No second public story  
- [ ] No DualLiquidity as DETF hero  
- [ ] No mock DETF research  
- [ ] No re-open of locked Policy/Open or compound/expansion product law without PRD revision  

---

## 11. Effort estimate (guideline only)

| Phase | Calendar | Notes |
|-------|----------|-------|
| 0 | 1–2 days | Scope lock |
| 1 | 2–4 days | Mostly reading + figure selection |
| 2 | 1–2 days | Definitions |
| 3 | 1–2 weeks | Critical path |
| 4 | 3–5 days | Draft + review |
| 5 | 2–4 days | Release polish |
| 6 | 1–3 weeks | Optional |
| 7 | as needed | Optional / last |

**MVP path to public litepaper:** Phases 0–5 with D0–D5.  
**Fastest honest interim:** Phases 0–2 + 4–5 with SE appendix only and DETF labeled design-level (weaker; not preferred).

---

## 12. Suggested file tree after completion

```text
research/
  papers/
    detf-litepaper/
      RESEARCH_AND_WRITING_PROGRAM.md   # this program
      BRIEF.md
      CLAIMS_MATRIX.md
      OUTLINE.md
      FORMAL_DEFINITIONS.md
      FIGURE_MANIFEST.md
      LITEOBACK_DRAFT.md
      LITEOBACK.pdf                     # optional release
      WHITEPAPER_DRAFT.md                # Phase 6
      REVIEW_NOTES.md
  scenarios/
    detf/
      singleSe/
        DETF_Research_PRD.md
        DETF_Research_IMPLEMENTATION_AND_TEST_PLAN.md
        FINDINGS.md
        AGENT_RESEARCH_REPORT.md
  out/
    detf/
      singleSe/                         # generated JSONL + PNG
  run_detf_single_se.sh                 # Phase 3
scripts/foundry/research/detf/singleSe/ # Phase 3
```

---

## 13. Immediate next actions

1. **Approve this program** (or mark interim SE-only litepaper scope).  
2. Execute **Phase 0**: write `BRIEF.md` + freeze claims matrix.  
3. Start **Phase 1** figure harvest in parallel with **Phase 2** definitions.  
4. Kick **Phase 3a** PRD only after brief is locked.  
5. Do **not** open Phase 6–7 until litepaper draft exists.

---

## 14. Status log

| Date | Event |
|------|--------|
| 2026-07-29 | Program authored from research inventory, frontend research pitch, playbook Tier 5 gap, and prior planning discussion |
| 2026-07-29 | Single campaign PRD authored: `research/scenarios/detf/singleSe/DETF_Research_PRD.md` (Progress + Results + D0–D5 minimum; implementation notes inline) |
| 2026-07-29 | **Dropped** `composed/single` (SingleVaultDetf) from research universe — gold SUT remains `standardExchange/single` only; taxonomy = four live families |
| 2026-07-30 | Integrated **protocol compound** + **natural supply expansion** (LOCKED product law + docs handoff): claims **C12–C13**, litepaper §3b, scenarios D5/D8/D9, non-claims expanded |
| 2026-07-30 | Phase 3 execution PRD authored: full **D0–D9** acceptance; one script per Di |
| 2026-07-30 | Phase 3 implementation plan authored (M0–M5, fixture API, per-Di steps) |
| — | Phase 0 brief optional; Phase 3 harness not started |

---

## 15. Related documents (quick index)

| Doc | Role |
|-----|------|
| [`research/RESEARCH_PLAYBOOK.md`](../../RESEARCH_PLAYBOOK.md) | Ladder, chart catalog, DETF Tier 5 |
| [`research/README.md`](../../README.md) | How to run existing SE research |
| [`research/MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) | Measured claim roll-up |
| [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../../../docs/marketing/DETF_NARRATIVE_SPINE.md) | Public product story |
| [`frontend/RESEARCH_SECTION_DESIGN.md`](../../../frontend/RESEARCH_SECTION_DESIGN.md) | `/research` surface |
| [`frontend/app/content/research/articles/detf.ts`](../../../frontend/app/content/research/articles/detf.ts) | Public DETF note |
| [`contracts/vaults/detf/DETF_Threshold_Modes_PRD.md`](../../../contracts/vaults/detf/DETF_Threshold_Modes_PRD.md) | Policy/Open law |

---

*End of program document.*
