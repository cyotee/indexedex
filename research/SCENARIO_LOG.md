# Scenario log

One row per completed research run. **Narrative** lives under `research/scenarios/` (tracked). **Artifacts** live under `research/out/` (generated, gitignored).

**Reproduce Mode A:** `./research/run_mode_a.sh`  
**Reproduce Mode C:** `./research/run_mode_c.sh` (`FOUNDRY_PROFILE=default`)

| Date | Product | Mode | Scenario doc | Artifact dir | Status | One-line finding |
|------|---------|------|--------------|--------------|--------|------------------|
| 2026-07-20 | uniswapV2Se | A | [`scenarios/.../modeA_trade_usdc.md`](scenarios/uniswapV2Se/modeA_trade_usdc.md) | `out/.../modeA_trade_usdc` | polished | Buy WETH: uni +0.48%; rateW↓ rateU↑; rateW×uni=rateU; total/start **+0.479%**; fee **+7.3 USDC** |
| 2026-07-20 | uniswapV2Se | A | [`scenarios/.../modeA_trade_weth.md`](scenarios/uniswapV2Se/modeA_trade_weth.md) | `out/.../modeA_trade_weth` | polished | Buy USDC: mirror rates; total/start **−0.477%**; fee **+7.3 USDC** |
| 2026-07-20 | uniswapV2Se | A | [`MODE_A_FINDINGS.md`](scenarios/uniswapV2Se/MODE_A_FINDINGS.md) | — | summary | SE foundation story locked |
| 2026-07-20 | uniswapV2Se | C | [`MODE_C_FINDINGS.md`](scenarios/uniswapV2Se/MODE_C_FINDINGS.md) | `modeC_market_buys_*` | core done | **Zero residual** after Uni (probes 0); rate alignment finding |
| 2026-07-20 | uniswapV2Se | C | [`modeC_market_buys_usdc.md`](scenarios/uniswapV2Se/modeC_market_buys_usdc.md) | `out/.../modeC_market_buys_usdc` | complete | fills=0, maxBuy/SellProbe=0; P&L = Mode A twin |
| 2026-07-20 | uniswapV2Se | C | [`modeC_market_buys_weth.md`](scenarios/uniswapV2Se/modeC_market_buys_weth.md) | `out/.../modeC_market_buys_weth` | complete | fills=0, probes=0; total/start **+0.479%**; fee **+7.3 USDC** (= Mode A twin) |
| — | uniswapV2Se | B | — | — | todo | Drive Balancer first |
| — | detf/* | — | — | — | not started | After SE foundation |

## Reconstruction checklist (any scenario)

- [ ] Forge script under `scripts/foundry/research/`
- [ ] Tracked markdown under `research/scenarios/<product>/`
- [ ] Row in this log
- [ ] `./research/run_*.sh` or documented forge + `plot_all_mode_a.py` + `stamp_meta.py`
- [ ] `meta.json` contains params + `gitCommit` after stamp
