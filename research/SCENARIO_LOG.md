# Scenario log

One row per completed research run. **Narrative** lives under `research/scenarios/` (tracked). **Artifacts** live under `research/out/` (generated, gitignored).

**Marketing / performance roll-up (start here):** [`MARKETING_AND_PERFORMANCE_FINDINGS.md`](./MARKETING_AND_PERFORMANCE_FINDINGS.md)

**Reproduce Mode A:** `./research/run_mode_a.sh`  
**Reproduce Mode C:** `./research/run_mode_c.sh` (`FOUNDRY_PROFILE=default`)  
**Reproduce rateProviderCompare:** `./research/run_rate_provider_compare.sh` (`FOUNDRY_PROFILE=default`)  
**Reproduce DualLiquidity research:** `./research/run_dual_liquidity_research.sh` (Base fork)

| Date | Product | Mode | Scenario doc | Artifact dir | Status | One-line finding |
|------|---------|------|--------------|--------------|--------|------------------|
| 2026-07-20 | uniswapV2Se | A | [`scenarios/.../modeA_trade_usdc.md`](scenarios/uniswapV2Se/modeA_trade_usdc.md) | `out/.../modeA_trade_usdc` | polished | Buy WETH: uni +0.48%; rateW↓ rateU↑; rateW×uni=rateU; total/start **+0.479%**; fee **+7.3 USDC** |
| 2026-07-20 | uniswapV2Se | A | [`scenarios/.../modeA_trade_weth.md`](scenarios/uniswapV2Se/modeA_trade_weth.md) | `out/.../modeA_trade_weth` | polished | Buy USDC: mirror rates; total/start **−0.477%**; fee **+7.3 USDC** |
| 2026-07-20 | uniswapV2Se | A | [`MODE_A_FINDINGS.md`](scenarios/uniswapV2Se/MODE_A_FINDINGS.md) | — | summary | SE foundation story locked |
| 2026-07-20 | uniswapV2Se | C | [`MODE_C_FINDINGS.md`](scenarios/uniswapV2Se/MODE_C_FINDINGS.md) | `modeC_market_buys_*` | core done | **Zero residual** after Uni (probes 0); rate alignment finding |
| 2026-07-20 | uniswapV2Se | C | [`modeC_market_buys_usdc.md`](scenarios/uniswapV2Se/modeC_market_buys_usdc.md) | `out/.../modeC_market_buys_usdc` | complete | fills=0, maxBuy/SellProbe=0; P&L = Mode A twin |
| 2026-07-20 | uniswapV2Se | C | [`modeC_market_buys_weth.md`](scenarios/uniswapV2Se/modeC_market_buys_weth.md) | `out/.../modeC_market_buys_weth` | complete | fills=0, probes=0; total/start **+0.479%**; fee **+7.3 USDC** (= Mode A twin) |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | [`rateProviderCompare/FINDINGS.md`](scenarios/uniswapV2Se/rateProviderCompare/FINDINGS.md) | `out/.../rateProviderCompare/` | **complete** | R+ residual **0**; R− residual **~±24 bps**; Mode C probes **0** both pure states (fees); LP P&L identical |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode A R+ buys WETH | `out/.../rates_on/modeA_market_buys_weth` | complete | mid×rate residual **0**; total/start **+0.479%** |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode A R+ buys USDC | `out/.../rates_on/modeA_market_buys_usdc` | complete | mid×rate residual **0**; total/start **−0.477%** |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode A R− buys WETH | `out/.../rates_off/modeA_market_buys_weth` | complete | mid frozen at 1; residual **−0.239%**; P&L = R+ twin |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode A R− buys USDC | `out/.../rates_off/modeA_market_buys_usdc` | complete | mid frozen at 1; residual **+0.240%**; P&L = R+ twin |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode C R+ buys WETH | `out/.../rates_on/modeC_market_buys_weth` | complete | fills=0 probes=0 residual=0; P&L = Mode A twin |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode C R+ buys USDC | `out/.../rates_on/modeC_market_buys_usdc` | complete | fills=0 probes=0 residual=0 |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode C R− buys WETH | `out/.../rates_off/modeC_market_buys_weth` | complete | residual **−0.239%** persists; probes=0 (fee-drowned) |
| 2026-07-20 | uniswapV2Se | rateProviderCompare | Mode C R− buys USDC | `out/.../rates_off/modeC_market_buys_usdc` | complete | residual **+0.240%** persists; probes=0 |
| 2026-07-21 | uniswapV2Se | rateProviderCompare highVol mul10 | [`HIGH_VOLUME_PLAN.md`](scenarios/uniswapV2Se/rateProviderCompare/HIGH_VOLUME_PLAN.md) / FINDINGS high-vol section | `out/.../highVol/mul10/` | **complete** | Fee unchanged; R− residual **~±2.3–2.4%** (~10× baseline); Mode C probes still **0** (5% Bal fee) |
| 2026-07-21 | uniswapV2Se | rateProviderCompare highVol | Mode A/C R± both demands | `highVol/mul10/rates_{on,off}/mode{A,C}_*` | complete | tradeSizeMul=10; R+ residual 0; full 8-run matrix |
| 2026-07-21 | uniswapV2Se | rateProviderCompare highVol mul25_s48 | FINDINGS high-vol mul25 section | `out/.../highVol/mul25_steps48/` | **complete** | **Arb apparent:** Mode C fills from ~step 22; R− Mode A residual **~±10%**; fee still 5% |
| 2026-07-21 | uniswapV2Se | rateProviderCompare highVol mul25_s48 | Mode C R− buys WETH | `highVol/mul25_steps48/rates_off/modeC_market_buys_weth` | complete | fills **~46**; first probe ~22; cum arb profit ≫ 0 |
| 2026-07-21 | uniswapV2Se | rateProviderCompare | [`AGENT_RESEARCH_REPORT.md`](scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md) | artifacts under `out/.../rateProviderCompare/` | **handoff** | Internal report: fee threshold + R+/R−; agents should not re-run matrices |
| — | uniswapV2Se | B | — | — | todo | Drive Balancer first |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | research | [`FINDINGS.md`](scenarios/dualLiquidityLinkedCrossVersion/FINDINGS.md) / [`AGENT_RESEARCH_REPORT.md`](scenarios/dualLiquidityLinkedCrossVersion/AGENT_RESEARCH_REPORT.md) | `out/dualLiquidityLinkedCrossVersion/` | **complete v1** | Mode A: R+ residual≈0, R− residual grows; Mode B preview exact (off) / few-wei (on) |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | Mode A rates_off | legDemand | `.../rates_off/modeA_legDemand` | complete | residualA ~+1.86e-4 |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | Mode A rates_on | legDemand | `.../rates_on/modeA_legDemand` | complete | residualA dust −1 |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | Mode B rates_off/on | depositCommon | `.../modeB_depositCommon` | complete | preview==exec (exact off) |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | **v2 planned** | [`DualLiquidity_Research_v2_PRD.md`](scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_PRD.md) / [plan](scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md) | `out/.../v2/` | **planned** | Linked volume + share-book; Mode B first; rates-off hero; no Mode C gate |
| — | detf/* | — | — | — | not started | After SE foundation / DualLiquidity research |

## Reconstruction checklist (any scenario)

- [ ] Forge script under `scripts/foundry/research/`
- [ ] Tracked markdown under `research/scenarios/<product>/`
- [ ] Row in this log
- [ ] `./research/run_*.sh` or documented forge + `plot_all_mode_a.py` + `stamp_meta.py`
- [ ] `meta.json` contains params + `gitCommit` after stamp
