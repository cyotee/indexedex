# Product Requirements Document (PRD)

## Title

DualLiquidity Linked Cross-Version Uniswap Vault — Performance & Benefits Research

## Status

**COMPLETE (v1)** — Mode A+B pure R+/R− on Base fork; residual fairness + Mode B preview. Implementation plan: [`DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md). Findings: [`FINDINGS.md`](./FINDINGS.md).

**Next:** linked volume + share-book research — [`DualLiquidity_Research_v2_PRD.md`](./DualLiquidity_Research_v2_PRD.md).

## Purpose

Produce **reviewable, reconstructable evidence** for marketing and agent handoff on the DualLiquidity Linked Cross-Version Uniswap Vault (“DualLiquidity vault”): how its three Standard Exchange legs and Balancer weighted reserve behave under market demand and product routes, with Rate Providers **off** (product default) vs **on** (opt-in).

### Why this exists

1. Uni V2 SE research locked the **generic** stories: SE re-marks with underlying demand; rates re-mark nested mids; fee is an arb threshold. See  
   `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`.
2. DualLiquidity is a **distinct product surface**: two Uni V4 SE legs + one Uni V2 pair SE leg → **3-token weighted reserve** → simple vault shares (not full synthetic DETF gates / bond NFT / claim).
3. Public docs need DualLiquidity-specific claims: nested routing into linked markets, share-holder economics, and honest rates-off default vs rates-on fairness—not only Uni V2 SE matrix slides.

### Research questions (normative)

| ID | Question |
|----|----------|
| **RQ1** | Under identical Uni demand on legs, does **R+** keep reserve mid×rate residual ≈ 0 while **R−** residual grows? |
| **RQ2** | How does the DualLiquidity **share book** (full exit: shares → BPT → legs → underlying) perform under leg market demand (normalized P&L)? |
| **RQ3** | Do **exchangeIn / swap routes** on the DualLiquidity diamond drive measurable activity into linked Uni markets (Mode B product claim)? |
| **RQ4** | Do previews match execution on closed-form DualLiquidity routes under modest stress? |
| **RQ5** (stretch) | On the **reserve** (leg-share mids), when does Mode C–style arb appear relative to **this pool’s** fee (~0.3%), rates-off vs rates-on? |

Results feed a marketing outline and an agent research report; they do **not** claim mainnet APY.

---

## SUT and naming

### Subject under test

| Item | Path / identity |
|------|-----------------|
| Package | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg` |
| Facets / common | `contracts/vaults/protocol/uniswap/crossVersion/*` |
| Product PRD (as-built) | `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` |
| Gold TestBase | `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` |
| Rates API | `PkgArgs.useRateProviders` — **false** default; **true** opt-in; homogeneous all three reserve legs |

### Role names (mandatory)

Use **role names only** in research code, meta, NatSpec, and scenario docs:

| Role | Meaning |
|------|---------|
| `commonToken` | Shared base of both V4 markets |
| `tokenA` / `tokenB` | Linked tokens |
| `vaultA` / `vaultB` | Uni V4 SE vaults (common/tokenA, common/tokenB) |
| `pairVault` | Uni V2 SE vault (tokenA/tokenB) |
| `reservePool` / `reserveBpt` | Balancer V3 weighted 3-leg pool + BPT |
| DualLiquidity share / `address(this)` | Diamond ERC-20 share |

**Anti-patterns:** product token brands in research contracts; calling this a full “synthetic DETF” with mint/burn thresholds/bonds (it is a **simple share-on-BPT** nested vault).

### What this is / is not

| Is | Is not |
|----|--------|
| Nested three-SE → weighted reserve → vault shares | Single-SE DETF with synthetic ±5% gates |
| Immutable unowned instance after deploy | Upgradeable admin surface |
| Optional rates on **reserve legs only** via package flag | Mixed WITH_RATE/STANDARD legs in one instance |

---

## Locked decisions

Do not re-open without an explicit PRD revision.

| Topic | Decision |
|-------|----------|
| Scenario family | **New** research path only under DualLiquidity research dirs (below) |
| Parallel work | Do **not** edit other DETF packages/tests under concurrent agent work; DualLiquidity package is **assumed ready** (optional rates shipped) |
| SUT deploy | Production path: CREATE3 facets + registry DFPkg + TestBase / factory helpers — **no** `new` package/facets; **no** mocks of SUT |
| Environment | **Base mainnet fork** via existing gold TestBase (not a new hermetic Uni V4 port in v1) |
| Foundry | `FOUNDRY_PROFILE=default`; `--offline` allowed for script runs after compile |
| Homogeneous rates | One `useRateProviders` value per instance/run; pure R+ and pure R− worlds only |
| Separate worlds | Distinct fixture instances, scripts, and `out/` trees for rates on vs off |
| R+ | `useRateProviders: true` — three SE RPs + WITH_RATE on reserve legs |
| R− | `useRateProviders: false` — STANDARD legs, no RP deploy (product default) |
| Init | Bootstrap reserve per product PRD (inert deploy → manual/bootstrap init → first BPT deposit); t0 mids fair under each policy |
| Drive modes v1 | **Mode A** (leg Uni demand) then **Mode B** (DualLiquidity routes); **Mode C** stretch only |
| Primary book | DualLiquidity **share holder** full-exit mark (normalized); secondary: residual fairness on reserve |
| Fee claims | Use **this reserve’s** swap fee (**0.003e18 = 0.3%** at weighted-pool create), **not** Uni V2 SE research const-prod 5% |
| Cite prior work | SE identities and fee-threshold theory from Uni V2 SE rateProviderCompare — **transfer** claims; re-measure only on DualLiquidity |
| Artifacts | New trees only: `research/out/dualLiquidityLinkedCrossVersion/` |
| Tracked narrative | `research/scenarios/dualLiquidityLinkedCrossVersion/` |
| Chart framing | Market demand / LP book conventions from Mode A playbook: raw indices, no display invert, `pnl_normalized` preferred for marketing |
| Scripts vs tests | Research **forge scripts** + offline plots; do not require full monorepo test suite for each run; avoid colliding with other agents’ DETF test edits |

---

## Scope

### In scope (v1)

1. Research fixtures/scripts that deploy DualLiquidity via **production package + fork TestBase patterns**.
2. Pure-state **R−** (default) and **R+** (opt-in) matrices for Mode A and Mode B.
3. Telemetry JSONL + meta (`rateProviderMode`, `useRateProviders`, runId, gitCommit via stamp).
4. Plot pack (reuse/adapt Mode A fairness/P&L; DualLiquidity-specific labels).
5. Runner shell script; `FINDINGS.md` / agent handoff after runs.
6. Marketing claim → evidence checklist (this PRD § Success).

### Out of scope (v1)

- Refactoring other DETF families’ rate wiring (other agent).
- Mixed-policy reserves; brand-token launches.
- Full synthetic DETF bond/claim/mint-threshold suite (wrong product).
- Multi-protocol SE legs (Aero/Camelot) as DualLiquidity substitute.
- Monte Carlo, mainnet APY, fork-live marketing numbers as production truth.
- Editing Uni V2 SE research scripts or overwriting `research/out/uniswapV2Se/**`.
- Guaranteeing R+ Mode C fills = 0 under extreme stress (Uni V2 SE mul25 showed stress fills can exist even with rates).

---

## Topology under test

```text
                    ┌─ vaultA (V4 SE: common/tokenA) ─┐
Uni demand (A) ──►  ├─ vaultB (V4 SE: common/tokenB) ─┼─► reserve weighted pool (BPT)
                    └─ pairVault (V2 SE: tokenA/tokenB)┘         │
                                                                 ▼
                                                    DualLiquidity shares
Mode B ──► exchangeIn / swap on diamond ─────────────────────────┘
```

Weights: package defaults **20 / 20 / 60** (A / B / pair) unless research documents an override in meta.

---

## Scenario modes

### Mode A — Leg underlying demand (priority 1)

**Drive:** Trades on Uni V4 markets (and/or V2 pair) that back the three SE legs — **not** DualLiquidity routes first.

**Goals:**

- R+ vs R− residual on reserve leg mids (transfer fairness story).
- DualLiquidity share full-exit P&L under the same path.
- Both demand directions where TestBase markets allow meaningful tilt (document token roles in meta).

**Success signals:**

- R+: residual near zero under modest volume.
- R−: residual grows with volume; document vs 0.3% fee (may remain fee-drowned until stress tier).

### Mode B — DualLiquidity product surface (priority 2)

**Drive:** Diamond `exchangeIn` / swap routes (common, tokenA, tokenB, leg shares, BPT per route table).

**Goals:**

- Evidence that routing supports linked-market activity (quotes, fills, leg vault volume or reserve joins).
- preview == execution on closed-form routes under research sizes.
- Usage fee visibility on share-minting paths vs free swap aggregation (product PRD).

**Success signals:**

- At least one documented deposit path with exact or near-exact preview match.
- Narrative + series showing nested composition (not only raw Uni LP).

### Mode C — Reserve arb closer (priority 3, stretch)

**Drive:** Mode A (or mixed) + closer on **reserve** (leg-share ↔ pair-token style probes adapted from `ResearchModeCCloser` patterns).

**Goals:**

- Fee-threshold transfer: residual vs **0.3%** pool fee (and SE path fees).
- R− more likely to show residual; fills only if edge clears stack.

**Not required** for first marketing draft of DualLiquidity benefits.

### Volume policy

| Tier | Intent |
|------|--------|
| **Modest** (v1 default) | Visible residual difference R+/R− without extreme gas; primary marketing fairness charts |
| **Stress** (optional) | Larger size/steps if residual must clear ~0.3% for Mode C fills — document separately |

Prefer size multiplier over huge step counts (Mode C cost). Record `tradeSizeMul` / `tradeSteps` in meta.

---

## Hypotheses (pre-registered)

| ID | Claim | Primary mode |
|----|--------|--------------|
| **H1** | R+ reserve mid residual ≈ 0 under modest leg Uni demand | Mode A |
| **H2** | R− residual grows with same Uni path; mids lag SE rates | Mode A |
| **H3** | DualLiquidity share full-exit P&L is stable enough to plot normalized user book under Mode A | Mode A |
| **H4** | Mode B routes execute with preview==execution on supported closed-form deposits | Mode B |
| **H5** | Mode B deposits/swaps interact with legs (joins/leg activity), supporting “nested liquidity” docs | Mode B |
| **H6** (stretch) | Mode C fills for R− appear only when residual ≳ fee stack (~0.3% + path); R+ residual stays low at modest size | Mode C |

---

## Artifacts and layout

### Tracked (repo)

```text
research/scenarios/dualLiquidityLinkedCrossVersion/
  DualLiquidity_Research_PRD.md                 # this file
  DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md  # next delivery
  FINDINGS.md                                   # after runs
  AGENT_RESEARCH_REPORT.md                      # handoff for other agents (after findings)
```

### Generated (gitignored)

```text
research/out/dualLiquidityLinkedCrossVersion/
  rates_off/
    modeA_*/ series.jsonl meta.json plots
    modeB_*/
  rates_on/
    modeA_*/
    modeB_*/
  compare/                    # offline R+ vs R− panels
  highVol/                    # optional stress tiers
```

**Meta must include:** `product`, `scenarioFamily: dualLiquidityLinkedCrossVersion`, `rateProviderMode` / `useRateProviders`, `mode`, `runId`, trade sizes/steps, `reserveSwapFee` (0.003e18), gitCommit (stamp).

### Scripts (suggested)

```text
scripts/foundry/research/dualLiquidityLinkedCrossVersion/
  ResearchFixture_DualLiquidity_*.sol
  Script_RatesOff_ModeA_*.s.sol
  Script_RatesOn_ModeA_*.s.sol
  Script_RatesOff_ModeB_*.s.sol
  ...
research/run_dual_liquidity_research.sh
```

Parallel-safe: new paths only; do not modify other agents’ DETF production sources.

---

## Telemetry (minimum)

Reuse Mode A field spirit where possible:

| Group | Examples |
|-------|----------|
| Market | Uni V4/V2 spots or indices for relevant pairs |
| Rates | SE `getRate` on vaultA/B/pair when available |
| Reserve | Per-leg mid or live balance ratios; residual vs rate when R+ |
| Book | portfolio0, full-exit USDC (or commonToken) mark, fee/price split if applicable |
| Mode B | route tag, previewOut, execOut, optional leg share deltas |
| Mode C | maxBuyProbe, maxSellProbe, arbFills, arbProfit |

Exact schema locked in implementation plan; PRD requires **reconstructability** and **R+/R− comparability**.

---

## Charts (minimum)

| Chart | Use |
|-------|-----|
| `index_vs_fairness` / residual panel | H1/H2 marketing fairness |
| `pnl_normalized` | Share-holder book (primary user story) |
| `inventory` / claim composition | Nested exposure honesty |
| Mode B route panel | Product surface (deposit → BPT/shares) |
| `probes_compare` (if Mode C) | Fee-threshold illustration |

Framing: **market demand against liquidity / holder book**, not trader-centric “we sold X.”

---

## Success criteria (v1 research done)

### Structural

- [ ] PRD + implementation plan tracked under `research/scenarios/dualLiquidityLinkedCrossVersion/`
- [ ] Scripts deploy DualLiquidity with `useRateProviders` true/false pure worlds
- [ ] Artifacts under `research/out/dualLiquidityLinkedCrossVersion/` only
- [ ] No edits required to other DETF packages for these scripts to run

### Empirical (Mode A)

- [ ] R+ residual ≈ 0 (or documented dust) under modest leg demand
- [ ] R− residual larger in magnitude on same path
- [ ] Normalized share-book P&L series for both pure states

### Empirical (Mode B)

- [ ] At least one deposit route: preview == execution (or documented ≤ few-wei)
- [ ] Evidence of nested interaction (joins / leg balances / BPT) suitable for one marketing figure

### Narrative

- [ ] `FINDINGS.md` with H1–H5 pass/fail
- [ ] Agent handoff report: claims, artifact paths, “do not re-run unless params change”
- [ ] Marketing checklist filled (§ below)

### Stretch (Mode C)

- [ ] Residual vs 0.3% fee documented; fills or honest fee-drown

---

## Marketing claim → evidence map

| Publishable claim (draft language) | Evidence required |
|------------------------------------|-------------------|
| DualLiquidity composes V4 + V2 SE legs into one share claim on a weighted reserve | Topology + Mode B bootstrap/deposit figure |
| Default config can run **without** Rate Providers | rates_off Mode A + deploy meta `useRateProviders: false` |
| Opt-in Rate Providers re-mark nested reserve legs with underlying demand | rates_on Mode A residual ≈ 0 |
| Without rates, nested mids can lag SE fair value as markets trade | rates_off residual growth |
| Holders’ economics are plotable under market demand | `pnl_normalized` Mode A |
| Nested routes put capital into linked markets | Mode B activity metrics |
| Arb is not free lunch below pool fee | Residual vs 0.3% (+ Mode C if run) |

**Do not publish** mainnet yield, guaranteed arb profit, or “rates eliminate all Mode C fills under all stress.”

---

## Dependencies

| Dependency | Status assumption |
|------------|-------------------|
| Optional rates on DualLiquidity DFPkg | **Shipped** (`useRateProviders`) |
| Gold fork TestBase | Available |
| Uni V2 SE rateProviderCompare conclusions | Cite; do not re-run full matrix |
| Other DETF rate refactors | Independent; do not block this family |

---

## Implementation plan

**Normative execution plan:** [`DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md)

Phases:

0. Fixture bootstrap on fork TestBase + rates flag + residual formula lock  
1. Mode A R− + R+ modest volume + plots  
2. Mode B deposit/swap scripts + preview asserts  
3. Compare pack + FINDINGS + agent report  
4. Optional Mode C / stress  
5. Verification checklist

---

## Risks

| Risk | Mitigation |
|------|------------|
| Fork RPC / wall-clock | Cache compile; `--offline` after; Mode A before Mode C |
| Parallel agent conflicts | Touch only DualLiquidity research scripts/scenario paths + read-only package |
| Residual metric multi-leg ambiguity | Define residual per leg mid vs SE rate in implementation plan; primary chart = documented formula |
| Extreme stress R+ fills | Modest volume first; document stress separately |
| Confusing “DETF” naming in docs | Prefer “DualLiquidity vault” in marketing; PRD uses role names |

---

## Related paths

| Path | Role |
|------|------|
| `contracts/vaults/protocol/uniswap/crossVersion/` | SUT package |
| `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` | Product as-built |
| `DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md` | Rates optional (done) |
| `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` | Prior fee/rates theory |
| `research/RESEARCH_PLAYBOOK.md` | Ladder / chart conventions |

---

## Acceptance of this PRD

This PRD is **accepted for implementation planning** when:

1. Product owner agrees Mode A → Mode B → optional Mode C priority.  
2. Default research world is rates-**off** with rates-**on** comparative rows.  
3. Artifact roots and non-collision with Uni V2 SE / other DETF work are approved.

---

*Next action: write `DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md` after PRD review.*
