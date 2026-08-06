# Orbital Hook Research — Implementation Plan

## Status

**ACTIVE** (2026-08-06)

## Layout

```text
scripts/foundry/research/uniswapV4/hooks/orbital/
  ResearchFixture_OrbitalHook.sol
  Script_H0_Smoke.s.sol
  Script_H1_Demand01.s.sol
  Script_H1_Demand10.s.sol
  Script_H2_Preview.s.sol

research/run_uniswap_v4_orbital_hook.sh
research/plots/plot_uniswap_v4_hook_mids.py   # shared hook mids + reserves
```

## Fixture API

Inherit `TestBase_UniswapV4OrbitalSwapHook` with empty `setUp()` override; expose:

- `bootstrapResearch()` → call parent setUp body  
- `seedLiquidity(uint256 perLeg)` → `_seedThreeLeg`  
- `swapExactIn(tokenIn, tokenOut, amount)`  
- `initTelemetry(runId)` / `sample(tag)` → JSONL via `ResearchTelemetry`  
- Public getters: hook, tokens, radius, reserves, LP balance of research book

## Telemetry fields (JSON object per line)

`step`, `tag`, `radius`, `r0`, `r1`, `r2`, `lpSupply`, `bookLp`, `previewOut`, `execOut`, `mid01`, `mid12`, `mid02` (raw ratios where defined), indices vs t0.

## Milestones

| M | Deliverable |
|---|-------------|
| M0 | Fixture bootstrap + H0 |
| M1 | H1a/H1b |
| M2 | H2 preview |
| M3 | Plot + NOTES + FINDINGS |

## Runner

```bash
./research/run_uniswap_v4_orbital_hook.sh           # all
./research/run_uniswap_v4_orbital_hook.sh --h0
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/uniswapV4/hooks/orbital/Script_H0_Smoke.s.sol:Script_H0_Smoke -vv
```
