# modeC_market_buys_usdc

**Tracked notes.** Artifacts: `research/out/uniswapV2Se/modeC_market_buys_usdc/`.  
**Summary:** [`MODE_C_FINDINGS.md`](./MODE_C_FINDINGS.md) · **Mode A twin:** [`modeA_trade_weth.md`](./modeA_trade_weth.md)

## One-line story

Market buys **USDC** on Uni (WETH→USDC), then closer tries to capture Balancer residual in **WETH**.

## Setup

- Same init as Mode A  
- Drive: `Script_ModeC_MarketBuysUsdc` — 1 WETH × 24 + `closeBalancerArbs` each step  
- Profit token: WETH  

## Observed (2026-07-20)

| Chart / field | Result |
|---------------|--------|
| `rates.png` / `price_index.png` | Same qualitative paths as `modeA_trade_weth` |
| `pnl_normalized.png` | total/start **−0.477%** (matches Mode A twin) |
| `arbFills` | **0** all steps |
| `maxBuyProbe` / `maxSellProbe` | **0** all steps |
| `positiveProbes` | **0** |

Conclusion: no profitable residual after Uni demand — see [`MODE_C_FINDINGS.md`](./MODE_C_FINDINGS.md).

## Commands

```bash
./research/run_mode_c.sh
# or:
FOUNDRY_PROFILE=research forge script \
  scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysUsdc.s.sol:Script_ModeC_MarketBuysUsdc -vv
python research/plots/plot_all_mode_a.py research/out/uniswapV2Se/modeC_market_buys_usdc
```
