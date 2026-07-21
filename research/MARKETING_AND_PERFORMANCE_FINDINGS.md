# IndexedEx — Marketing & Performance Research Findings

**Living document.** Roll-up of hermetic/fork research results for product messaging, docs, and agent handoff.  
**Updated:** 2026-07-21  

| Companion | Role |
|-----------|------|
| [`SCENARIO_LOG.md`](./SCENARIO_LOG.md) | Run index (dates, paths, one-liners) |
| [`RESEARCH_PLAYBOOK.md`](./RESEARCH_PLAYBOOK.md) | Ladder / methodology |
| Per-scenario `FINDINGS.md` / `AGENT_RESEARCH_REPORT.md` | Full detail (do not duplicate every number here) |

**Rule:** Prefer citing this file + the named graph path for marketing claims. Do not re-run full matrices unless parameters change.

---

## 1. Executive narrative (publishable spine)

1. **Standard Exchange vaults re-mark with underlying markets.** When Uni (or leg) demand moves SE rates, nested Balancer legs that use Rate Providers keep mids fair; without rates, mids lag.  
2. **Rate Providers are a mark-integrity control, not free yield.** Residual lag ≠ profitable arb until edge clears fees.  
3. **Pool fee is an arb presentation threshold.** Below fee stack → residual can exist with zero fills; above → closer can fill (proven on Uni V2 SE high-vol).  
4. **DualLiquidity’s primary product story is nested linked liquidity under one share**, not synthetic DETF seigniorage. Research so far proves rates fairness + deposit preview trust; **linked volume charts are Research v2**.  
5. **Previews can match execution** on closed-form DualLiquidity deposits (exact rates-off; few-wei rates-on).

---

## 2. Product value propositions (research-backed)

| Product | Primary VP (research stance) | Backing status |
|---------|------------------------------|----------------|
| **Uni V2 Standard Exchange + Balancer matrix** | SE share rates track underlying Uni; LP book P&L under market demand is measurable | **Strong** — Mode A full plot pack |
| **Rate Providers on SE-share Balancer legs** | Nested mid stays fair (`residual ≈ 0`); optional off shows lag | **Strong** — pure R+/R− worlds |
| **Fee-aware arb story** | Only treat residual as arb when it clears pool fee + path costs | **Strong** on Uni V2 SE (5% research fee ladder); transfer theory to other fees carefully |
| **DualLiquidity Linked Cross-Version vault** | One share over V4+V2 linked legs + pair; nested mark optional via rates; deposit previews trustworthy | **Partial** — fairness + Mode B preview done; linked-market “volume driver” not fully charted yet |

---

## 3. Findings by campaign

### 3.1 Uni V2 SE — Mode A (foundation)

| Finding | Result | Primary graph(s) |
|---------|--------|------------------|
| Uni demand moves SE rates | rateWeth / rateUsdc indices track Uni tilt; identity `rateWeth × uni ≈ rateUsdc` | `research/out/uniswapV2Se/modeA_trade_*/rates.png`, `price_index.png` |
| Chart slopes can differ while fair | mid tracks 1/rate; residual ~0 with rates on | `.../modeA_trade_*/index_vs_fairness.png` |
| LP book P&L under market demand | Directional total/start ~±0.48%; fee ~+7.3 USDC both ways | `.../pnl_normalized.png`, `pnl.png` |

**Detail:** [`scenarios/uniswapV2Se/MODE_A_FINDINGS.md`](./scenarios/uniswapV2Se/MODE_A_FINDINGS.md)  
**Reproduce:** `./research/run_mode_a.sh`

---

### 3.2 Uni V2 SE — Mode C (rates on, modest volume)

| Finding | Result | Primary graph(s) |
|---------|--------|------------------|
| Arb probes after Uni | **fills=0, maxBuy/SellProbe=0** | series + Mode C NOTES; same P&L as Mode A twin |
| Interpretation | Rate re-mark leaves no free Balancer lunch at modest volume | `index_vs_fairness.png` on `modeC_market_buys_*` |

**Detail:** [`scenarios/uniswapV2Se/MODE_C_FINDINGS.md`](./scenarios/uniswapV2Se/MODE_C_FINDINGS.md)

---

### 3.3 Rate Provider comparative (R+ vs R−) — Uni V2 SE

**Setup:** Pure separate worlds; Balancer const-prod research fee **5%** (not DualLiquidity’s 0.3%).

| Tier | R+ residual | R− residual | Mode C fills | Primary graph(s) |
|------|-------------|-------------|--------------|------------------|
| **Baseline** (1× size, 24 steps) | **0** | **~±24 bps** | **0** both | `out/uniswapV2Se/rateProviderCompare/compare/A_uni_only_WETH/fairness_compare.png` (top residual panel) |
| **mul10** | **0** | **~±2.4%** | **0** (fee-drowned) | `.../highVol/mul10/compare/A_uni_only_WETH/fairness_compare.png` |
| **mul25 × 48 steps** | Mode A **0**; Mode C stress more complex | Mode A **~±10–12%** | **Fills from ~step 22** (R− and R+) | `.../highVol/mul25_steps48/compare/C_uni_plus_bal_arb_WETH/probes_compare.png` + Mode A `fairness_compare.png` |

| Claim | Status |
|-------|--------|
| Rates on ⇒ residual 0 under Uni-only | **Proven** (all tiers Mode A) |
| Rates off ⇒ residual scales with volume | **Proven** |
| Residual &lt; fee ⇒ no fills | **Proven** (baseline + mul10 vs 5% fee) |
| Residual ≳ fee ⇒ fills appear | **Proven** (mul25/s48) |
| R+ Mode C never fills | **False at extreme stress** — do not overclaim; Mode A residual still 0 |

**Detail:**  
- [`scenarios/uniswapV2Se/rateProviderCompare/FINDINGS.md`](./scenarios/uniswapV2Se/rateProviderCompare/FINDINGS.md)  
- [`scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](./scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md)  
**Reproduce:** `./research/run_rate_provider_compare.sh` / `--high-vol` / `--high-vol-25s48`

---

### 3.4 DualLiquidity Linked Cross-Version vault

**Setup:** Base fork; pure `useRateProviders` true/false; reserve fee **0.3%**.

| Finding | Result | Primary graph(s) |
|---------|--------|------------------|
| R+ nested mid fair under leg Uni demand | residualA ≈ **0** (−1 wei) | `out/dualLiquidityLinkedCrossVersion/compare/modeA_legDemand/fairness_pnl_compare.png` **(top panel)** |
| R− mid lags same path | residualA ≈ **+1.86×10⁻⁴** (~1.9 bps); midIndex frozen, rateIndex moves | **same top panel (red vs green)** |
| Mode B deposit preview trust | R− **exact** preview==exec; R+ **≤ ~2k wei** | `.../compare/modeB_depositCommon/preview_gap.png` |
| Primary product VP | Nested linked V4+V2 liquidity under one share (composition/routing) — not arb/seigniorage | Narrative + Mode B successful deposits; volume-into-legs metric still light |

| Hypothesis | Verdict |
|------------|---------|
| H1 R+ residual ≈ 0 | **Supported** |
| H2 R− residual grows | **Supported** (modest) |
| H4 preview==execution | **Supported** (exact off; few-wei on) |
| H5 nested activity | **Partial** (shares mint / BPT tracked; deeper “linked volume” charts TBD) |
| H6 fee-threshold fills on DualLiquidity | **Not run** (residual ≪ 0.3% at this tier) |

**Detail:**  
- [`scenarios/dualLiquidityLinkedCrossVersion/FINDINGS.md`](./scenarios/dualLiquidityLinkedCrossVersion/FINDINGS.md)  
- [`scenarios/dualLiquidityLinkedCrossVersion/AGENT_RESEARCH_REPORT.md`](./scenarios/dualLiquidityLinkedCrossVersion/AGENT_RESEARCH_REPORT.md)  
**Reproduce:** `./research/run_dual_liquidity_research.sh`

**Primary VP (research stance):** one vault share over linked Uni V4 + V2 legs for a token pair; rates optional for fair nested marks; deposits are preview-safe. Lead with **composition/routing**, not arb.

**Next (v2):** linked volume attribution + share-book hero charts — [`DualLiquidity_Research_v2_PRD.md`](./scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_PRD.md). Artifacts will land under `out/dualLiquidityLinkedCrossVersion/v2/`.

---

## 4. Graph map (quick lookup)

| If you need to show… | Open this first |
|----------------------|-----------------|
| SE rates follow Uni | `uniswapV2Se/modeA_trade_usdc/rates.png` |
| Fairness residual (rates on, Mode A) | `uniswapV2Se/modeA_trade_*/index_vs_fairness.png` |
| R+ vs R− residual (baseline) | `uniswapV2Se/rateProviderCompare/compare/A_uni_only_WETH/fairness_compare.png` |
| Fee-drown vs residual growth | `rateProviderCompare/highVol/mul10/compare/A_uni_only_WETH/fairness_compare.png` |
| Arb fills appear | `rateProviderCompare/highVol/mul25_steps48/compare/C_uni_plus_bal_arb_WETH/probes_compare.png` |
| DualLiquidity rates fairness | `dualLiquidityLinkedCrossVersion/compare/modeA_legDemand/fairness_pnl_compare.png` |
| DualLiquidity deposit preview | `dualLiquidityLinkedCrossVersion/compare/modeB_depositCommon/preview_gap.png` |
| LP book relative P&L (SE) | `uniswapV2Se/modeA_trade_*/pnl_normalized.png` |

Paths are under `research/out/` (generated; gitignored — regenerate via runners).

---

## 5. Claims ready vs not ready for external marketing

### Ready (with hermetic/fork disclaimer)

- SE vault rates track underlying demand.  
- Rate Providers keep nested SE-share Balancer mids fair (residual ≈ 0).  
- Without Rate Providers, nested mids can lag as underlying markets trade.  
- Lag is not free arb below fees; above fees, arb can execute (Uni V2 SE high-vol evidence).  
- DualLiquidity deposits: preview matches execution (exact / few-wei).  
- DualLiquidity supports rates-on and rates-off deploy policies.

### Not ready / incomplete

- DualLiquidity as proven “volume engine into both linked markets” with dedicated volume charts — **next campaign: Research v2** ([PRD](./scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_PRD.md)).  
- DualLiquidity Mode C arb fills at 0.3% fee (stretch only; not required for primary VP).  
- Multi-protocol SE sameness (Aero/Camelot/Aave Stata Mode A twins).  
- Full synthetic DETF mint/burn/bond/claim research.  
- Production APY or live mainnet performance numbers.

---

## 6. Next research campaign

| Priority | Campaign | Status | Spec |
|----------|----------|--------|------|
| **1** | DualLiquidity linked volume + share-book (v2) | **PLANNED** | [`scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_PRD.md`](./scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_PRD.md) · [implementation plan](./scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 2 | Multi-protocol SE Mode A twins | not started | — |
| 3 | Single SE DETF inert→live + mint/burn | not started | — |

v2 focus: Mode B **volume_by_leg** (rates-off default) → Mode A share-book P&L → Mode C stretch only. Artifacts under `research/out/dualLiquidityLinkedCrossVersion/v2/` (do not overwrite v1).

---

## 7. Changelog

| Date | Update |
|------|--------|
| 2026-07-21 | **Created** this roll-up. Seeded from Mode A/C, rateProviderCompare (baseline + mul10 + mul25/s48), DualLiquidity Mode A/B. |
| 2026-07-21 | **Next campaign planned:** DualLiquidity Research v2 (linked volume + share-book). PRD + implementation plan under `scenarios/dualLiquidityLinkedCrossVersion/`. |

*When adding a campaign: append a subsection under §3, add graph row under §4, update §5 ready/not-ready, add a changelog line.*
