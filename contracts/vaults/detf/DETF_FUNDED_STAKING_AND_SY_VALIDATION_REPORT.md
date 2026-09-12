# Funded DETF staking and SY — final implementation review

**Release status: the exact candidate satisfies the plan’s in-scope production-readiness criteria.** Public deployment and migration were not performed or authorized.

## Final execution record — 2026-09-11 UTC

The exact candidate has passed all required implementation and validation work. Local source/configuration SHA: `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe`; Crane source/configuration SHA: `b45a057611f782040ee29f1fddbbcc8eeba01def2c9341ef01c6bb65f685e123`. The dirty Crane authorization patch is part of this candidate. Git HEAD alone does not identify it.

| Required evidence | Final result | Record under `implementation-artifacts/detf-funded-staking/` |
| --- | --- | --- |
| Complete build, including all 294 maintained scripts | PASS; 8,552.311 seconds; Solc 0.8.35, optimizer 1, no viaIR | `implementation-full-build.json` |
| Full unfiltered default suite | **31,312 passed / 0 failed / 0 skipped; 2,696 suites**; 785.228 command seconds (762.11 Forge seconds) | `implementation-hermetic-test.json` |
| Security and direct dust regressions | 27 existing plus seven PR-09/10 cases passed; these overlap the full suite | `production-readiness/corrected-candidate-regressions.json`, `production-readiness/lifecycle-production-regressions.json` |
| Pinned external-provider and retained V3 forks | 27 + eight passed; reused only through 423 verified unchanged compiler dependencies | `production-readiness/provider-renewal-core-final/run.json`, `v3-retained-live-pool-production-readiness-run.json`, `production-readiness/lifecycle-fork-evidence-reuse.json` |
| Fresh strict local architecture | All 19 onchain stages and isolated export passed; 156 successful receipts | `current-robinhood-rehearsal-production-readiness-lifecycle-fixed/architecture-run.json`, `current-robinhood-rehearsal-production-readiness-lifecycle-fixed/receipt-manifest.json` |
| Strict local lifecycle | **39 passed / 0 failed / 0 skipped**; unchanged 30M money-path bounds; 661.434 seconds | `current-robinhood-rehearsal-production-readiness-lifecycle-fixed/lifecycle-run.json` |
| Final artifacts, payloads, storage and installed code | 138 components, 30 release packages, 20 actual local registrations, 135 receipt-bound CREATE3 inputs, 64 storage fields; all reconciled | `production-readiness/final-static-renewal.json` and its six linked records |
| Callers and presentation | 28 ABI declarations compatible; unchanged lint/typecheck and 410 tests / 59 files reused; eight matching SVG fixtures | `production-readiness/frontend-abi-reconciliation.json`, `production-readiness/frontend-check.json`, `production-readiness/renderer-evidence-reuse.json` |
| Acceptance and security | 40 applicable criteria complete; A33/D60 excluded; A42/D66 deferral verified; all ten findings resolved | `acceptance-progress.json`, `production-readiness/security-findings.json` |
| Complete isolated funding simulation | 156 transactions; 747,456,930 summed gas limits; 0.0817942118499 ETH quote / 0.102242764812375 ETH with 25% buffer | `current-robinhood-rehearsal-production-readiness-funding/funding-quote.json` |

The final local release uses `http://127.0.0.1:18665`, chain 4663, upstream pin 56,118,361, Prague rules, 24,576-byte runtime limits and 32M-gas blocks. The corrected core is `0xd41305e8ba283b1043e78f0cfc506557f2c69df1`. Actual transactions used 528,256,469 gas in total; the largest transaction gas limit was 12,038,566 and largest gas usage 8,917,457. All receipts, actual installed cuts, recursive library runtimes, constructor payloads and salt/address calculations reconcile to the candidate. Funding ran on separate node 18664 and preserved the completed architecture head. The quote finished at 2026-09-11T12:44:59Z and is a point-in-time simulation, not a future fee guarantee.

The vulnerable pinned public core `0xD7786b10BC8Bc97dc7651CAb7B97086c8b227882` is **ineligible for this release**. The source correction does not repair existing deployed bytecode. Application network/address bindings were preserved through isolated exports; the conditional new-browser-transaction gate was not triggered, and no new browser money-path pass is claimed.

Current acceptance is tied to the [final release manifest](../../../implementation-artifacts/detf-funded-staking/production-readiness/release-manifest.json). The [public deployment runbook](../../../implementation-artifacts/detf-funded-staking/production-readiness/PUBLIC_DEPLOYMENT_RUNBOOK.md) records future operator configuration, fee/salt/core checks and replacement procedures for immutable instances. Public deployment, customer activation, publication, migration and independent audit commissioning remain separate actions. This internal review is not an independent external audit.

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

## Historical validation checkpoints

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

These checkpoints predate the final release validation above. The final post-Forge manifest independently reconciles all 138 current release components and their compiler source closures, linking and EIP-170 sizes, together with actual installed local runtime and proxy cuts.

## Test consolidation and performance

The initial 45-source position fixture migration maps 349 declarations to 345, with explicit replacement coverage and no unmapped retirement. The subsequent nine-source runtime corrections preserve declaration counts and every decimal leaf. V4 decimal imports now use the actual vendored PositionManager instead of a non-funding test double; E1 conservation redeems every attacker share instead of requesting one output unit.

The current comparison reuses the archived source descriptions/hashes for immutable baseline `e08b415733e729471779dcb8102529631330ea16`, because its original worktree and Git object are no longer available. It validates the exact baseline commit and all 3,112 required paths, then recomputes the current side. Across those files, 1,637 are unchanged, 979 updated, 474 removed/moved and 22 added. The archive path and SHA-256 are recorded in `current-test-consolidation.json`; this is evidence reuse, not a fresh read of unavailable Git blobs. These totals include preserved unrelated changes and excluded families; they are not a task-specific change count. The supplemental retirement map covers 493 declarations in 77 sources, and every in-scope removed declaration has a consolidation record. These source counts do not replace executable inherited-case counts or runtime evidence.

The current compiled default inventory is **2,696 concrete test contracts / 31,312 methods**, versus the independent baseline's 3,073 / 36,563. All 31,312 current cases executed and passed. In-scope/shared methods decreased from 29,085 to 27,558 while their concrete contract count increased from 2,090 to 2,127. The preserved D60 inventory is 540 contracts / 3,489 methods and D66 is 29 / 265. The current test artifact inventory totals 6,081,710,590 bytes; these counts include existing workspace changes and are not attributed solely to this readiness task. `current-test-consolidation.json` has zero unmapped retired declarations, with the seven PR-09/10 additions separately verified in `production-readiness/lifecycle-test-additions.json`. All 39 local lifecycle declarations remain present.

The complete current build took **8,552.311 seconds** and the unfiltered test command **785.228 seconds** (762.11 seconds reported by Forge). The previous candidate's complete build/test commands took 27,719.527 / 1,042.441 seconds. Different snapshots, cache states and scope prevent a controlled full-suite timing comparison. The identical 14-case comparison passes before and after with reduced setup EVM gas in two cases but higher command wall time. The attempted provider-cache seed did not eliminate compilation. **No full-suite speedup is claimed.**

## Acceptance and limitations

The [acceptance matrix](../../../implementation-artifacts/detf-funded-staking/acceptance-progress.json) closes all 40 applicable criteria against current named tests and their separate package, storage, security, caller and local-runtime evidence. A33 remains excluded by D60; A42 records the verified D66 deferral. The parent stages and readiness checkboxes are reconciled against those criteria. No in-scope blocker remains.

All ten findings have production or tooling dispositions in [security-findings.json](../../../implementation-artifacts/detf-funded-staking/production-readiness/security-findings.json). PR-01/02 protect final payout and payable dust; PR-04 guards canonical registry writes; PR-09 terminates already-unmintable nested V3/V4 retries; PR-10 uses full-precision Orbital NAV arithmetic. LC-01 is an explicitly funded fixture prerequisite, not a production economics change. Direct one-unit/first-payable/last-unpayable and retained-counterexample regressions remain separate from constructive `bound()` fuzzing. The 30M lifecycle call bounds and default fuzz/invariant settings were preserved.

The owner's all-tests-pass report retains its own provenance in [P0_BASELINE.md](../../../implementation-artifacts/detf-funded-staking/production-readiness/P0_BASELINE.md); its missing logs/build fingerprint were not invented. New production changes received a separate matching agent-executed build and full run. Matching provider, frontend and presentation evidence was reused only with explicit source evidence. Historical failed processes remain failed records.

The immutable comparison baseline is `e08b415733e729471779dcb8102529631330ea16`. Passing finite tests is not a universal proof of gas bounds or external behavior. The internal source review is not an independent external audit. Readiness applies only to the exact source/configuration/dependency/artifact snapshot and listed packages. Any public deployment, later customer market configuration/activation, frontend publication or fund transition requires its own authorized operation and updated chain/fee checks described in the runbook. No excluded product is approved by this report.
