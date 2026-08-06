# Product Requirements Document (PRD)

## Title

Uniswap V4 Standard Exchange Orbital DETF — Lifecycle Research (D0–D9)

## Status

**ACTIVE** — Phase 0 (2026-08-06). Harness after CP DETF D0–D1 path is proven (same research patterns).

| Field | Value |
|-------|--------|
| **Campaign id** | `uniswapV4/detf/standardExchangeOrbital` |
| **Product PRD** | `…/orbital/UniswapV4StandardExchangeOrbitalDETF_PRD.md` |
| **Gold TestBase** | `TestBase_UniswapV4StandardExchangeOrbitalDETF.sol` |
| **Reserve host** | SE Orbital Buffer Hook |
| **Profile** | `se_orbital_detf` (`via_ir=true`) |
| **Artifacts** | `research/out/uniswapV4/detf/standardExchangeOrbital/` |

## Purpose

True DETF on **orbital sphere** multi-leg SE buffer host. Emphasize family deltas:

- Dual-capital / multi-leg first bond  
- Per-family synthetic  
- **Mature-only sell → rebasing claim** (DETF-wide standard; this family first adopter)  
- Expansion / compound on sphere host  

## Research questions

RQ1–RQ10 as CP DETF + **RQ-M** mature-only sell→claim reverts pre-unlock; succeeds post-warp.

## Scenarios

D0–D9 + **D_claimMature** (maturity sell path) when bond/claim surfaces wired in TestBase.

## Progress

| Checkpoint | Status |
|------------|--------|
| PRD authored | **done** |
| Fixture / D0 | pending (after CP DETF smoke patterns) |
