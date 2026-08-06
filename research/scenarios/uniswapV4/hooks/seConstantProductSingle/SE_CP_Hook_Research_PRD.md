# Product Requirements Document (PRD)

## Title

Uniswap V4 Single SE Buffer Constant Product Hook — SE Composition + Demand Research

## Status

**ACTIVE** (2026-08-06)

| Field | Value |
|-------|--------|
| **Campaign id** | `uniswapV4/hooks/seConstantProductSingle` |
| **Product PRD** | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md` |
| **Gold TestBase** | `…/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol` |
| **Profile** | `single_se_buffer_cp_hook` |
| **Artifacts** | `research/out/uniswapV4/hooks/seConstantProductSingle/` |

## Purpose

Evidence that the **asymmetric SE buffer CP hook** (raw leg ↔ pairToken + SE-wrapped pair) behaves as a Uniswap V2-like market with SE composition:

1. Inert until first liquidity (`isLive`).  
2. Dual-sided deposit goes live; single-sided deposit per product rules.  
3. Market demand via V4 swap moves reserves / mid.  
4. Preview honesty on deposit/withdraw/swap.  
5. Bound **ERC-4626 wrapper SE** remains production path (TestBase gold).

## Research questions

| ID | Question |
|----|----------|
| **RQ-S0** | Deploy inert; first dual deposit → live |
| **RQ-H1** | Exact-in demand moves mid and inventory |
| **RQ-H2** | previewDeposit / previewSwap match execution |
| **RQ-S1** | SE share rate change (if exercised) re-marks effective pair reserve |

## Scenarios

| ID | Intent |
|----|--------|
| **H0_smoke** | Deploy package; sample isLive=false |
| **S0_firstDeposit** | Dual deposit → live; LP > 0 |
| **H1_demand_raw** | Market buys raw with pair (or reverse) N steps |
| **H2_preview** | One swap preview==exec |

## Locked decisions

| Topic | Decision |
|-------|----------|
| SE in research | ERC-4626 wrapper SE only (product D63T) |
| No multi-SE matrix | Single SE attachment |
| Production-first | Hook factory + registry path |

## Progress

| Checkpoint | Status |
|------------|--------|
| PRD + plan | **done** |
| Fixture / H0 | pending |
