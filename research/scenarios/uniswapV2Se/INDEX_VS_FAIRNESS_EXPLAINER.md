# Visual proof: different chart slopes ≠ redeem arbitrage

**Plot script:** `research/plots/plot_index_vs_fairness.py`  
**Outputs:** `research/out/uniswapV2Se/<runId>/index_vs_fairness.png`

## How to regenerate

```bash
python research/plots/plot_index_vs_fairness.py research/out/uniswapV2Se/modeA_trade_usdc
python research/plots/plot_index_vs_fairness.py research/out/uniswapV2Se/modeA_trade_weth
python research/plots/plot_index_vs_fairness.py research/out/uniswapV2Se/modeC_market_buys_usdc
python research/plots/plot_index_vs_fairness.py research/out/uniswapV2Se/modeC_market_buys_weth
```

## What to open first

| Priority | File | Why |
|----------|------|-----|
| 1 | `modeA_trade_usdc/index_vs_fairness.png` | Market buys WETH; clearest “slopes differ” story |
| 2 | `modeC_market_buys_weth/index_vs_fairness.png` | Same demand + **arb probes = 0** overlaid |
| 3 | `modeA_trade_weth` / `modeC_market_buys_usdc` | Mirror direction |

## How to read the three panels

### Panel 1 — Chart slopes differ (your observation)

- Black: Uni **USDC/WETH** index  
- Blue: Balancer mid index (USDC pair, vault rated **WETH**)  
- Red: Balancer mid index (USDC pair, vault rated **USDC**)  

These are **different meters**, all rebased to 1.0 at t0. They **should not** move at the same % rate.

### Panel 2 — True fairness residuals stay flat

Plotted near zero (scaled ×1e6 so you can see noise):

| Residual | Meaning |
|----------|---------|
| `rateWeth × uni / rateUsdc − 1` | One share claim, two numeraires — must stay ~0 |
| `midW_index × rateW_index − 1` | Frozen Balancer inventory: mid tracks **1/rate** |
| `midU_index × rateU_index − 1` | Same for USDC-rated mid |

If the system were “breaking” into free redeem arb via rate lag, these would drift. They don’t.

### Panel 3 — Mistaken chart gap vs real arb probe

| Series | Meaning |
|--------|---------|
| Orange | `(Uni_index / midW_index − 1)` — the **misleading** “gap” from panel 1 |
| Green / purple (Mode C only) | `maxBuyProbe` / `maxSellProbe` — **actual** simulated buy-share→redeem / sell profit in wei |

**Mode C runs:** orange can move; green/purple stay **0**.  
That is the proof: a large-looking index ratio is not `(redeem − buy cost)`.

## Reproduce paths for underlying data

```bash
# Mode A (no arb probes in series)
./research/run_mode_a.sh

# Mode C (includes probe fields)
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysWeth.s.sol:Script_ModeC_MarketBuysWeth \
  -vv --offline
python research/plots/plot_index_vs_fairness.py research/out/uniswapV2Se/modeC_market_buys_weth
```
