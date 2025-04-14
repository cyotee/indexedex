# 2026-01-10 — DEX Review: Aerodrome Slipstream (Concentrated Liquidity)

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md

## Status

No Slipstream StandardExchange vault implementation is present in this worktree under the planned `contracts/protocols/dexes/aerodrome/slipstream/` paths.

This note is therefore limited to:
- the plan/spec text in `UNIFIED_PLAN.md`, and
- Crane’s Slipstream math + interfaces already vendored in-repo.

## Key in-repo dependencies (Crane)

- `lib/daosys/lib/crane/contracts/utils/math/SlipstreamUtils.sol`
- `lib/daosys/lib/crane/contracts/utils/math/SlipstreamQuoter.sol`
- `lib/daosys/lib/crane/contracts/utils/math/SlipstreamZapQuoter.sol`
- `lib/daosys/lib/crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol`

## High-risk checkpoints before implementation review

- Plan vs math semantics: ensure “below-range / above-range” token0/token1 semantics in `UNIFIED_PLAN.md` match the semantics used by `SlipstreamUtils` (standard V3-style behavior).
- Hard invariant: plan requires `previewExchangeIn == exchangeIn` exactly (0 tolerance). Any quoting implementation must be deterministic and mirrored.
- Tick spacing: implementation must read `pool.tickSpacing()`; do not hardcode fee-tier→tickSpacing mappings.
- Partial fills: quoters can report `fullyFilled=false`; define deterministic dust handling.

## Suggested tests once implementation exists

- Fork test(s) for custody + callbacks + consolidate/compound behavior.
- Preview/execution parity tests under fee growth + uncollected fees.
