# Product Requirements Document (PRD)

## Title

Uniswap V4 Standard Exchange Weighted DETF — Research Campaign (BLOCKED)

## Status

**BLOCKED** (2026-08-06) — product is PRD/plan only under  
`contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/`.  
No package code, TestBase, or hermetic suite.

| Field | Value |
|-------|--------|
| **Campaign id** | `uniswapV4/detf/standardExchangeWeighted` |
| **Product PRD** | `UniswapV4StandardExchangeWeightedDETF_PRD.md` (draft v0.4) |
| **Research gate** | Closed until package + gold TestBase land |

## Unblock criteria

1. Production DFPkg + facets via registry path  
2. Gold `TestBase_*` composing SE Weighted Buffer Hook  
3. Hermetic suite: deploy, first bond, mint/burn, gates  
4. Campaign PRD revision opens D0–D9 harness work  

## Placeholder research questions

Same RQ1–RQ10 as other true DETFs, plus family deltas from product PRD (per-route synthetic, all-legs-rich expansion, single-asset later bonds).

## Progress

| Checkpoint | Status |
|------------|--------|
| PRD stub | **done** |
| Implementation | **blocked** |
