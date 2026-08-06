# H0_smoke

## One-line story
Orbital Swap Hook deploys via production package path; radius 0 until first LP; seed establishes sphere.

## Setup
- Product: Uniswap V4 Orbital Swap Hook (3-asset)
- Path: hook factory + registry deployHookVault (TestBase)
- Seed: 500 ether per leg

## What the series shows
1. pre_seed: radius=0, reserves empty
2. post_seed: radius>0, equal-ish reserves, LP supply>0

## Caveats
- Hermetic mintable tokens; not live APY
- Numeraire = token units 1:1

## Commands
```bash
forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H0_Smoke.s.sol:Script_H0_Smoke -vv
```
