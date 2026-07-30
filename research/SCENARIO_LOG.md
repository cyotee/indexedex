# Scenario log

One row per completed research run. **Narrative** lives under `research/scenarios/` (tracked). **Artifacts** live under `research/out/` (generated, gitignored).

**Marketing / performance roll-up (start here):** [`MARKETING_AND_PERFORMANCE_FINDINGS.md`](./MARKETING_AND_PERFORMANCE_FINDINGS.md)

**Reproduce Mode A:** `./research/run_mode_a.sh`  
**Reproduce Mode C:** `./research/run_mode_c.sh` (`FOUNDRY_PROFILE=default`)  
**Reproduce rateProviderCompare:** `./research/run_rate_provider_compare.sh` (`FOUNDRY_PROFILE=default`)  
**Reproduce Single SE DETF Phase 3:** `./research/run_detf_single_se.sh` (`FOUNDRY_PROFILE=default`)  
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
| 2026-07-21 | dualLiquidityLinkedCrossVersion | **v2 complete** | [`FINDINGS_v2.md`](scenarios/dualLiquidityLinkedCrossVersion/FINDINGS_v2.md) / [PRD](scenarios/dualLiquidityLinkedCrossVersion/DualLiquidity_Research_v2_PRD.md) | `out/.../v2/rates_off/` | **complete** | H2 PASS: BPT+SE legs incl. tokenA/tokenB; Mode A mark flat under Uni-only |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | v2 Mode B tokenB (gap closed) | deposit_tokenB | `v2/rates_off/modeB_depositTokenB` | **complete** | nested min fix; vaultB+BPT volume; peer of tokenA |
| 2026-07-21 | cca | **rehearsal planned** | [`CCA_Rehearsal_PRD.md`](scenarios/cca/CCA_Rehearsal_PRD.md) / [plan](scenarios/cca/CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md) | `out/cca/rehearsal/` | **planned** | Auction UX + settle + post-clear DualLiquidity seed; auction ads readiness |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | v2 Mode B P0 | deposit_common / deposit_tokenA | `v2/rates_off/modeB_deposit*` | complete | pair+BPT / vaultA+pair+BPT volume |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | v2 Mode B P1 | pairShare, vaultAShare, swap A→B | `v2/rates_off/modeB_*` | complete | SE-share joins; swap exec without reserve live Δ |
| 2026-07-21 | dualLiquidityLinkedCrossVersion | v2 Mode A | legDemand rates-off | `v2/rates_off/modeA_legDemand` | complete | share_book_pnl; mark flat; residual ~1.86e-4 |

| 2026-07-30 | detf/singleSe | Phase 3 full | [`scenarios/detf/singleSe/FINDINGS.md`](scenarios/detf/singleSe/FINDINGS.md) | `out/detf/singleSe/` | **complete** | D0–D9 + F1–F4,F7–F9; RQ1–RQ10 PASS; Uni V2 SE + Single SE DETF hermetic |
| 2026-07-30 | detf/singleSe | D0 inert | FINDINGS | `D0_inert` | PASS | inert; mint reverts; defaults 1.05/0.95 |
| 2026-07-30 | detf/singleSe | D1 firstBond | FINDINGS | `D1_firstBond` | PASS | live after first bond |
| 2026-07-30 | detf/singleSe | D2 policyDeadband | FINDINGS | `D2_policyDeadband` | PASS | burn-side post-bond; mint blocked |
| 2026-07-30 | detf/singleSe | D3 policyMintAllowed | FINDINGS | `D3_policyMintAllowed` | PASS | preview==exec exact; Uni trades |
| 2026-07-30 | detf/singleSe | D4 policyBurnGate | FINDINGS | `D4_policyBurnGate` | PASS | burn when synth < 0.95 |
| 2026-07-30 | detf/singleSe | D5 openControl | FINDINGS | `D5_openControl` | PASS | Open no expansion on warp |
| 2026-07-30 | detf/singleSe | D6 capitalSeigniorage | FINDINGS | `D6_capitalSeigniorage` | PASS | serial mints supply ↑ |
| 2026-07-30 | detf/singleSe | D7 bondVsMint | FINDINGS | `D7_bondVsMint` | PASS | free holder no expansion airdrop |
| 2026-07-30 | detf/singleSe | D8 naturalExpansion | FINDINGS | `D8_naturalExpansion` | PASS | Policy supply ↑ after warp; Open twin no |
| 2026-07-30 | detf/singleSe | D9 protocolCompound | FINDINGS | `D9_protocolCompound` | PASS | protocol BPT principal ↑ |

## Reconstruction checklist (any scenario)

- [ ] Forge script under `scripts/foundry/research/`
- [ ] Tracked markdown under `research/scenarios/<product>/`
- [ ] Row in this log
- [ ] `./research/run_*.sh` or documented forge + `plot_all_mode_a.py` + `stamp_meta.py`
- [ ] `meta.json` contains params + `gitCommit` after stamp
