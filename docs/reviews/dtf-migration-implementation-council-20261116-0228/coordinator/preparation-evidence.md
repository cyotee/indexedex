# Coordinator evidence observations

These observations support later synthesis; they are not an independent council
vote or a completion verdict. No project build or test was run by this council.

## Review target inventory

The current primary checkout contains 63 Solidity files under the Migration
implementation root (including interfaces, TestBases and invariant handlers),
28 under the hermetic Migration root, 31 under the fork Migration root, and
four retained native scripts. File presence is not code coverage or test execution.

The complete supplied plan was read. Its opening November 15 owner correction
withdraws the custom operator application and associated application recovery,
bundle and journal requirements. Later historical reports about those withdrawn
requirements do not establish a current missing deliverable.

## Source applicability of historical verification

Read the task-13 source manifest at:

`docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-13/source-final.json`

It records capture at `2026-11-15T08:26:37.539Z`, with raw SHA-256 entries.
Compared its entries to current primary-checkout bytes for these roots:

- Migration implementation and helpers.
- Shared DETF common implementation.
- Ordinary V4 DETF and bond packages.
- Weighted Standard Exchange buffer hook.
- Migration hermetic and fork tests.
- Native migration scripts.

Of 299 historical entries selected, 293 matched. Four app-only Solidity files
were absent: `MigrationClaimWitness.sol`, `MigrationDelegatedReceiverFixture.sol`,
`MigrationIndirectClaimFixture.sol`, and
`Phase_08_Stage_00_OperatorEnvironment.s.sol`. These deletions are explicitly
recorded in the owner-directed removal report.

The other two changed entries were:

| File under scripts/foundry/recovery/dtf-migration | Historical SHA-256 | Current SHA-256 |
| --- | --- | --- |
| MigrationSnapshotLocalQA.s.sol | fed50d0473f8630f0f1be9275d80b78308c2c6c843248da68bfc4d09379196e3 | d1ffb369e5f4193eda819ff2fe0116873436910eb7123b1379aa0b5a8fe5941f |
| Phase_08_Stage_01_MigrationExecution.s.sol | e0d17ccb9bcd0c943a6c0ad5ae597da3f16225d7ca4bced1b1de37eccc1bfe3e | cd9f4edefecc1b946201609211d919861caa61365ac2a2410c5be25f8d92be74 |

All current Solidity paths in the four primary target roots had entries in
that historical manifest. This comparison does not certify the entire dependency
tree, compiler configuration, compiled bytecode, or unrelated source. Hash
comparison is not semantic examination of each file.

## Newer runtime evidence

The primary-checkout report
`.omo/verification/dtf-operator-removal-20261115/REMOVAL.md:39-68`
records post-removal native compilation and test results. Its raw logs are not
in the primary checkout; the original evidence worktree retains them:

`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/.omo/verification/dtf-operator-removal-20261115/`

Directly read raw summary lines:

| Retained log | Line | Observed summary |
| --- | --- | --- |
| native-spec.log | 514 | 236 passed, 0 failed, 0 skipped; 34 suites |
| native-fork.log | 987 | 183 passed, 0 failed, 0 skipped; 30 suites |

The removal report records exit 0 for compilation and both suites. Those exit
codes are report evidence; the raw summaries above were independently read.
The report states that scripts compiled but were not broadcast, and that no
production contract behavior was edited.

The current primary-checkout record
`.omo/verification/artifact-mismatch-20261116/DIAGNOSIS.md:23-52`
describes replacing mixed-generation artifacts with one Solar generation,
successful build, 279 affected tests and a complete hermetic regression.
The actual retained raw log
`.omo/verification/artifact-mismatch-20261116/full-hermetic.log:37617`
states: 28,641 tests passed, 0 failed, 0 skipped across 2,691 suites.
The diagnosis records exit 0 and no contract/test source edits.

Older task-13 raw logs are also absent from the primary checkout but exist in
the original conformance worktree. Their endings were read at
`task-13/hermetic-r2/04.log:64125-64138` and
`task-13/fork/03.log:5668-5677`, confirming historical counts of 28,641 and 183.
The newer records above are more relevant to the retained native scope.

## Boundaries

The conformance worktree was read only for historical execution evidence.
The implementation target remains `/Users/cyotee/Projects/indexedex`.
Older operator-specific failures, bounded stops and incomplete application
rehearsals remain preserved history. They are not silently translated into
current contract defects or requirements to restore the removed application.

Passing tests support exercised behavior, not exhaustive correctness. The
council must still check current code, plan coverage, unsupported domains and
any substantive defects. No fresh public-chain observation, production
allocation approval or deployment authorization is implied.

## Checks prompted by Grok's original

The current `source-route-matrix.md:3` and
`recovery-route-disposition.md:3` do cite the prior plan fingerprint
`93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e`
and 98,213 bytes. The current plan has the preparation fingerprint recorded
in the brief and 97,559 bytes. This establishes stale governing-document
metadata. It does not alone invalidate unchanged source-route evidence.

The live runbook indeed names the conformance worktree at lines 7-10.
Direct byte comparison found both retained scripts that changed after task 13
identical between the primary checkout and that worktree, with the current
hashes in the table above. Thus a documentation portability concern is real,
but different current script contents in that worktree were not established.
The post-removal report expressly records compilation of the retained scripts.

Target-chain batch-limit selections are present at
`conformance-20261114/task-11/batch-limits.md:3-29`: a recorded 32,000,000 gas
ceiling, separate measured loading/issuance axes, and bounded recovery shapes.
The coordinator read that report and the operation table. Applicability remains
limited to measured shapes and captured sources. A reviewer's failure to locate
this evidence is not evidence that it is absent.

## Checks prompted by Kimi's original

Read the complete `MigrationCoreLocalOwner` definition at
`scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:41-82`,
`deployAndIssue` at 266-297 and `exerciseAfterCliff` at 299-344.
The contract owner exposes bind, bootstrap, independent configuration/issuance
and activation, but no ordinary bond purchase or ownership-transfer forwarding.
The deployment sequence creates that owner, donates, bootstraps and independently
issues; the after-cliff sequence calls its activation at line 320.

The invoked `_migrationEnvironment` at
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol:97-136`
only deploys/wires/funds fixture assets and approves them; it performs no paid
owner-first bond purchase. The real activation guard at
`UniswapV4DetfMigrationAllocationTarget.sol:267-268` requires the recorded
owner-first bond. The separate `runMixedRecordRehearsal` at script lines 103-180
does call `_buyOwnerFirstBond` at 171, but it constructs a different fixture and
does not repair the two-stage contract-owner sequence.

This supports a static correctness finding in the retained QA script, without
claiming a newly executed revert. The relevant plan section is 1.5; Kimi's
additional reference to section 1.11 is invalid and will not be copied.

The coordinator read all of the native transaction script. It has NFT
configuration functions at lines 69-79 but no NFT surrender call, although the
production target provides that operation. Whether that omission is a mandatory
Task 9 completion gap or a useful convenience addition requires interpretation
of Task 9's explicitly limited operation list; the final will distinguish the
missing wrapper from any claim that the production NFT route is absent.

## Checks prompted by Astra's original

Read `UniswapV4DetfMigrationAllocationTarget.sol:305-414`,
`UniswapV4DetfMigrationWeightedHookTarget.sol:327-389`, the full Migration
policy, and `MigrationCore.t.sol:43-72`. The existing real-proxy test donates
100 ether per leg and bootstraps with only 50. Bootstrap permits that shape and
then sets `isReserveLive`. Non-self leftovers remain in `donationInventory`.
Bootstrap rejects another call once live. Later `donateMigrationCapital`
releases only the newly received amounts. Policy budgets expose
`residualInventory`, not the pre-existing donation balance.

A scoped `donationInventory` search over all 63 Migration Solidity files found
mutations only in the allocation and retained donation targets. Read the common
sweep at `UniswapV4DetfCommon.sol:497-575`, ordinary donation at
`UniswapV4DetfTarget.sol:732-776`, and recovery donation at
`UniswapV4DetfMigrationRecoveryTarget.sol:441-468`. These alternatives do not
release that booked genesis remainder. This supports the stranded-capital
finding as a current-source inference; no new runtime failure is claimed.

Read the entire Migration metadata target and the shared renderer's claim
attributes. `UniswapV4DetfMigrationBondMetadataTarget.sol:30-32` derives
`rewardsClosed` only for cliff positions or reserved IDs. An ordinary paid
owner-first bond is neither, so the renderer reports accrued rewards as
claimable even before activation. The child's `_claim` at
`UniswapV4DetfMigrationBondNFTVaultTarget.sol:73-78` gates every reward request.
This supports a presentation mismatch, not a reward-payment bypass.
