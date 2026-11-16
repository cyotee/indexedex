# Uni V4 CP Single DETF Research — Implementation Plan

## Status

**ACTIVE** — M0 fixture + D0/D1 first.

## Layout

```text
scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/
  ResearchFixture_UniV4CpDetf.sol
  Script_D0_Inert.s.sol
  Script_D1_FirstBond.s.sol
  # D2–D9 after D0–D1 green

research/run_uniswap_v4_cp_detf.sh
research/plots/plot_detf_univ4_cp_all.py   # reuse Single SE plot patterns
```

## Fixture API

Inherit `TestBase_UniswapV4SingleStandardExchangeDETF`:

| Method | Role |
|--------|------|
| `bootstrapResearch()` | Parent setUp |
| `deployPolicy` / already in setUp | Default Policy instance |
| `firstBond(amount)` | Expose `_firstBond` |
| `mintPair` / `burnToPair` | Expose helpers |
| `initTelemetry` / `sampleDetf` | JSONL: live, synth, thresholds, supply, bond flags, preview/exec |

## Milestone order

| M | Work |
|---|------|
| M0 | Fixture + D0 |
| M1 | D1 + lifecycle figure |
| M2 | D2–D5 gates + Open |
| M3 | D6–D7 seigniorage books |
| M4 | D8–D9 expansion/compound |
| M5 | FINDINGS + runner |

## Commands

```bash
./research/run_uniswap_v4_cp_detf.sh --d0
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D0_Inert.s.sol:Script_D0_Inert -vv
```
