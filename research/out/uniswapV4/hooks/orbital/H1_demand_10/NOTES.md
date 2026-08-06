# H1_demand_10

## One-line story
Mirror demand: market buys token0 with token1 for 24 steps after equal seed.

## Setup
- Same as H1_demand_01 with reversed tokenIn/tokenOut

## Expectation
midIndex01 should move opposite to H1_demand_01 under raw r1/r0 framing.

## Commands
```bash
forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H1_Demand10.s.sol:Script_H1_Demand10 -vv
```
