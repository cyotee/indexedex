# Product Requirements Document (PRD)

## Title

Rate Provider Comparative Research — Uni V2 Standard Exchange + Balancer share matrix

## Status

**PLANNED** — research-only scenario family. Does not change production vault packages.

## Purpose

Run a **controlled A/B research scenario** that isolates **one design switch**, with **homogenous pool policy per run**:

| Variant | Balancer share leg (every pool in that run) | Meaning |
|---------|-----------------------------------------------|---------|
| **R+** (rates on) | `TokenType.WITH_RATE` + SE rate provider | Production-like nested mark |
| **R−** (rates off) | `TokenType.STANDARD` (plain share ERC-20) | Child mid from raw inventory only |

### Homogeneous state rule (mandatory)

- **One Rate Provider policy per deployment / run.** Never mix R+ and R− share legs in the same world.
- Real-world product choice is binary for a given market design: **use rate providers, or do not.** Comparative research must not pollute a run with pools that use the other policy “for completeness.”
- **R+ world:** every Balancer pool that holds SE vault shares uses a rate provider (may still vary *which* rate target — WETH-rated vs USDC-rated — as in Mode A; that is still “rates on”).
- **R− world:** every such pool uses `STANDARD` shares with **no** rate provider.
- **Separate forge scripts, separate fixture instances, separate `out/` trees.** Comparison happens offline across artifacts, not inside one mixed matrix.
- **Later (out of scope v1):** a mixed-policy world only if findings suggest a product benefit; requires a new PRD revision.

Everything else is held fixed across the pair of pure states: hermetic Uni V2 WETH/USDC, SE vault, fair init, trade sizes, steps, telemetry schema, and plot conventions.

### Why this exists

Mode A/C showed that under **R+**, Uni-only demand re-marks Balancer mids via rates and leaves **no redeem-arb residual**. Older Liquidity Tree / nested-market theory assumed parent moves could leave **child AMM lag** and thus **arb + capital rotation**.

This scenario answers, with evidence:

1. Does **removing** Rate Providers restore Uni-driven redeem-arb (Mode C probes)?
2. Do chart-slope gaps behave differently under R+ vs R−?
3. How do LP-book P&L and arb-agent profit differ when residual exists vs not?

Results inform product messaging and whether buffer/tree “perpetual rebalancing” designs need **inventory skew / hooks**, not rate ticks alone.

## Locked decisions

Do not re-open without an explicit PRD revision.

| Topic | Decision |
|-------|----------|
| Scenario family | **New** research path only; **do not modify** existing Mode A/C scripts or their artifact dirs |
| Reuse style | **Import / inherit** Mode A fixture + Mode C closer; override only matrix token config (and any minimal hooks required) |
| SUT / production code | **Real** Uni port, SE vault, Balancer V3, rate provider packages — production-first; no mocks of SUT |
| Homogeneous policy | **All** SE-share legs in a given run share the same Rate Provider policy (all on, or all off). **No mixed R+/R− pools.** |
| Separate worlds | R+ and R− are **distinct fixture instances / scripts / artifact dirs** — never one bootstrap with both policies |
| R+ definition | **Every** share leg `TokenType.WITH_RATE` + SE rate provider (WETH- and/or USDC-rated as needed for the R+ matrix). Behavioral twin of production-like nested mark |
| R− definition | **Every** share leg `TokenType.STANDARD`, **no** rate provider on any share `TokenConfig` |
| Pool set per world | Prefer the **same pair topology in both worlds** for fair A/B (default: Mode A–style 4 pools: pair ∈ {WETH, USDC} × rating label ∈ {WETH, USDC}). Under R−, rating is **label-only** (no rate wiring). Do **not** deploy “extra” pools that use the other policy |
| Init fairness | Both pure states use fair init at t0 (R+: Mode A live-rate sizing; R−: Uni spot + SE redeem preview or equivalent). Uni demand then creates lag **only** where rates are off |
| No pollution | Do not leave unused SE-share pools in a run “for later”; each run’s pools are exactly those required for that pure state |
| Drive modes in v1 | **Mode A-style** Uni-only demand (both directions) **and** **Mode C-style** Uni + Balancer arb closer (both directions) |
| Arb closer | Reuse `ResearchModeCCloser` unchanged if possible; configure against each variant’s pools |
| Trade path | Same constants as Mode A unless PRD revision: `TRADE_WETH`, `TRADE_USDC`, `TRADE_STEPS` |
| Telemetry | Same JSONL field set as Mode A/C sample (including probe fields); `meta.json` **must** set `rateProviderMode: "on" \| "off"` |
| Artifact roots | **New dirs only** under `research/out/uniswapV2Se/rateProviderCompare/` |
| Tracked narrative | Under `research/scenarios/uniswapV2Se/rateProviderCompare/` |
| Foundry profile | **`FOUNDRY_PROFILE=default`** (via_ir research profile not required; offline ok) |
| Chart framing | Locked Mode A conventions: LP / market demand, raw bar ratios, no display invert |
| Primary hypothesis | After identical Uni-only path: **R+ probes ≈ 0**; **R− probes > 0** (if fees/impact allow) and/or clear redeem-vs-mid residual series |
| Secondary hypothesis | `index_vs_fairness` orange “chart gap” can appear in both; **true residual / probes** diverge by variant |
| Non-goal v1 | SE Buffer hooks, DETF, multi-protocol SE matrix, Monte Carlo, off-fair init (later scenario) |

## Scope

### In scope

- New Foundry research fixtures/scripts under `scripts/foundry/research/uniswapV2Se/rateProviderCompare/`
- Inheritance from `ResearchFixture_UniswapV2SeRateMatrix` / `ResearchFixture_ModeC` (or thin wrappers)
- Plot scripts for **paired comparison** (R+ vs R−) and reuse of existing single-run plot pack
- Runner shell script(s) + `stamp_meta.py` integration
- Tracked PRD, plan, scenario notes, findings, `SCENARIO_LOG` row(s)

### Out of scope (v1)

- Editing `Script_ModeA_*` / `Script_ModeC_*` bodies or their `research/out/uniswapV2Se/modeA_*` / `modeC_*` outputs as the SUT of this scenario
- **Mixed** Rate Provider policies in one deployment (some pools WITH_RATE, some STANDARD)
- Production package changes to force STANDARD shares on live vaults
- Buffer-pool hook recirculation experiments
- Claiming marketing APY from hermetic runs
- Co-locating R+ and R− markets in one product recommendation without a dedicated follow-up PRD

## Research questions (normative)

**RQ1 (primary).** Under identical Uni demand, does **R−** produce positive Mode C-style arb probes while **R+** does not?

**RQ2.** Do dual-numeraire and mid×rate identities hold under R+ and break or become inapplicable under R− in the expected way?

**RQ3.** How do LP full-exit P&L (total / fee / price) compare across R+ vs R− for the same Uni path?

**RQ4.** When R− arb fills, who earns: LP book vs arb agent? Any free-LP / inventory leak signals?

## Success criteria

1. Both variants deploy and complete Mode A–equivalent Uni runs (both demand directions) with non-empty `series.jsonl` + stamped `meta.json`.
2. Both variants complete Mode C–equivalent runs (both demand directions) with probe fields populated.
3. Side-by-side comparison artifacts exist (tables and/or comparison plots) under `research/out/.../rateProviderCompare/`.
4. Tracked findings document states whether primary hypothesis holds, with numbers.
5. Reproduce path documented: one shell runner or explicit forge + plot commands; **no** edits to legacy Mode A/C scripts required.

## Naming

| Term | Use |
|------|-----|
| `rateProviderCompare` | Scenario family id / path segment |
| `R+` / `rates_on` | WITH_RATE + rate provider |
| `R−` / `rates_off` | STANDARD share leg |
| `market_buys_weth` / `market_buys_usdc` | Demand framing (same as Mode A/C) |
| Role names | `rateAsset` not required here; keep Uni research labels WETH/USDC for hermetic tokens |

## Artifact layout (normative)

```text
research/out/uniswapV2Se/rateProviderCompare/
  rates_on/
    modeA_market_buys_weth/
    modeA_market_buys_usdc/
    modeC_market_buys_weth/
    modeC_market_buys_usdc/
  rates_off/
    modeA_market_buys_weth/
    modeA_market_buys_usdc/
    modeC_market_buys_weth/
    modeC_market_buys_usdc/
  compare/                    # derived comparison outputs
    summary.json              # optional machine table
    probes_compare.png
    fairness_compare.png
    pnl_compare.png
```

Each run dir: `series.jsonl`, `meta.json`, standard plot pack + `index_vs_fairness.png`.

## Meta requirements

`meta.json` must include at least:

```json
{
  "product": "uniswapV2Se",
  "scenarioFamily": "rateProviderCompare",
  "rateProviderMode": "on",
  "mode": "A_uni_only",
  "marketBoughtAsset": "WETH",
  "tradedAsset": "USDC",
  "runId": "modeA_market_buys_weth",
  "scenariosDoc": "research/scenarios/uniswapV2Se/rateProviderCompare/"
}
```

(`rateProviderMode`: `"on"` | `"off"`; Mode C uses `mode`: `C_uni_plus_bal_arb`.)

Stamp via `stamp_meta.py` after forge (git commit, forge version, script id).

## Hypotheses (pre-registered)

### H1 (primary)

After the same Uni-only demand path:

- **R+:** `maxBuyProbe` and `maxSellProbe` remain **0** (or dust below `MIN_PROFIT`) for all steps.
- **R−:** at least one demand direction shows **strictly positive** cumulative probe profit and/or `arbFills > 0` on Mode C, **or** a documented redeem-vs-mid residual series that grows with Uni steps while R+ residual stays flat.

If H1 fails (R− also zero), document fee/impact/path causes; do not silently claim rates are irrelevant.

### H2

R+ preserves `rateWeth × uniSpot / rateUsdc ≈ rateUsdc` identity and `mid_index × rate_index ≈ 1` for frozen inventory.

R−: mid indices do **not** systematically track `1/rate`; redeem-fair proxy vs mid-implied share cost **diverges** under Uni demand.

### H3

“Chart gap” `(uni_index/mid_index − 1)` may be nonzero in **both** variants; only R− (or R−+Mode C) ties that story to **measured** arb probes.

## Risks

| Risk | Mitigation |
|------|------------|
| R− init unfair by accident | Explicit fair-init using redeem preview / Uni ratio without relying on live rate scaling for mid |
| R− still no arb (fees) | Log residual series even when fills=0; optionally increase trade size in a **named** follow-up run (not silent constant change) |
| Stack-too-deep on new fixture | Inherit Mode A; override only `_tokenConfigs` / init; split telemetry helpers already landed |
| Confusion with legacy Mode A | Separate `out/` tree + `scenarioFamily` in meta |
| Treating R− as production default | PRD/findings must label R− as **comparative / lag-prone research**, not recommended production nested mark |

## Related docs

| Doc | Role |
|-----|------|
| [`../MODE_A_FINDINGS.md`](../MODE_A_FINDINGS.md) | R+ Uni-only baseline |
| [`../MODE_C_FINDINGS.md`](../MODE_C_FINDINGS.md) | R+ Uni + closer baseline |
| [`../INDEX_VS_FAIRNESS_EXPLAINER.md`](../INDEX_VS_FAIRNESS_EXPLAINER.md) | Chart gap vs residual pedagogy |
| [`../../../RESEARCH_PLAYBOOK.md`](../../../RESEARCH_PLAYBOOK.md) | Research ladder, telemetry, marketing rules |
| `docs/research/Pachira - Liquidity Trees Litepaper.pdf` | Historical nested-market / stagnant liquidity theory |
| This PRD | Normative for rateProviderCompare |
| [`RateProvider_Comparative_IMPLEMENTATION_AND_TEST_PLAN.md`](./RateProvider_Comparative_IMPLEMENTATION_AND_TEST_PLAN.md) | Execution plan |

## Acceptance (scenario “done”)

- [ ] PRD + implementation plan reviewed (this phase)
- [ ] Code + runners land without editing legacy Mode A/C scripts
- [ ] Full R+ and R− Mode A + Mode C artifact matrix (or documented skip with reason)
- [ ] Comparison plots + `FINDINGS.md` with H1–H3 verdicts
- [ ] `SCENARIO_LOG.md` updated
- [ ] Reproduce commands work on a clean checkout (after forge cache warm)
