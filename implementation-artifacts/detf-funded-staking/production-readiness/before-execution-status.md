# Funded DETF refactor — current execution status

The full owner-authorized plan remains in progress in the main repository on `codex/robinhood-release-review`. Unrelated changes are preserved. The owner-approved V4 mature-close cleanup is applied and has no pending approval. D60 excludes further Balancer DETF functionality; unrelated Balancer SE remains included. D66 defers unfinished Slipstream work while preserving completed code, tests and evidence.

## Active work

Current Solidity/configuration fingerprint: `26484c06fffc5dc4aaf6fcaf8054f8dac5448e3b394f1181207cee58f08ca911`.

The owner reported **28,775 passed / 1,362 failed**. `user-failure-remediation/applied.json` records 17 source corrections: Balancer buffer unit conversions and exact conservation assertions; Orbital sequential SE-state zap planning; V3 exact-out inversion search; and V4 funded-claim, opening-price, per-route gate, donation-size and decimal-dust fixtures. The pre-edit warm diagnostic reproduced seven failures and one passing control in six suites. The final code-generation checks passed for 12 production contracts/libraries and nine representative test containers (237 methods); all 12 production runtimes fit EIP-170. These are **not post-fix runtime results**.

No Forge process is active from this remediation. The earlier PTY 79172 runner/compiler exited without a captured completion record; its stale RUNNING state is preserved and reconciled in `user-failure-remediation/previous-sequence-status.json`. The owner's footer is separate evidence. The owner-run complete build/test is next:

```sh
python3 implementation-artifacts/detf-funded-staking/run-current-repository-checks.py --label user-failure-remediation
```

Do not award runtime, gas, full-suite or release acceptance from the compiler diagnostics. D60 Balancer-hosted DETF failures remain reported, and D66 unfinished Slipstream remains deferred.

Both narrowed Balancer builds passed, but each runtime stopped in artifact lookup during setup: 61 pass, 154 failed setup cases, 149 incomplete suites, 1,381 expected methods. The second build took 4,395.846 seconds and runtime 29.258 seconds. These are not accepted functional results. The first diagnostic identifies ERC20Facet; the second generic lookup failure was not retraced. The normal complete source graph now supplies all production artifacts. The prepared 52-source provider precheck was not executed; the active unfiltered run covers every provider and Balancer SE suite.

The latest policy/cleanup selection passes **all 438 methods**, with zero failures/skips and no incomplete suites. Build: 1,185.534 seconds; runtime: 220.246 seconds. Evidence: `hermetic-remediation-v4-policy-public-market-split.json`. It clears every failure in the prior gold batch, including the dual-hook artifact lookup and all native/decimal gate cases. All 102 dedicated unused-ledger cleanup anchors pass. Public swaps use actual user payments and current native reserve proportions; all seven production-provider pair-specific test methods are preserved through a shared helper. A separate 21-method provider code-generation check also passes; it is not runtime acceptance.

The preceding full gold selection reported 897 pass / 37 fail across 934 methods. Its first follow-up reported 421 pass / 17 fail across 438 methods; the next compile identified and resolved test-helper stack depth without compiler-setting changes. All original evidence remains preserved.

All **136 package/proxy/staged initialization cases pass** after a fresh 1,096-file build (188.089 seconds); runtime 15.67 seconds. Temporary aggregate imports are namespaced to avoid duplicate interface names. Evidence: `hermetic-remediation-surfaces-isolated-imports.json`.

All **112 Stata cases in six suites pass**, after a fresh 575-file build (112.56 seconds); runtime was 5.69 seconds. Evidence: `hermetic-remediation-stata-first-runtime.json`.

## Completed full-run checkpoint

The prior `96d7a3ff1d5d6d8f41f1ff0c7a8dd09419e8243b669dd27700325822edf63dde` snapshot finished the full build, 294 maintained scripts, unfiltered hermetic suite and exact baseline attribution. Build: 20,057.124 seconds. Test command: 4,842.791 seconds; **19,858 pass / 7,973 fail / zero skipped / 2,699 suites**. Failures: 7,124 in-scope DETF, 212 shared/other, 637 D60-excluded Balancer DETF. Matching baseline failures are not in-scope waivers.

All full-run evidence and checked before sources are preserved in `hermetic-followups-before-validation-remediation/`. No additional in-scope failure group appeared after the partial-run preparation review.

## Applied remediation

`hermetic-followups-validation-remediation-applied.json` records **79 existing sources / 12 checked batches**, applied after the entire full-run parent and diagnostics exited. These include:

- The Stata zero-supply exact-output guard and real route, fee, aToken and reward fixtures.
- Exact V3 pool seeding, real two-token activation across CP/Quad/Weighted/Orbital providers, and actual token/decimal bindings.
- Current package, proxy-selector and staged initialization expectations.
- Balancer SE native-token units, real-package smoke consolidation, rate units and stable walking fixtures.
- Funded lifecycle purchase amounts, state-based policy triggers and actual short-payment delta checks.
- Two Orbital donation overrides consolidated into inherited real-payment tests, removing fabricated DETF balances without changing executed method counts.
- Both retained V3 fork migrations, preserving seven direct cases plus inherited Base sanity.

All retired local declarations have source mappings. Prior compiler diagnostics include 176 policy/donation/short-payment methods, 69 Balancer SE methods and eight retained V3 fork cases generating bytecode. Diagnostics do not establish runtime acceptance.

## Remaining execution

A repo-wide import audit found the old common NFT ledger is dead, correcting its earlier compatibility label. `obsolete-common-ledger-cleanup-applied.json` records removal of six unused implementation/lifecycle files and 17 storage members, with seven obsolete test declarations mapped. The 16-source cleanup was applied after the gold parent exited and a 102-method compiler check passed. All 102 dedicated cleanup anchors passed in the completed policy batch. Final matching full validation remains. Keep the legacy interfaces required by excluded families.

1. Run the owner-managed normal full-source build/test/attribution sequence above and resolve actual in-scope failures. The complete unfiltered suite replaces the unexecuted narrowed provider precheck without reducing coverage. See `remaining-validation-sequence-consolidation.json`.
2. Execute the eight retained Base/Robinhood V3 fork cases with complete production compile roots and the current full-build artifacts. The prepared runner now uses normal production/script roots, requires the completed full sequence and matching successful build, and seeds its separate cache from that full build.
3. Recheck any actual runtime corrections under a matching complete build and preserve full-run attribution. Do not use the historical post-position parent with its old source assertion.
4. Deploy current packages and run all 39 strict local Robinhood lifecycle cases. The visible rehearsal node/core at port 18663 use chain4663, block56,118,361, EIP-17024,576 bytes and gas32M. Preserve unrelated nodes and use the maintained local script; no public deployment.
5. Reconcile final source/storage/selector/ABI/caller manifests, executed suite counts, consolidation mappings and timings. Close the PRD acceptance matrix, plan stages and review report only from complete evidence.

Earlier actual provider, position, gas, frontend and SVG checkpoints remain in the plan/queue and `execution-history-before-hermetic-followups.md`. Selected counts overlap and are not a full-plan total. No owner decision is pending.
