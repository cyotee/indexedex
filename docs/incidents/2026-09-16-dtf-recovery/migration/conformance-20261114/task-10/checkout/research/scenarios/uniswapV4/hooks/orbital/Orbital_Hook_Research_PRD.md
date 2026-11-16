# Product Requirements Document (PRD)

## Title

Uniswap V4 Orbital Swap Hook — Hermetic Demand, LP Book, and Preview Honesty Research

## Status

**ACTIVE** — Phase 0 PRD + plan; harness in progress (2026-08-06).

| Field | Value |
|-------|--------|
| **Campaign id** | `uniswapV4/hooks/orbital` |
| **Product PRD** | `contracts/hooks/uniswap/v4/orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md` |
| **Gold TestBase** | `contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol` |
| **Profile** | `FOUNDRY_PROFILE=orbital` (or default if script compile needs broader graph) |
| **Program** | [`../../PROGRAM.md`](../../PROGRAM.md) |
| **Artifacts** | `research/out/uniswapV4/hooks/orbital/<runId>/` |

## Purpose

Produce reconstructable evidence that the **3-asset Orbital sphere hook**:

1. Deploys production-first (hook factory + registry `deployHookVault`).  
2. Seeds multi-leg LP and exposes measurable reserves / radius.  
3. Reprices under **market demand** on pair doors (exact-in).  
4. Keeps closed-form **preview == execution** on swap and LP paths.  
5. Attributes LP holder economics (inventory vs fee) under one-way demand.

**Not:** mainnet APY, Monte Carlo, DETF gates (see DETF campaigns).

## Research questions

| ID | Question |
|----|----------|
| **RQ-H0** | Does production deploy leave three pair doors live and radius 0 until first mint? |
| **RQ-H1** | After seed, do one-way exact-in swaps move reserves and mid indices in the expected door direction? |
| **RQ-H2** | Does `previewSwapExactIn` match execution (exact or ≤ few-wei documented)? |
| **RQ-H3** | How does passive LP full-exit mark change under one-way demand (price vs residual fee)? |

## Scenarios

| ID | Drive | Pass intent |
|----|-------|-------------|
| **H0_smoke** | Deploy + sample | doors live; radius 0; telemetry files |
| **H1_demand_01** | Seed equal legs; market buys token1 with token0 for N steps | reserves/mids move; series length N+1 |
| **H1_demand_10** | Mirror direction | opposite mid path |
| **H2_preview** | One swap + one remove | preview==exec |
| **H3_lpBook** | Seed; demand; sample full-exit claim each step | NOTES mechanism |

## Locked decisions

| Topic | Decision |
|-------|----------|
| Deploy path | Gold TestBase path only (CREATE3 facets + hook factory + package) |
| Tokens | Mintable 18-dec hermetic tokens (TestBase) |
| Numeraire | 1:1 token units for P&L mark (document in meta) |
| Production-first | No mock hook / manager / factory |
| Artifacts | `research/out/uniswapV4/hooks/orbital/` only |

## Progress

| Checkpoint | Status |
|------------|--------|
| PRD authored | **done** |
| Implementation plan | **done** |
| Research fixture | **done** |
| H0 smoke | **PASS** |
| H1 demand | **PASS** (01 + 10) |
| H2 preview | **PASS** |
| Plots + FINDINGS | **done** (mids_reserves + FINDINGS.md) |
| H3 LP book P&L | pending |
