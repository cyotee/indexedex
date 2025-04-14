# 2026-01-10 — DEX Review: Uniswap V4

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md

## Status

Uniswap V4 vault/contracts appear to be planned in `UNIFIED_PLAN.md`, but are not present as concrete implementation under `contracts/protocols/dexes/uniswap/v4/` on `main` in this worktree.

## Reviewable today

- Plan/spec: `UNIFIED_PLAN.md` (Uniswap V4 task section)
- Any Crane utilities intended to be reused by V4 contracts (search in `lib/daosys/lib/crane/contracts/`).

## Must-have checkpoints once implementation exists

- Hookless-only enforcement, fully tested.
- `unlockCallback` caller validation + delta settlement to zero.
- Preview/execution parity across ERC-6909 / settlement flows.
