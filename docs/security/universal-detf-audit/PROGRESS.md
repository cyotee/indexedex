# Audit progress

Status: in progress. Owner subsequently authorized focused local fixes during review and requested concise results without vulnerability explanations.

- Captured source manifest and tracked source patches; local modifications are part of the baseline.
- Read repository/product guidance and loaded Crane/IndexedEx audit and testing skills.
- Started universal DETF entrypoint and collector review.
- Next: inspect supporting accounting, hook and deployment paths; build baseline artifacts and run focused suites.

UDETF-SEC-001: reproduced, corrected locally, and verified by 36 passing close regression tests across four hook bindings. Selected CP hook canonical initialization checks and adversarial tests strengthened; production rebuild in progress before broader verification. No deployment readiness conclusion has been established.

## Local remediation awaiting compilation and runtime verification

- CP canonical tick-spacing validation and staged initialization regressions.
- CP public swap callback shared reentrancy lock; four real PoolManager transfer-callback regressions.
- CP fee accrual before incoming capital, including exact-output preview ordering; ten fee-capital regressions.
- Shared claim exact-output balance-unit rounding; six non-unit-rate regressions.
- Shared claim live valuation, full internal-share precision on principal release, and atomic rejection of zero-share mints; five accounting regressions.
- Universal physical LP-to-original-principal conversion on bond, purchase, compound and close rejoin; four-binding regressions and CP tiny-principal cases.
- Consistent downward principal issuance, atomic rejection of unrepresentable user positions, compound reward preservation, and close dust liveness; shared NFT floor/offset regression.
- Universal five-facet split, CP three-facet deposit split, and removal of six unrouted NFT dispatch methods; routing, approval and size regressions.
- Follow-up review confirmed the single-asset CP join reconstructed raw reserves using the opposite currency's add leg in two branches. The helper now consistently subtracts the raw-currency leg; both-input/both-order regressions are being added. This change postdates the successful production build and active regression compiler, so those artifacts/results require another refresh before final validation.

The original full build completed successfully in 13,911.54 compiler seconds; its input predates the combined changes and is not final-source validation. The separate Foundry production build passed with `out_security_validation_20260905` and `cache_security_validation_20260905`: 2,331 files, 1,563.83 seconds (one Orbital unreachable-code warning). Those directories were copied from the warm directories so they could not race the original writer. No new profile or persistent Foundry configuration change was made. Source-metadata verification passed for all 14 selected artifacts and 212 unique dependency sources (`evidence/artifact-freshness-after.json`).

Isolated solc 0.8.35 compilation (optimizer 1, Prague, no IR) passed for 14 selected production components. All measured runtime sizes are below 24,576 bytes after remeasuring the NFT facet at 23,958 bytes. Evidence: `evidence/production-sizes-after.json`. ABI typechecking passed for nine selected regression files, including NFT packaging; these are compilation checks, not executed tests. The source-metadata verifier detected the intentionally stale claim artifact and will be rerun against refreshed artifacts.

Outstanding readiness items include actual factory deployment/size assertions, claim purchase preview parity, zero-supply claim bootstrap ownership policy (question pending with the owner), full regression/invariant coverage, and deployed-source reconciliation. Robinhood mainnet manager `feeTo()` was verified against the recorded collector at a pinned block. See specialist review files for bounded findings and limitations. No live deployments have been changed.

## First combined runtime checkpoint

`evidence/remediation-regressions.log`: 112 passed, 19 failed, 131 tests in 17 suites; runtime 33.88 seconds. This checkpoint predates the follow-up reserve-order and preview fixes. Shared accounting, close suites, initialization, callback-lock and packaging tests passed. Failures included invalid tiny-fixture assumptions, full custom-error matching, use of preview LP instead of actual minted LP for an accounting assertion, and post-maintenance versus mint-event balance snapshots. Those fixtures/assertions have been corrected without replacing the accounting invariants.

The six exact-output failures exposed a production wiring mismatch: D15 specifies DETF-only payment and `claimLiquidity` pays DETF, but the claim deployment advertised the first pair token. `completeReserveClaim` now configures the DETF itself, and tests assert both that configuration and actual recipient DETF credit. The initial validator-only test adjustment was reverted.

SE-share deposit preview now uses the aggregate claim delta after rounding the incoming SE shares, matching execution. The three CP deposit artifacts rebuilt successfully (seven sources, 4.49 seconds); a focused raw-growth trace is running before any further preview correction. Final combined runtime validation is still pending.

## Follow-up artifact checkpoint

The focused fee trace completed: three pass / one fail, with SE-share parity passing. Raw/pair preview overquotes one atomic LP unit because nested conversion rounding is not represented by the generic quote model. See `amm-review.md` and `evidence/fee-capital-rounding-trace.log`.

Both output trees have been refreshed after the reserve-order, SE-share preview and claim-wiring changes. The final canonical `out/` refresh passed (212 files, 48.68 seconds), followed by source verification for all 14 selected artifacts and 212 unique sources. Every selected component passes runtime and base creation-code size limits. Evidence: `artifact-freshness-final-canonical.json`, `production-sizes-final-canonical.json`. A combined 15-file regression selection is running with the narrower `--contracts contracts/utils/foundry` CLI scope; exact runtime results remain pending.

The narrowed-contracts-root runtime experiment failed all 18 suites during artifact-dependent setup and was rejected. The current run restores the normal contracts root and narrows only `FOUNDRY_TEST` through named imports of the original 15 files. Expected selection remains 18 suites / 135 tests; runtime verification is pending. The next workflow measurement will omit match filters to avoid Foundry's separate ABI discovery compile.

Seven launch-script roots passed ABI typechecking after wiring the existing foundation `multiStepOwnableFacet` into `Script_08_DeployFeeDetfPackage`'s CP package initializer. That fee-DETF package script also passed actual bytecode generation with optimizer 1 and no IR. These are compilation checks; no launch scripts were executed or broadcast. Evidence: `deployment-typecheck-after-output.json`, `fee-deployment-codegen-output.json`.

## Zero-backing correction awaiting validation

Shared claim valuation now reserves the unit-rate bootstrap for zero outstanding shares. A successful NFT conversion returning zero remains zero, and a positive-share mint that yields zero token balance reverts atomically. Two new production-fixture accounting tests establish a zero extractable DETF balance through ordinary trading, check unavailable exact-output redemption, and check mint rollback. The rollback fixture explicitly requires positive external shares before minting an amount equal to the backing denominator. These changes postdate the active 2,355-file focused compile and must be built before the next test run. The latest expected focused selection is 18 suites / 137 tests.

## Normal-root focused runtime checkpoint

`evidence/focused-harness-default-src.log`: 130 passed / 2 failed across 18 suites (132 reported cases because one four-test suite failed setup). Compiler: 2,355 sources / 2,537.91 seconds. Reported suite execution: 452.98 seconds; full command: 3,102.00 seconds. All 25 original-principal tests, six exact-output claim tests and existing accounting checks passed. The raw/pair growth preview still fails. The new reserve-order fixture failed setup with `InvalidDecimals`: it selected raw6/pair18, but HDEC requires raw18. The fixture now uses raw18/pair6, preserving unequal units and both currency orders. A matching-root build is running for that fixture and the latest zero-backing correction; the next test run will be unfiltered.

The latest matching-root build passed: six sources, 123.97 compiler seconds / 144.98 wall seconds. All 14 selected artifacts match 212 current source hashes and pass runtime/base creation size limits (`artifact-freshness-latest.json`, `production-sizes-latest.json`). The unfiltered 137-test candidate reports compilation skipped and is running; its final count and result remain pending.

## Latest completed local checkpoint

The unfiltered run completed: **136 passed / one failed / zero skipped, 137 tests in 18 suites**. Compilation was skipped after the matching-root build; suite execution was 421.42 seconds and full command wall time was 484.08 seconds. Both new zero-backing tests and all four corrected reserve-order tests passed. All selected close, initialization, callback-lock, exact-output claim, original-principal, shared NFT and packaging regressions passed. The sole failure is the retained raw/pair growth-preview minimum test. Evidence: `evidence/focused-harness-unfiltered.log`.

The latest production source hashes and size checks pass for all 14 selected artifacts and 212 dependency sources. Seven launch-script ABI checks and fee-package script code generation also passed. No build or test process from this pass remains running.

This is a completed bounded remediation checkpoint, **not production readiness or a completed audit**. Remaining work includes the exact transition-quote implementation described in `PREVIEW_REMEDIATION_DESIGN.md`, claim-purchase rebasing-balance preview parity, the unanswered ownership policy for backing accumulated before claim issuance, broader cross-family regressions/invariants, deployed-source reconciliation and gas benchmarking. The explicit narrower artifact-seed proposal remains unvalidated. No existing deployed contracts were changed.
