# Funded DETF refactor — current execution status

The full plan remains in progress in the main repository on `codex/robinhood-release-review`. Unrelated changes are preserved. `current-implementation-queue.json` records the current work; `acceptance-progress.json` tracks criteria. Historical drafts, failures and approvals remain in their original records and the archives below.

## Scope and approval

The owner explicitly approved the V4 mature-close cleanup. It is applied: obsolete `closeRouteMode` / `closeRoutes` arguments, getters, storage, initialization, readers/writers, old LP-close accounting and the unreferenced legacy target are removed. Funded bond claims, linear vesting, staking rewards and standard exchange/SY redemption remain. No cleanup approval or product decision remains pending. See `v4-close-cleanup-owner-approval.json` and `approved-v4-close-cleanup.json`.

D60 excludes further functional refactoring of Balancer-hosted DETFs; unrelated Balancer SE work remains. D66 defers unfinished Slipstream work and release gates. Existing completed Slipstream changes, tests and evidence are preserved.

## Current validation

Solidity/configuration fingerprint: `96d7a3ff1d5d6d8f41f1ff0c7a8dd09419e8243b669dd27700325822edf63dde`.

PTY 4255 / parent 84406 runs `final-provider-repository-post-position-sequence.json`: pinned provider forks have passed, the complete default build including 294 maintained scripts passed in 20,057.124 seconds, and unfiltered hermetic execution plus exact baseline attribution are now running sequentially. Do not start another Forge or edit canonical Solidity while the sequence runs.

Completed checkpoints:

- The current full default build plus all 294 maintained script sources passed in 20,057.124 seconds. All 16 compiled funded facets/packages match current source closures and all deployable components fit EIP-170; actual proxy wiring and behavior remain part of the active hermetic test run.

- All 80 local provider cases pass: V2 8, Camelot 22, Aerodrome 37, ERC-4626 13. Selected production components fit EIP-170.
- All 333 methods in 46 affected V3/V4 suites pass. The nine-source fixture migration resolves all 54 failures from the preceding 1,997-case batch; every retained declaration/decimal leaf remains. The actual V4 position import includes principal and earned fees.
- Rocket Pool passes seven actual-protocol cases at each of blocks 24,000,000 and 25,934,585; sfrxETH passes four at 24,000,000. Earlier actual EtherFi five and Lido four cases remain recorded. These are executed checks, not merely prepared drafts.
- The previous matching complete build passed in 23,391.542 seconds, followed by 48 integration cases / 22 suites. These exact-source records are archived in `pre-provider-build-checkpoint/`; the current source still needs its own complete checks.
- Frontend lint, typecheck and all 410 tests / 59 files passed in 58.748 seconds. Eight SVG states were rendered and reviewed. The prior selected 343-case gas check enforced actual 31M money-path calls; it is finite evidence, not a universal gas guarantee.

Checkpoint counts overlap and are not a substitute for the unfiltered repository result.

## Remaining work

1. Complete the running build/hermetic/attribution sequence and resolve actual in-scope failures. An unchanged baseline failure is not an acceptance waiver.
2. Apply the prepared two-file V3 fork migration after the current sequence exits. Retain all seven declared cases plus inherited Base sanity; seed both assets before subsequent one-token/locked-pool deposits and normalize live token units. Execute the pinned real-pool checks. See `v3-fork-fixture-followup-prepared.json`.
3. Deploy current packages and run all 39 local Robinhood lifecycle cases. The visible rehearsal node/core are ready at port 18663, chain 4663, block 56,118,361, EIP-170 24,576 bytes and block gas 32M. Current package/lifecycle execution remains pending; no public deployment is in scope.
4. Reconcile final storage, selector and source-closure manifests, ABI/caller wiring, compiled suite counts, consolidation mapping and timings. Finalize the PRD acceptance matrix, plan stages and `DETF_FUNDED_STAKING_AND_SY_VALIDATION_REPORT.md` from actual evidence.

The V3 import metadata cleanup is applied and awaiting the current final regression. V4 import context remains because settlement reads it. Historical queue: `queue-history-before-final-reconciliation-7e29f3157bb9.json`. Historical status: `execution-history-before-final-reconciliation-f5c25536fd66.md`.

## Findings from the active hermetic run

The running suite has exposed an actual Stata zero-supply exact-output withdrawal defect: donated receipt inventory can produce a zero-share quote. Its existing H2 negative case catches the unauthorized withdrawal. `stata-hermetic-followups-prepared.json` contains a guard and a seven-source fixture consolidation using real Crane Stata and the actual fee manager. All 112 methods in six decimal suites typecheck; 57 retired declarations map to real replacements. Canonical source remains unchanged, and runtime validation is pending.

`production-se-fixture-followups-prepared.json` now contains 34 existing V4 fixture corrections: exact mixed-decimal V3 seeding, funded two-token activation across CP/Quad/Weighted/Orbital provider fixtures, and actual first-leg token/decimal bindings. The 33-source activation checkpoint typechecked 1,272 methods in 24 representative suites; the subsequent binding/short-payment combined check passes 133 methods in five suites. These are compiler diagnostics, not runtime acceptance.

Additional checked drafts cover current installed proxy surfaces, native-unit Balancer SE fixtures and real-package smoke consolidation, funded lifecycle purchase sizes, state-based policy triggers, actual short-payment deltas, and retirement of two fake-DETF donation overrides in favor of their inherited funded tests. Every removed local declaration has an explicit replacement map; inherited donation case counts remain unchanged. The retained V3 fork drafts typecheck and generate bytecode for all eight cases. `current-implementation-queue.json` lists every prepared source and diagnostic. Canonical Solidity/configuration remains frozen until parent 4255 finishes; all patches still require application and actual validation. No owner requirement decision is pending.
