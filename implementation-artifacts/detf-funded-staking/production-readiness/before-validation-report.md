# Funded DETF staking and SY — implementation review

**Release status: validation in progress.** This report covers the owner-authorized [implementation plan](./DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) and [alignment PRD D32–D66](./DETF_ALIGNMENT_PRD.md). It is not a release approval or a production deployment record.

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

The current source comparison reads the immutable baseline Git blobs directly. Across its 3,112 inventoried files, 1,679 are unchanged, 937 updated, 474 removed/moved and 22 added. These totals include preserved unrelated changes and excluded families; they are not a task-specific change count. The supplemental retirement map covers 493 declarations in 77 sources, and every in-scope removed declaration has a consolidation record. These source counts do not replace executable inherited-case counts or runtime evidence.

The compiled inventory checkpoint is 2,699 concrete test contracts / 31,239 methods versus the independent baseline's 3,073 / 36,563. In-scope/shared methods decrease from 29,085 to 27,529; excluded/deferred families are accounted separately. These inventories await final artifact reconciliation. Artifact bytes increased. The identical 14-case comparison passes before and after with reduced setup EVM gas in two cases but higher command wall time. The attempted provider-cache seed did not eliminate compilation. **No full-suite speedup is claimed.**

## Remaining acceptance

The active source/configuration fingerprint is `8b95fa9d3b840eee0885c252c2c8a20e62a596a5ea9be110235c634e0195a295`. The preceding full run completed and attributed all failures: 7,124 in-scope DETF, 212 shared/other and 637 D60-excluded Balancer DETF failures. No additional in-scope failure group appeared after the prepared partial-run review. The checked 79-source correction is applied with visible before copies and complete original validation in `hermetic-followups-before-validation-remediation/`. The Stata zero-share withdrawal guard and actual route/fee/reward fixtures pass all 112 selected cases after a fresh build. All 136 package/proxy/staged initialization cases pass. All 438 methods in the current policy/cleanup follow-up pass, including all 102 dedicated cleanup anchors. Build took 1,185.534 seconds and runtime 220.246 seconds. Both narrowed Balancer SE builds passed, but runtime artifact lookup failed during setup (61 passes, 154 setup failures and 149 incomplete suites each). The second 933-file build took 4,395.846 seconds; tests took 29.258 seconds. The prepared provider precheck was not executed. A normal complete production/default-test build including maintained scripts and the unfiltered suite is now active under `current-repository-funded-final-sequence.json`, recompiling 1,843 files. It covers all Balancer SE and provider cases and performs exact scope/baseline attribution. Prior full evidence is archived in `before-current-repository-funded-final/`; no release coverage was removed. Six verified unused common ledger/lifecycle files and 17 storage members were removed under the explicit approval; `current-implementation-queue.json` records the remaining groups. See `hermetic-followups-validation-remediation-applied.json` and the individual consolidation records.

Required before completion:

1. Validate the applied corrections, resolve all in-scope failures, complete a new matching full build/hermetic run, and attribute unrelated/excluded results against the immutable baseline.
2. Run the two applied V3 fork fixture migrations: all seven retained declarations plus inherited Base sanity. The actual Base and Robinhood pools exist at the pinned blocks; this read-only preflight is not runtime acceptance.
3. Deploy current packages on the strict local Robinhood fork and pass all 39 lifecycle cases with the approved liquidity policies and real provider composition.
4. Reconcile final selectors, storage, ABIs, deployment wiring, test counts and measured timings against the complete acceptance matrix.
5. Replace this pending status with the actual final results and remaining practical limitations.

The immutable baseline is `e08b415733e729471779dcb8102529631330ea16`: 30,056 passed / 3,632 failed with the recorded misplaced-network-source exclusions. Matching an old failure does not waive an in-scope requirement. The local Robinhood node uses EIP-170 and a 32M block gas limit. Finite fuzz coverage does not prove a universal gas bound.

Current evidence and remaining work are tracked in [acceptance progress](../../../implementation-artifacts/detf-funded-staking/acceptance-progress.json), `current-implementation-queue.json`, and `execution-status.md`. The historical full-run sequence remains in `final-provider-repository-post-position-sequence.json`; `run-current-repository-checks.py --label funded-final` has archived the preceding evidence and is running the current complete build/test/attribution cycle.
