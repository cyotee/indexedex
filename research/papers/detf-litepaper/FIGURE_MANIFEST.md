# DETF litepaper — figure manifest

| Field | Value |
|-------|--------|
| **Updated** | 2026-07-30 |
| **Rule** | Hand-picked paths only; do not re-run SE matrices casually |
| **Claims** | C1–C13 in [`RESEARCH_AND_WRITING_PROGRAM.md`](./RESEARCH_AND_WRITING_PROGRAM.md) §2 |

All paths relative to monorepo root.

---

## DETF Phase 3 figures (measured)

| Fig | Path | Caption (paper-ready) | Claims | Source |
|-----|------|----------------------|--------|--------|
| **F1** | `research/out/detf/singleSe/figures/F1_lifecycle.png` | Inert Policy deploy → first bond of Uni V2 SE shares → live reserve. User mint blocked until live. | C3 | D0–D1 |
| **F2** | `research/out/detf/singleSe/figures/F2_synthetic_thresholds.png` | Synthetic price vs abstract peg with default mint/burn bands (1.05 / 0.95). Allowed mint and burn regions under Policy. | C2, C4 | D2–D4 |
| **F3** | `research/out/detf/singleSe/figures/F3_demand_to_synthetic.png` | Market and inventory paths that move synthetic under Policy (real Uni trades + production free-DETF burn path; no storage hacks). | C2, C4 | D3 |
| **F4** | `research/out/detf/singleSe/figures/F4_preview_vs_execution.png` | Closed-form capital mint: preview amount equals execution amount (exact on measured D3 path). | C6 | D3 |
| **F7** | `research/out/detf/singleSe/figures/F7_bond_vs_mint.png` | Bond effective-share reward path vs free unlocked DETF holder (no expansion airdrop to free-only holders). | C9, C12 | D7 |
| **F8** | `research/out/detf/singleSe/figures/F8_expansion_policy_vs_open.png` | Natural expansion when Policy + mint-rich + time; Open twin shows no expansion over the same warp. | C12 | D5, D8 |
| **F9** | `research/out/detf/singleSe/figures/F9_protocol_compound.png` | Protocol NFT BPT principal before/after permissionless `compoundProtocolRewards`. | C13 | D9 |
| **F10** | *(optional; omit if thin)* | Reserve composition / supply under serial capital mints | C2 | D6 |

Reproduce DETF figures:

```bash
./research/run_detf_single_se.sh          # full
./research/run_detf_single_se.sh --plot-only
```

---

## SE nested mark integrity (harvest — Phase 1)

| Fig | Path | Caption (paper-ready) | Claims | Source |
|-----|------|----------------------|--------|--------|
| **F5** | `research/out/uniswapV2Se/rateProviderCompare/compare/A_uni_only_WETH/fairness_compare.png` | **R+ vs R− residual under Uni-only demand.** Rates on: residual ≈ 0. Rates off: residual grows with Uni tilt (~±0.24% baseline ladder). | C7 | rateProviderCompare baseline Mode A |
| **F6** | `research/out/uniswapV2Se/rateProviderCompare/highVol/mul25_steps48/compare/C_uni_plus_bal_arb_WETH/probes_compare.png` | **Fee as economic threshold.** Extreme volume (mul=25, 48 steps) pushes R− residual above research 5% Balancer fee scale; Mode C probes/fills appear. Modest residual under same fee → no fills. | C8 | high-vol mul25_s48 |

### Supporting (optional inset / appendix)

| Path | Use |
|------|-----|
| `research/out/uniswapV2Se/rateProviderCompare/compare/A_uni_only_WETH/pnl_compare.png` | R+/R− P&L overlay (coincide under Uni-only) |
| `research/out/uniswapV2Se/rateProviderCompare/highVol/mul25_steps48/compare/A_uni_only_WETH/fairness_compare.png` | Residual scale ~10–12% at extreme tier |
| `research/out/uniswapV2Se/modeA_trade_weth/price_index.png` | Mode A demand → price re-mark (one direction) |

**Do not re-run** unless parameters change:

```bash
# only if artifacts missing
FOUNDRY_PROFILE=default ./research/run_rate_provider_compare.sh
FOUNDRY_PROFILE=default ./research/run_rate_provider_compare.sh --high-vol-25s48
```

### Transferability caveats (must appear near F5–F6)

1. Hermetic research, not mainnet measurement.  
2. Research Balancer const-prod swap fee is **5%** (`5e16`) — not retail 0.3%.  
3. Residual measures mark lag; **residual ≠ profit**. Closer must clear Balancer fee + SE usage fee + impact + dust.  
4. DETF product fees may differ; cite mechanism, not universal fill rates.

Canonical SE summary: [`../../scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../../scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md).

---

## Claim → figure map

| Claim | Primary figures |
|-------|-----------------|
| C2 pricing engine | F2, F3 |
| C3 inert → live | F1 |
| C4 Policy/Open gates | F2, F8 |
| C6 preview honesty | F4 |
| C7 nested rates on | F5 |
| C8 fee threshold | F6 |
| C9 bond vs mint books | F7 |
| C12 natural expansion | F8 |
| C13 protocol compound | F9 |

---

*End of figure manifest.*
