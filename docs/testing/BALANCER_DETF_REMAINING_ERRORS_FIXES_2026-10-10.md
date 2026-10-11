# Balancer DETF remaining-error fixes — 2026-10-10

## Authorization and scope

The owner explicitly authorized the fixes proposed in [the diagnosis](BALANCER_DETF_REMAINING_ERRORS_DIAGNOSIS_2026-10-10.md). This pass covers the 17 previously deferred failures. It changes one production facet and five test sources.

## Implemented

- Composed stable exact-output execution validates supported input/output routes before funding. Unsupported routes revert `InvalidRoute(input, output)`.
- Reserve-dependent execution requires initialization before pricing or funding and reverts `ReservePoolNotInitialized` while inactive.
- A positive-output request with a remaining zero-input quote reverts `ExchangeOutNotAvailable` before funding.
- Direct DETF/staked-DETF conversions keep their 1:1 behavior and bypass reserve liveness. Positive-amount and deadline checks retain precedence.
- Fifteen preview assertions now require exact zero for unsupported routes or inactive reserves. The mixed and weighted route cases also require explicit execution rejection under both funding flags and unchanged custody/supply.
- Composed preview tests cover invalid tokens before and after activation. Execution regressions cover both funding flags, no transferFrom call before rejection, and unchanged balances/supply. Direct staking round trips verify exact quote/payment equality under pull and prepaid funding; preactivation tests prove these routes still reach funding validation.

No pool pricing, decimal conversion, public selectors, storage layout, or reserve exact-output capabilities were changed.

## Validation status

All **17 requested failures are fixed and verified**. The complete affected-suite run finished successfully: **875 tests passed / 0 failures across 87 suites**.

The composed invariant campaign passes with 256 runs, depth 64, and fail-on-revert. Recorded results: invariant_accounting() (runs: 256, calls: 16384, reverts: 0).

Five additional composed exact-output regression tests pass. The run includes valid reserve-exit quote/payment tests, direct staking conversions under both funding flags, the native matrix, all eight weighted decimal variants, and composed deployment, routing, custody, adversarial, decimal, and invariant suites. This is affected-suite validation, not a fresh whole-repository run.

The two original composed execution failures reproduced before changes. The production build succeeds. The updated facet runtime is 21,174 bytes, below the 24,576-byte deployment limit.

## Evidence and resume

- `.scratch/balancer-detf-fixes-2026-10-10/before.log`: two original execution errors reproduced.
- `.scratch/balancer-detf-fixes-2026-10-10/after.log`: complete affected-suite run, exit 0.
- Matching `*-command.json` files record exact artifact-first commands; the after run includes the mixed route base/native matrix, all nine weighted mint/burn suites, and the entire composed stable test subtree.
- `changes.json`, `changes.diff`, and `before/`: isolated source changes, hashes and before snapshots.
- `requested-cases.json`: maps all 17 original names to their current tests (four preview tests were renamed).
- `runtime.json`: compiled facet size.
- `STATUS.md`: final handoff; no active task process.
- [Durable per-test evidence](BALANCER_DETF_REMAINING_ERRORS_EVIDENCE_2026-10-10.json): all results, original-to-current test names, source and log hashes, commands, and runtime size.

No changes committed, pushed or deployed. No unresolved failures remain from the supplied 17-case list.
