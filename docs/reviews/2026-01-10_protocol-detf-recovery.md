# 2026-01-10 — Protocol DETF: Recovery Notes (crashed worktree)

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md

## Worktree

- `/Users/cyotee/Development/github-cyotee/indexedex-wt/feature/protocol-detf`

## Snapshot (observed)

- Dirty state: modified files + many untracked files + dirty submodules (`lib/daosys`, `lib/frontend-monorepo`).
- Local convention enforced: `foundry.toml` in that worktree sets `via_ir = false` and includes a “NEVER enable via_ir” comment.

## Recovery steps (suggested)

1) Clean submodules and remove local-only agent artifacts from commit scope.
2) Run `forge build` in that worktree to surface the first real compile blocker.
3) Fix stack-depth issues using structs + local scoping (no IR).
4) Add a minimal smoke spec that deploys the package via the CREATE3 helpers and asserts core invariants (wiring + basic ERC4626 behaviors + non-reverting entrypoints).
