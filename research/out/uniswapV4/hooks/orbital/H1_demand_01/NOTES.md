# H1_demand_01

## One-line story
After equal three-leg seed, market repeatedly buys token1 with token0 on the orbital pair door.

## Setup
- Seed: 500 ether per leg; dex fee 0.3%
- Drive: exact-in token0->token1, 1 ether x 24 steps
- Book: research user LP from seed (passive)

## What the series shows
1. midIndex01 moves as r1/r0 changes vs init
2. r0 rises (token in), r1 falls (token out)
3. radius / lpSupply stay defined (sphere state)

## Caveats
- Hermetic; fee + inventory not yet split P&L panels
- mid ratios are raw reserve ratios, not USD

## Commands
```bash
forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H1_Demand01.s.sol:Script_H1_Demand01 -vv
python research/plots/plot_uniswap_v4_hook_mids.py research/out/uniswapV4/hooks/orbital/H1_demand_01
```
