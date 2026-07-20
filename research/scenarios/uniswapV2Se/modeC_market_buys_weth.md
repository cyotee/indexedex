# modeC_market_buys_weth

**Tracked notes.** Artifacts: `research/out/uniswapV2Se/modeC_market_buys_weth/`.  
**Summary:** [`MODE_C_FINDINGS.md`](./MODE_C_FINDINGS.md) · **Mode A twin:** [`modeA_trade_usdc.md`](./modeA_trade_usdc.md)

## One-line story

Market buys **WETH** from our Uni V2 liquidity (flow: USDC → WETH), then the Mode C closer probes Balancer residual in **USDC**. Under default rate-provider re-marking, residual is empty — same economics as Mode A twin, plus documented zero arb probes.

## Setup

| Item | Value |
|------|--------|
| Product | Uni V2 SE WETH/USDC + 4 Balancer CP share pools |
| Mode | `C_uni_plus_bal_arb` |
| Drive | `Script_ModeC_MarketBuysWeth` — 1000 USDC exact-in × 24 + `closeBalancerArbs` each step |
| Profit token | USDC (market sells USDC into Uni / buys WETH) |
| Framing | LP / market demand (not “we sell”) |

## Observed (2026-07-20 full run)

| Field | Result |
|-------|--------|
| Steps | 25 (init + 24) |
| `meta.marketBoughtAsset` | **WETH** |
| `meta.tradedAsset` | **USDC** |
| Uni USDC/WETH index end | **~1.00480** |
| SE rate(WETH) index end | **~0.99761** |
| SE rate(USDC) index end | **~1.00240** |
| Total P&L / start | **~+0.479%** |
| Fee P&L | **~+7.33 USDC** |
| `arbFills` (sum) | **0** |
| `maxBuyProbe` / `maxSellProbe` | **0** all steps |
| `positiveProbes` | **0** |

Matches Mode A twin `modeA_trade_usdc` when arb is idle — expected under SE rate → Balancer live mid re-marking.

## Charts (review order)

1. `rates.png`  
2. `price_index.png`  
3. `pnl_normalized.png`  
4. `pnl.png`  
5. `inventory.png`  

## Reproduce

```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysWeth.s.sol:Script_ModeC_MarketBuysWeth -vv
python research/plots/stamp_meta.py research/out/uniswapV2Se/modeC_market_buys_weth \
  --script scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysWeth.s.sol:Script_ModeC_MarketBuysWeth
python research/plots/plot_all_mode_a.py research/out/uniswapV2Se/modeC_market_buys_weth
```

Or: `./research/run_mode_c.sh` (both Mode C directions; slow).

## Caveats

- Hermetic; not live APY.  
- Zero residual is a **product finding**, not a failed closer.  
- Mode C is slow (snapshot probes per pool per step).  
