# Funded DETF staking and SY — implementation review

**Release status: validation in progress.** This report covers the owner-authorized [implementation plan](./DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) and [alignment PRD D32–D66](./DETF_ALIGNMENT_PRD.md). It is not a release approval or a production deployment record.

The final launch-only correction PR-08 populates the required Balancer stable hook exit/query facets through its existing FactoryService. Only that library and its two script entrypoints are affected; all production contracts, tests, dependencies and compiler configuration are unchanged. The explicit complete build including all 294 maintained scripts passed in 132.233 seconds after compiling those three sources. The 31,305 hermetic, 27 targeted and 35 pinned-fork passes retain their original executed provenance and are reused through `production-readiness/pr08-script-only-evidence-reuse.json`; they are not represented as rerun results. Local deployment resumes only stage 06/09 and export, then the 39-case lifecycle and complete funding simulation.

## Current checkpoint — 2026-09-10

The owner reports that all tests now pass; historical failure totals below describe earlier snapshots. [P0 provenance](../../../implementation-artifacts/detf-funded-staking/production-readiness/P0_BASELINE.md) records the report without inventing missing logs or a tested fingerprint. The previous `funded-final` process is not active and did not record successful completion.

The [remaining readiness plan](./DETF_PRODUCTION_READINESS_REMAINING_IMPLEMENTATION_PLAN.md) is executing. Two V4 production rounding fixes passed 11 focused regressions. The subsequent PR-04 core authorization fix and PR-05 isolated deployment export are applied; the corrected candidate is frozen at local source/configuration SHA `231e505d8379c41deb1905d933d32e2b9974f358f84bce169d056f07d4384c75` and Crane source/configuration SHA `b45a057611f782040ee29f1fddbbcc8eeba01def2c9341ef01c6bb65f685e123`. The superseded build completed successfully in 15,790.852 seconds, and its source guard rejected stale acceptance. The corrected complete build passed in 27,719.527 seconds, including maintained scripts. All 27 security/boundary regressions passed with zero failures/skips; the unfiltered hermetic suite passed all 31,305 tests across 2,695 suites with zero failures/skips. The 410 frontend tests, lint and typecheck passed; 28 required caller ABI declarations reconcile. All 27 renewed provider fork cases and all eight retained V3 cases pass at the required pins. The fresh corrected strict local architecture deployment is in progress; 39 lifecycle cases, the isolated funding quote and final acceptance remain pending.

Current status is in [execution-status.md](../../../implementation-artifacts/detf-funded-staking/execution-status.md). Historical completed and failed checkpoints below describe their own snapshots. They are not current failures or active process descriptions.

## Implemented behavior

- DETF and sDETF use nine decimals. Staking credits only actually received DETF, supports equal-unit redemption, and increases balances only through funded rewards. Standing fee/creator weights survive redemption of their ordinary sDETF balances.
- Purchased bonds hold funded staked principal. Principal vests linearly; staking rewards can be claimed independently while vesting. Claims pay sDETF. Bond ownership transfers the remaining entitlement.
- Automatic expansion uses fixed eight-hour boundaries anchored by the first bond and one aggregate catch-up. Issuance seigniorage distributes immediately. Each distribution rebases existing stake before issuing its fee/creator receipts.
- All four V4 DETF reserve families use mandatory price gates with reserve-swap fallback. Standard Exchange and Pendle SY routes expose the approved issuance, redemption and staking composition.
- Deployment fixes reserve liquidity permissions. Restricted additions remain DETF-only; restricted withdrawals also allow the current `feeTo()` Fee Collector to redeem owned/authorized LP. Recipient rotation uses the live oracle address. Public swaps remain available in either mode.
- Own-reserve LP bond payments transfer the entire position into protocol ownership and value its non-DETF legs. Existing contained DETF is inventory, not another issuance. The route applies its bonus once, issues no duplicate matching liquidity leg, and charges seigniorage only on newly issued DETF.
- V3/V4 position vaults require both assets for activation, convert imports to full range, and account for exact deployed amounts, earned fees and sleeves once. Subsequent single-token deposits and available sleeve operations during pool locks remain supported.
- Obsolete V4 mature-close arguments, getters, storage and dead code are removed under the explicit owner approval. Unread position caches, unused V4 wings and unused V3 import metadata are removed. Funded claims and standard exits remain.

## Scope retained

Balancer-hosted DETFs are excluded under D60, except required compilation maintenance. Unrelated Balancer SE work remains included. Unfinished Slipstream work and its release gates are deferred under D66; existing functionality, tests and completed evidence remain preserved. Work is in the main repository and retains unrelated changes. No production deployment or migration is authorized by this work.

## Completed validation checkpoints

These selections overlap and must not be added together as a full-suite result. Evidence files are under `implementation-artifacts/detf-funded-staking/`.

| Checkpoint | Result | Evidence |
|---|---|---|
| Pre-remediation complete contracts/tests plus 294 maintained scripts | Passed; 20,057.124 seconds | `hermetic-followups-before-validation-remediation/implementation-full-build.json` |
| Pre-remediation unfiltered default tests | 19,858 passed / 7,973 failed / zero skipped; 2,699 suites; 4,842.791 seconds | `hermetic-followups-before-validation-remediation/implementation-hermetic-test.json`, `hermetic-followups-before-validation-remediation/current-hermetic-baseline-attribution.json` |
| Prior complete contracts/tests plus 294 maintained scripts | Passed; 23,391.542 seconds | `pre-provider-build-checkpoint/implementation-full-build.json` |
| Post-build funded/composed integration | 48 passed / 22 suites | `pre-provider-build-checkpoint/post-build-followups.json` |
| Current local provider follow-ups | V2 8, Camelot 22, Aerodrome 37, ERC-4626 13; all passed | `*-funded-followups-run.json` |
| Broad V3/V4 position selection | 1,943 passed / 54 failed; 1,997 cases / 265 suites; all required suites executed | `position-cleanup-funded-followups-run.json` |
| Corrections for those 54 failures and retained conservation checks | 333 passed / 46 suites; zero failures/skips; every affected decimal leaf retained | `position-cleanup-runtime-migrations-run.json`, `position-runtime-failure-migration-map.json` |
| Actual Rocket Pool v3/v4 | Seven passed at each pinned block, 24,000,000 and 25,934,585 | `rocket-post-position-live-projection-fork-run.json`, `rocket-v4-post-position-live-projection-fork-run.json` |
| Actual sfrxETH | Four passed at block 24,000,000 | `sfrxeth-post-position-live-projection-fork-run.json` |
| Earlier actual EtherFi / Lido | Five / four passed | Preserved provider fork records linked from the implementation plan |
| V4 route gas regressions | All 343 selected cases passed; relevant money-path calls constrained to 31M gas | `v4-cached-orbital-343-green-*`, `orbital-v4-position-gas-after-cached-claim.json` |
| Frontend | Lint, typecheck, 410 tests / 59 files passed | `frontend-v2-query-package-check.json` |
| Bond presentation | Eight SVG fixtures rendered and reviewed | Preserved SVG fixture artifacts |

Every selected V3/V4 production component fits EIP-170. The latest removal of unused V3 NFT storage occurred after the 333-case recheck; its matching full build/hermetic evidence is preserved in the pre-remediation archive; final source reconciliation remains required. ABI/source-closure checks complement actual deployed-proxy tests and do not replace them.

## Test consolidation and performance

The initial 45-source position fixture migration maps 349 declarations to 345, with explicit replacement coverage and no unmapped retirement. The subsequent nine-source runtime corrections preserve declaration counts and every decimal leaf. V4 decimal imports now use the actual vendored PositionManager instead of a non-funding test double; E1 conservation redeems every attacker share instead of requesting one output unit.

The current comparison reuses the archived source descriptions/hashes for immutable baseline `e08b415733e729471779dcb8102529631330ea16`, because its original worktree and Git object are no longer available. It validates the exact baseline commit and all 3,112 required paths, then recomputes the current side. Across those files, 1,638 are unchanged, 978 updated, 474 removed/moved and 22 added. The archive path and SHA-256 are recorded in `current-test-consolidation.json`; this is evidence reuse, not a fresh read of unavailable Git blobs. These totals include preserved unrelated changes and excluded families; they are not a task-specific change count. The supplemental retirement map covers 493 declarations in 77 sources, and every in-scope removed declaration has a consolidation record. These source counts do not replace executable inherited-case counts or runtime evidence.

The final compiled default inventory is 2,695 concrete test contracts / 31,305 methods versus the independent baseline's 3,073 / 36,563. All 31,305 current cases executed and passed. In-scope/shared methods decrease from 29,085 to 27,551 while their concrete contract count increases from 2,090 to 2,126. Excluded/deferred families are accounted separately. In-scope artifact bytes increased; total test artifact bytes decreased. The current complete build took 27,719.527 seconds and the full test command 1,042.441 seconds. Different snapshots, failures, cache states and scope prevent a controlled full-suite timing comparison. The identical 14-case comparison passes before and after with reduced setup EVM gas in two cases but higher command wall time. The attempted provider-cache seed did not eliminate compilation. **No full-suite speedup is claimed.**

## Remaining acceptance

The [current queue](../../../implementation-artifacts/detf-funded-staking/current-implementation-queue.json) and [acceptance matrix](../../../implementation-artifacts/detf-funded-staking/acceptance-progress.json) track the corrected candidate. Older remediation counts, process IDs and source fingerprints are preserved in the [pre-reconciliation report](../../../implementation-artifacts/detf-funded-staking/production-readiness/before-validation-report.md). They must not be interpreted as newly observed failures after the owner's passing run.

Required before completion:

1. Complete the remaining local checks after the matching build, full hermetic suite, 27 security regressions and 35 pinned fork cases have all passed.
2. Deploy the corrected core and current packages on the strict isolated Robinhood fork; pass all 39 lifecycle cases under the runtime and transaction limits. Do not reuse the vulnerable pinned core.
3. Reconcile final source closures, artifact sizes/linking, package/proxy selectors, constructor payloads, storage, callers and compiled test counts. Reuse matching frontend/presentation evidence where its dependencies are unchanged.
4. Close each applicable A1–A42 requirement, publish the exact local release manifest and complete the deployment handoff. Public deployment and fund migration remain outside this execution.

The immutable comparison baseline is `e08b415733e729471779dcb8102529631330ea16`; it is distinct from the owner's latest reported pass. Historical counts are not summed with overlapping selections. The local rehearsal enforces EIP-170 and a 32M block gas limit. Finite fuzz coverage does not establish a universal gas bound. This internal review is not an independent external audit.
