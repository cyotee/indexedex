# Product Requirements Document (PRD) — v2

## Title

DualLiquidity Linked Cross-Version Uniswap Vault — Linked Volume & Share-Book Research (v2)

## Status

**PLANNED** — research-only extension of DualLiquidity v1. Does **not** re-open rates fairness (v1 complete). Implementation plan: [`DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md).

## Purpose

Produce **reviewable evidence** that DualLiquidity’s **primary product value proposition** is real: **one vault share over linked Uni V4 + Uni V2 liquidity**, with measurable activity into nested markets and a trustworthy **share-holder full-exit book**.

### Why v2 exists

v1 ([`DualLiquidity_Research_PRD.md`](./DualLiquidity_Research_PRD.md), FINDINGS 2026-07-21) locked:

| Claim | v1 status |
|-------|-----------|
| R+ nested mid residual ≈ 0 under modest leg demand | **Done** |
| R− residual grows (modest) | **Done** |
| Mode B deposit preview == execution (exact off / few-wei on) | **Done** |
| Nested composition under one share | Topology + deposits only — **volume-into-legs not charted** |
| Share-book as marketing hero | Series present; **not** the lead figure set |

Roll-up gap ([`MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) §5):

> DualLiquidity as proven “volume engine into both linked markets” with dedicated volume charts — **not ready**.

v2 fills that gap. It does **not** exist to prove arb (Mode C remains stretch; fee-threshold theory already proven on Uni V2 SE).

### Research questions (normative)

| ID | Question |
|----|----------|
| **RQ1** | When capital enters via DualLiquidity product routes (deposit / exchangeIn), which nested legs receive measurable activity — `vaultA`, `vaultB`, `pairVault`, and/or reserve BPT inventory? |
| **RQ2** | Under **leg Uni demand** (Mode A), how does the DualLiquidity **share full-exit mark** move (normalized P&L, fee vs price if separable)? |
| **RQ3** | Under **product-surface drive** (Mode B), is multi-leg activity visible in a single marketing figure (volume attribution), not only “shares minted”? |
| **RQ4** | Does rates-**off** (product default) suffice for the primary VP charts, with rates-on only as optional twin? |
| **RQ5** (stretch) | At higher volume, does R− residual approach the **0.3%** reserve fee enough to justify Mode C? (Document only; not required for “volume engine” claim.) |

Results update the marketing roll-up; they do **not** claim mainnet APY or live fee APR.

---

## SUT and naming

Same as v1 — no product rename.

| Item | Path / identity |
|------|-----------------|
| Package | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg` |
| Facets / common | `contracts/vaults/protocol/uniswap/crossVersion/*` |
| Product PRD | `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` |
| Gold TestBase | `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` |
| Rates API | `PkgArgs.useRateProviders` — **false** default; **true** opt-in; homogeneous |
| v1 research fixture | `scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol` |

### Role names (mandatory)

| Role | Meaning |
|------|---------|
| `commonToken` | Shared base of both V4 markets |
| `tokenA` / `tokenB` | Linked tokens |
| `vaultA` / `vaultB` | Uni V4 SE vaults (common/tokenA, common/tokenB) |
| `pairVault` | Uni V2 SE vault (tokenA/tokenB) |
| `reservePool` / `reserveBpt` | Balancer V3 weighted 3-leg pool + BPT |
| DualLiquidity share / `address(this)` | Diamond ERC-20 share |

**Anti-patterns:** brand tokens; calling this a full synthetic DETF; leading with arb as the DualLiquidity story.

### What this is / is not

| Is | Is not |
|----|--------|
| Linked multi-market nested vault under one share | Arb product |
| Share-on-BPT economics under market + product demand | DETF seigniorage / bond NFT / claim |
| Volume **attribution** research | Guarantee of equal flow to every leg every step |

---

## Locked decisions

Do not re-open without an explicit PRD revision.  
**(2026-07-21 product-owner clarifications applied — see § Clarifications.)**

| Topic | Decision |
|-------|----------|
| Relationship to v1 | **Extension** — do not re-run full R+/R− residual matrix unless params change; **cite** v1 FINDINGS for rates |
| Primary VP | **Composition / routing / linked volume** — not residual fairness, not Mode C |
| Default research world | **Rates off** (`useRateProviders: false`) for hero charts |
| Rates-on twin | **Not in default runner** — optional later if residual slide needed; not blocking |
| Mode B routes | **Broader matrix** — multiple `exchangeIn` paths (deposits + swaps), not commonToken-only; see § Mode B route matrix |
| H2 success bar | **BPT + ≥1 SE leg** non-zero nested activity under the Mode B matrix (not all three SE legs required) |
| Mode A mark | **Reuse v1 full-exit mark as-is** (shares → BPT → legs → existing mark token) |
| Mode B / Mode A scale | **Match v1** modest sizes/steps unless smoke shows flat nested deltas |
| SUT deploy | Production path only (CREATE3 + registry DFPkg + TestBase / fixture) — no mocks of SUT |
| Environment | **Base mainnet fork** via gold TestBase / existing research fixture |
| Foundry | `FOUNDRY_PROFILE=default`; offline forge OK after compile |
| Mode priority | **Mode B volume first**, then Mode A share-book polish, Mode C **stretch only** |
| Fee claims | Reserve fee **0.003e18 (0.3%)** — not Uni SE research 5% |
| Artifact isolation | New subtrees only: `research/out/dualLiquidityLinkedCrossVersion/v2/` (do not overwrite v1 `rates_*` / `compare/`) |
| Tracked narrative | Same scenario folder; new v2 PRD / plan / FINDINGS_v2 |
| Chart framing | Market demand / holder book; raw indices; `pnl_normalized` preferred for share book |
| Parallel safety | Research scripts + scenario docs + `out/.../v2/` only; no other DETF package edits |
| Stop condition | If multi-leg volume cannot be shown at modest size → document honestly; do **not** substitute Mode C arb as the VP |

### Clarifications (locked 2026-07-21)

| # | Question | Answer |
|---|----------|--------|
| C1 | Mode B routes | **Broader route matrix** (multiple `exchangeIn` paths) |
| C2 | H2 multi-surface bar | **BPT + ≥1 SE leg** |
| C3 | Mode A mark currency | **Keep v1 full-exit mark as-is** |
| C4 | Rates-on in default runner | **Rates-off only** for hero runs |
| C5 | Modest scale | **Match v1 Mode B** (and Mode A) sizes/steps |

---

## Scope

### In scope (v2)

1. Extend DualLiquidity research fixture/scripts with **per-leg volume / inventory telemetry**.
2. Mode B runs focused on **deposit / exchangeIn** paths that can touch nested SE books (document which routes are closed-form).
3. Mode A runs focused on **share full-exit mark** as hero P&L (rates-off primary).
4. Offline plots: **volume_by_leg**, **share_book_pnl** (normalized), optional inventory overlay.
5. Runner flags for v2-only (or dedicated `run_dual_liquidity_research_v2.sh`).
6. `FINDINGS_v2.md` + agent handoff section; update marketing roll-up §3.4 / §5 / changelog.
7. SCENARIO_LOG rows for completed v2 runs.

### Out of scope (v2)

- Re-proving R+ residual ≈ 0 (v1).
- DualLiquidity Mode C arb fills as a **required** success criterion.
- Multi-protocol SE legs (Aero/Camelot) as DualLiquidity substitutes.
- Synthetic DETF mint/burn/bond/claim.
- Mainnet APY / production fee history.
- Overwriting v1 artifacts under `rates_on/` / `rates_off/` / `compare/` from 2026-07-21.
- Editing Uni V2 SE research trees.

---

## Topology under test (unchanged)

```text
                    ┌─ vaultA (V4 SE: common/tokenA) ─┐
Uni demand (A) ──►  ├─ vaultB (V4 SE: common/tokenB) ─┼─► reserve weighted pool (BPT)
                    └─ pairVault (V2 SE: tokenA/tokenB)┘         │
                                                                 ▼
                                                    DualLiquidity shares
Mode B ──► deposit / exchangeIn on diamond ──────────────────────┘
```

Weights: package defaults **20 / 20 / 60** (A / B / pair) unless meta documents an override.

---

## Scenario modes (v2)

### Mode B — Product surface volume attribution (**priority 1**)

**Drive:** DualLiquidity diamond `exchangeIn` **route matrix** (broader than v1 commonToken-only). Prefer **closed-form exact-in** paths; skip / log `UnsupportedRoute` rather than inventing solvers.

#### Mode B route matrix (normative)

From product surface (`DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget` + product PRD):

| Priority | `routeTag` | Drive | Why for volume story |
|----------|------------|-------|----------------------|
| **P0** | `deposit_common` | commonToken → shares | v1 baseline; nested common→linked→pair→join |
| **P0** | `deposit_tokenA` | tokenA → shares | Linked-token path (leg vs pair best-of) |
| **P0** | `deposit_tokenB` | tokenB → shares | Symmetric linked path |
| **P1** | `deposit_pairShare` | pairVaultShare → shares | Direct SE-share join into reserve |
| **P1** | `deposit_vaultAShare` / `deposit_vaultBShare` | vaultA/B share → shares | Direct V4 SE share join |
| **P1** | `swap_tokenA_tokenB` | tokenA ↔ tokenB (no share mint) | **Volume driver** through pair / two-hop (product: free aggregation) |
| **P2** | `swap_common_tokenA` / `swap_common_tokenB` | common ↔ linked | Via-leg swap volume |
| **P2** | `deposit_bpt` | reserve BPT → shares | Share mint without nested Uni (control: BPT-only surface) |
| **Out** | Exact-out solvers / binary-search routes | — | Revert or skip; not v2 |

**Run policy:**

1. Phase 0 smoke: `deposit_common` only (confirm attribution).  
2. Phase 1 matrix: run **all P0** at v1-comparable sizes; then **P1** if gas/time allows in same session.  
3. P2 optional; `deposit_bpt` as control row (may show BPT-only, zero SE Δ — still useful).  
4. Per route: separate `out/.../v2/rates_off/modeB_<routeTag>/` tree + shared compare if useful.  
5. Aggregate marketing figure may stack routes or show a multi-panel “route atlas.”

**Goals:**

- Per-step **volume attribution**: deltas for `vaultA`, `vaultB`, `pairVault`, reserve BPT (per attribution model).
- Clear marketing figure: “capital entered here → activity appeared there” **across routes**.
- preview==execution on deposit routes (reconfirm; exact or ≤ few-wei).

**Success signals (H2 locked):**

- Across the Mode B matrix (not necessarily every single route), show **reserve BPT activity + ≥1 SE leg** non-zero nested Δ.  
- Individual routes may be single-funnel (document honestly).  
- `volume_by_leg` series reconstructable from JSONL alone.

### Mode A — Share-book under leg demand (**priority 2**)

**Drive:** Uni V4 (and optionally V2 pair) trades that move leg SE rates / inventories — same spirit as v1 Mode A, **rates-off default**.

**Goals:**

- Hero **share full-exit** P&L (`shares → reserve BPT → legs → mark token`) normalized to start.
- Secondary: inventory / claim composition honesty (what the share is claim on).
- Residual optional (cite v1); do not make residual the Mode A hero chart.

**Success signals:**

- Continuous `pnl_normalized` (or DualLiquidity equivalent) series for the share holder under the Mode A path.
- Meta records trade size, steps, mark token, full-exit method.

### Mode C — Reserve arb (**priority 3, stretch only**)

**Drive:** Only if Mode A residual under rates-off at a **stress tier** approaches ~0.3%.

**Goals:** Transfer fee-threshold illustration onto DualLiquidity reserve — **not** required to call v2 complete.

**Not required** for marketing “linked volume” claim.

### Volume policy

| Tier | Intent |
|------|--------|
| **Modest (v2 default)** | Visible multi-leg or multi-surface activity + smooth share P&L; primary marketing charts |
| **Elevated (optional)** | Larger deposit size / more steps if modest Mode B fails to move two surfaces |
| **Stress (stretch)** | Residual toward 0.3% for Mode C only — separate artifact subtree |

Record `tradeSizeMul`, `tradeSteps`, `depositSize`, `routeTags` in meta.

---

## Hypotheses (pre-registered)

| ID | Claim | Primary mode |
|----|--------|--------------|
| **H1** | Mode B product routes create **measurable nested activity** beyond “shares exist” (BPT and/or SE leg deltas) on at least the P0 matrix | Mode B |
| **H2** | Mode B matrix supports **multi-surface** story: **reserve BPT + ≥1 SE leg** non-zero activity (aggregate across routes OK); single-route funnels documented honestly | Mode B |
| **H3** | DualLiquidity share full-exit mark under Mode A is stable enough for a marketing `pnl_normalized` figure (rates-off; **v1 mark as-is**) | Mode A |
| **H4** | Rates-off default is sufficient for H1–H3 hero charts (no rates-on required in default runner) | Mode A/B |
| **H5** (stretch) | R− residual can be driven toward ~0.3% with elevated volume without rewriting the product | Mode A stress |
| **H6** (stretch) | Mode C fills only if residual ≳ fee stack | Mode C |

---

## Metrics (normative)

Exact JSON field names locked in the implementation plan; PRD requires these **quantities**:

### Volume attribution (Mode B hero)

| Metric | Definition (intent) |
|--------|---------------------|
| `dVaultAShares` / inventory | Change in vaultA SE share inventory relevant to the path (alice, diamond, or pool leg as documented) |
| `dVaultBShares` | Same for vaultB |
| `dPairVaultShares` | Same for pairVault |
| `dReserveBpt` | Change in reserve BPT held by diamond and/or alice research book |
| `dUnderlyingProxy*` (optional) | V4/V2 pool spot or liquidity proxy if SE share delta is opaque |
| `routeTag` | Which DualLiquidity route ran this step |
| `previewOut` / `execOut` | Closed-form deposit routes |

**Attribution rule:** Document in meta **which address’s balances** define “activity” (prefer: reserve pool live balances of SE shares + diamond free inventory + alice share book — pick one consistent stack and stick to it).

### Share book (Mode A hero)

| Metric | Definition (intent) |
|--------|---------------------|
| `shareBal` | Alice DualLiquidity share balance |
| `markFullExit` | Full exit to mark token (commonToken or USDC-equivalent per fixture) |
| `pnlAbs` / `pnlNorm` | `mark_t - mark_0` and `(mark_t / mark_0) - 1` |
| `portfolioExitBpt` (if used) | Intermediate BPT claim mark (v1 field OK) |

### Residual (secondary / stretch only)

Reuse v1 formula for vaultA lens:

```text
midA = live[pairVault] * 1e18 / live[vaultA]
midIndexA = midA_t / midA_0
rateIndexA = rateA_t / rateA_0
residualA = midIndexA * rateIndexA / 1e18 - 1
```

Do **not** require multi-leg residual charts for v2 done.

---

## Artifacts and layout

### Tracked (repo)

```text
research/scenarios/dualLiquidityLinkedCrossVersion/
  DualLiquidity_Research_PRD.md                          # v1 (complete)
  DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md # v1 (complete)
  DualLiquidity_Research_v2_PRD.md                       # this file
  DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md
  FINDINGS.md                                            # v1
  FINDINGS_v2.md                                         # after v2 runs
  AGENT_RESEARCH_REPORT.md                               # append v2 section or v2 sibling report
```

### Generated (gitignored)

```text
research/out/dualLiquidityLinkedCrossVersion/v2/
  rates_off/
    modeB_depositCommon/     # series.jsonl meta.json plots
    modeB_<route2>/          # if second route
    modeA_legDemand/
  rates_on/                  # optional twin only
    ...
  compare/                   # optional rates_off vs rates_on; not required
  elevated/                  # optional larger size
  stress/                    # Mode C / residual stretch only
```

**Meta must include:** `product`, `scenarioFamily: dualLiquidityLinkedCrossVersion`, `researchVersion: 2`, `useRateProviders`, `mode`, `runId`, sizes/steps, `reserveSwapFee` (0.003e18), `attributionModel` (string describing balance stack), `gitCommit` (stamp).

### Scripts (suggested)

```text
scripts/foundry/research/dualLiquidityLinkedCrossVersion/
  ResearchFixture_DualLiquidity.sol          # extend: volume sample helpers
  Script_V2_RatesOff_ModeB_*.s.sol
  Script_V2_RatesOff_ModeA_*.s.sol
  Script_V2_RatesOn_* (optional)
research/run_dual_liquidity_research_v2.sh
research/plots/plot_dual_liquidity_v2.py     # volume_by_leg + share_book_pnl
```

Prefer **extend** v1 fixture over a full rewrite; keep v1 runner/artifacts intact.

---

## Charts (minimum)

| Chart | Use | Required for v2 done? |
|-------|-----|------------------------|
| `volume_by_leg.png` | Mode B multi-surface activity (stacked or multi-line cumulative Δ) | **Yes** |
| `share_book_pnl.png` / `pnl_normalized.png` | Mode A holder book under leg demand | **Yes** |
| `inventory.png` or composition panel | What the share claims (BPT / legs) | Recommended |
| `preview_gap.png` | Reconfirm Mode B preview trust | Optional if v1 cited |
| residual / fairness | Rates story | Cite v1; optional v2 twin |
| Mode C probes | Fee threshold | Stretch only |

Framing: **linked liquidity and holder book**, not “we arb’d the reserve.”

---

## Success criteria (v2 research done)

### Structural

- [ ] v2 PRD + implementation plan tracked under `research/scenarios/dualLiquidityLinkedCrossVersion/`
- [ ] Artifacts only under `research/out/dualLiquidityLinkedCrossVersion/v2/`
- [ ] v1 trees left intact
- [ ] Runner documented; meta stamped with `researchVersion: 2`

### Empirical (Mode B — primary)

- [ ] JSONL with per-step volume attribution fields for vaultA / vaultB / pairVault / reserveBpt (zeros allowed if documented)
- [ ] **P0 route matrix** run (deposit_common, deposit_tokenA, deposit_tokenB) at v1-comparable scale
- [ ] H2: across matrix, **BPT + ≥1 SE leg** non-zero nested Δ (aggregate OK)
- [ ] Per-route (or atlas) `volume_by_leg` plot(s) in FINDINGS_v2
- [ ] H1 supported **or** explicit fail with topology explanation (still a valid research outcome)
- [ ] P1 routes attempted or explicitly deferred with reason in FINDINGS_v2

### Empirical (Mode A — secondary)

- [ ] Rates-off Mode A share full-exit normalized P&L series + plot
- [ ] H3 supported (plotable book) or documented instability / mark caveats

### Narrative

- [ ] `FINDINGS_v2.md` with H1–H4 pass/fail
- [ ] Agent handoff updated: claims, paths, “do not re-run unless params change”
- [ ] Marketing roll-up §3.4 / §4 / §5 / changelog updated
- [ ] SCENARIO_LOG row(s)

### Stretch (not required)

- [ ] Elevated volume if modest Mode B under-delivers multi-surface signal
- [ ] Residual vs 0.3%; Mode C only if residual clears fee-scale

---

## Marketing claim → evidence map (v2)

| Publishable claim (draft language) | Evidence required | v1 vs v2 |
|------------------------------------|-------------------|----------|
| DualLiquidity is one share over linked Uni V4 + V2 SE legs | Topology + **volume_by_leg** under product deposits | v2 unlocks |
| Depositing into DualLiquidity can fund nested SE / reserve composition | Mode B series: BPT and/or SE share deltas | v2 |
| Holder economics under market demand are plotable | Mode A `share_book_pnl` / pnl_normalized | v2 polishes v1 |
| Default deploy can omit Rate Providers | v1 meta + rates_off | v1 (cite) |
| Opt-in rates re-mark nested mids | v1 residual ≈ 0 | v1 (cite) |
| Arb is not free lunch below pool fee | Uni SE rateProviderCompare + v1 residual ≪ 0.3% | cite; Mode C stretch |

**Do not publish:** mainnet yield; equal flow to all three legs every trade; DualLiquidity as arb engine; “rates eliminate all fills under stress.”

---

## Dependencies

| Dependency | Status |
|------------|--------|
| DualLiquidity optional rates + v1 research fixture | **Shipped / complete** |
| Gold fork TestBase | Available |
| v1 FINDINGS / agent report | Cite for rates + preview |
| Uni V2 SE fee-threshold theory | Cite; do not re-run |
| Other DETF work | Independent |

---

## Implementation plan

**Normative execution plan:** [`DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md)

Phases (summary):

0. Telemetry schema + attribution model lock on fixture  
1. Mode B rates-off volume runs + `volume_by_leg` plot  
2. Mode A rates-off share-book polish + hero P&L plot  
3. FINDINGS_v2 + roll-up + SCENARIO_LOG  
4. Optional elevated / rates-on twin / Mode C  

---

## Risks

| Risk | Mitigation |
|------|------------|
| Mode B only moves BPT, not “both Uni markets” visibly | Document composition chain; elevate size; second route; honest single-funnel claim |
| SE share inventory on reserve pool hard to interpret | Prefer live balances of SE tokens in reserve + alice share mark; document stack |
| Fork wall-clock | Extend fixture; Mode B first; cache compile; offline after |
| Overclaim multi-leg equality | Pre-register H2 as “multi-surface” not “equal weights of flow” |
| Confusion with v1 residual campaign | Separate `v2/` out tree; lead with volume/P&L charts |
| Parallel agent conflicts | Touch only DualLiquidity research paths |

---

## Related paths

| Path | Role |
|------|------|
| [`DualLiquidity_Research_PRD.md`](./DualLiquidity_Research_PRD.md) | v1 residual + preview |
| [`FINDINGS.md`](./FINDINGS.md) | v1 results |
| [`AGENT_RESEARCH_REPORT.md`](./AGENT_RESEARCH_REPORT.md) | v1 handoff |
| [`../../MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) | Living marketing roll-up |
| `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` | Fee-threshold theory |
| `research/RESEARCH_PLAYBOOK.md` | Ladder / chart conventions |

---

## Acceptance of this PRD

This PRD is **accepted for implementation** when:

1. Product owner agrees Mode B volume → Mode A share-book → Mode C stretch priority.  
2. Hero world is rates-**off**; rates-on optional.  
3. Artifacts live under `.../v2/` without overwriting v1.  
4. Success does **not** require Mode C fills.

---

*Next action: execute [`DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md) after PRD review.*
