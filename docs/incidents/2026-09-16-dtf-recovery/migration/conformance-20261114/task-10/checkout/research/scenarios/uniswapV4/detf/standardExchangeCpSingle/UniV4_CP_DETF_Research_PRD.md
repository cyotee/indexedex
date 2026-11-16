# SUPERSEDED

Family Uni V4 CP DETF diamond is deleted. Research against `UniswapV4DetfDFPkg` / `IUniswapV4Detf` and `UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md`. Do not restore the family package.

# Product Requirements Document (PRD)

## Title

Uniswap V4 Single Standard Exchange Constant Product DETF — Lifecycle Research (D0–D9)

## Status

**SUPERSEDED** — family diamond deleted (2026-08-29). Historical Phase 0 PRD only.

| Field | Value |
|-------|--------|
| **Campaign id** | `uniswapV4/detf/standardExchangeCpSingle` |
| **Product PRD** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_PRD.md` |
| **Gold TestBase** | `TestBase_UniswapV4SingleStandardExchangeDETF.sol` |
| **Reserve host** | Single SE Buffer CP Hook (same stack as TestBase) |
| **Profile** | `uv4_single_se_cp_detf` |
| **Peer campaign** | Balancer Single SE DETF [`../../../detf/singleSe/`](../../../detf/singleSe/) — **methodology twin, different host** |
| **Artifacts** | `research/out/uniswapV4/detf/standardExchangeCpSingle/` |

## Purpose

Hermetic evidence that the **Uni V4 Single SE CP buffer DETF** implements shared true-DETF law on a **hook LP reserve host**:

1. Deploy **inert**; mint blocked until first bond.  
2. Permissionless **first bond** (pair capital + DETF self-leg → hook LP) → live.  
3. **Policy** synthetic mint/burn gates (default ±5%); **Open** twin never expands.  
4. Preview == execution on closed-form pair ↔ DETF routes.  
5. Natural expansion + protocol compound per shared DETF PRD (when suite paths exist).

Results are **host-specific** figures for litepaper / marketing — not a re-run of Balancer Single SE matrices.

## Research questions

Mirror Single SE DETF RQ1–RQ10 with host wording:

| ID | Question |
|----|----------|
| **RQ1** | Inert until first bond? |
| **RQ2** | First bond → `isReserveLive` + LP principal on bond NFT? |
| **RQ3–RQ4** | Policy mint/burn synthetic gates? |
| **RQ5** | Synthetic moved by production paths (hook swaps / primary burns)? |
| **RQ6** | Preview == execution on mint? |
| **RQ7** | Open twin ungated primary? |
| **RQ8–RQ9** | Natural expansion Policy-only, bond ledger? |
| **RQ10** | Protocol compound increases protocol LP principal? |

## Scenarios

| ID | Peer | Intent |
|----|------|--------|
| D0_inert | D0 | Policy deploy inert |
| D1_firstBond | D1 | First bond → live |
| D2…D9 | D2…D9 | Same ladder as Single SE Phase 3 (implement after D0–D1 green) |

## Locked decisions

| Topic | Decision |
|-------|----------|
| Gold family | This package only (not Balancer Single SE, not Orbital DETF) |
| SE attachment | ERC-4626 wrapper SE via hook TestBase (not Uni V2 SE) |
| Thresholds | Default Policy resolve 1.05 / 0.95 |
| Synthetic drive | Production paths only — no storage hacks |
| Sell→claim | Family PRD; migrate to mature-only when product locks |
| Production-first | Registry DFPkg deploy; no mock DETF/hook |

## Progress

| Checkpoint | Status |
|------------|--------|
| PRD + plan | **done** |
| Fixture | **done** |
| D0 inert | **PASS** |
| D1 firstBond | **PASS** |
| D2–D9 | pending |
| Plots F* + FINDINGS | partial (FINDINGS D0–D1) |
