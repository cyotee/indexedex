# 2026-01-10 — DEX Review: Uniswap V3

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md

## Status

A Uniswap V3 StandardExchange vault/package stack appears planned in `UNIFIED_PLAN.md`, but is not present as concrete implementation under `contracts/protocols/dexes/uniswap/v3/` on `main` in this worktree.

## Reviewable today

- Plan/spec: `UNIFIED_PLAN.md`
- Crane V3 primitives/utilities under `lib/daosys/lib/crane/`.

## Checkpoints once implementation exists

- NPM custody + approval safety.
- Tick spacing validation per fee tier and per-pool.
- Preview/execution parity, especially around rounding and fee accounting.
- Callback caller validation + reentrancy boundaries.
