# Task 13 independent verification

Date: 2026-11-15. Verdict: **needs-fix**. Primary failure class: **product**. Additional evidence defects are classified **harness** below.

Task 13 cannot be confirmed. The required operator command actually exited 1 with 240 passing cases and one unchanged claimed-SY authentication assertion failure. Task 10's complete rehearsal and the dependent task 12 real lifecycle proofs are absent. The passing build, hermetic, fork and typecheck subset does not satisfy the conjunctive acceptance criterion.

This verification used local reads, hashes, JSON parsing, raw-log aggregation and read-only Git inspection. It ran no Forge, bun CLI, recorder, RPC, installation, commit or rehearsal, delegated nothing, and changed only this report and the final verdict. Loading the already installed ethers hashing module inside the resident evaluation kernel did not execute tests or a CLI.

## Scope and claim binding

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`, task 13.
Evidence paths below are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-13/` unless stated otherwise.

The untrusted `.omo/ulw-execute/dtf-conformance/task-13-done.json` was read completely and remained 8737 bytes, SHA-256 `d73967ecccfc8a498c9322464bd37e2ddc9ee4c56630aaa5efb07885ac644cbd`. Its status is incomplete and completed is false. No size change was observed. Its 63-file evidence index was independently checked against current raw bytes with zero hash mismatches.

## Findings

1. **Product: required operator authentication gate fails.** `operator-r2/04.log:88-115` contains the assertion at `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts:92`. The test hashes `out/MigrationClaimWitness.sol/MigrationClaimWitness.json` deployed bytecode and compares it directly to `claimWitnessCodeHash` at `scripts/recovery/dtf-migration/claimed-sy-witness.ts:11`. Actual: `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc`. Expected: `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`. Lines 329-331 report 240 pass, 1 fail, 241 cases across 21 files. The command sidecar records code 1, signal null; `operator-r2/results.json` records completed false. Pre-existing does not mean out of scope or accepted.

2. **Harness/lifecycle: required real-surface evidence is missing.** Sibling `task-10/funding-blocker.json` and `task-10/verification/report-r2.md` preserve an authority-bundle donor provenance block, zero transactions, and no complete rehearsal. The task-10 directory has no required rehearsal-location/runtime lifecycle records. Its recorded funded holders within the authority candidate set are excluded source contracts; retained transfer evidence outside the bound bundle contains other funded candidates. Thus this is not evidence of global DTF scarcity. Missing mixed-pricing, same-block replacement, donation identity, owner activation, NFT 3 two-bond/rollback and portable current-chain proofs remain missing. Offline export and test fixtures do not replace them.

3. **Harness: strict raw-log command provenance is incomplete.** Exact argv and exit codes for recorder commands exist in `.log.command.json` sidecars and are corroborated by recorder `CHECK_END` lines and the recorder implementation at `migration/resumed-integration/record-verification.ts:316-353`. However, the numbered build/hermetic/operator logs do not themselves contain those full invocation headers and exit receipts. The fork raw log prints expanded inner Forge commands, while the exact outer Python artifact-helper invocation is in its sidecar. Most clearly, `helper-typecheck.log` is empty; `helper-typecheck.exit.log` contains only `HELPER_TYPECHECK_EXIT=0`, and the exact helper tsc argv is supplied separately in `invocation-inventory.json`. These records support a reported check but do not meet the user's stronger requirement for exact argv and status in a raw command log. No missing raw invocation or success output was reconstructed.

4. **Harness: the claim miscopies the expected pin.** `task-13-done.json` unmet item 1 says `0x4ae06bcb278766df6529bcd60e05453fee6c8536b9f18d2a4d0dac8fd899`, omitting `f653` from the actual source/raw-log expected value above. The disposition is accurate, but this exact datum does not match the logs. The claim was left untouched.

## Observed commands and selected cases

These are recorded invocations, not commands rerun by this verifier. Shell-glob invocations are preserved exactly as the recorder's `/bin/zsh -c` argument; expanded individual filenames were not captured as child argv.

| Check | Exact recorded argv or shell command | Observed result | Raw evidence |
| --- | --- | --- | --- |
| Production build | `["forge","build","--use","solar"]` | Code 0 in sidecar; 3237 files compiled successfully | `hermetic-r2/03.log:13-15`, matching `.command.json`, recorder index 3 |
| Full hermetic | `["forge","test","--use","solar","-vv","--no-match-path","**/fork/**","--no-match-contract","Fork"]` | Code 0; 28641 passed, 0 failed, 0 skipped, 2691 suites | `hermetic-r2/04.log:64138`, matching sidecar and recorder index 4 |
| All K forks | `["python3","scripts/forge-artifacts.py","test","contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol","--test-root","test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration","--","-j","1","--compute-units-per-second","10","--rpc-timeout","120","-vv"]` | Code 0; 183 passed, 0 failed, 0 skipped, 30 suites; all 26 current K `.t.sol` files selected | `fork/03.log:5677`, matching sidecar and recorder index 3 |
| Operator types | `["/bin/zsh","-c","bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts"]` | Code 0 in sidecar and recorder index 3; no case count applies to typechecking | `operator-r2/03.log`, matching sidecar, `operator-r2-recorder.log` |
| Full operator tests | `["/bin/zsh","-c","bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts"]` | Code 1; 240 passed, 1 failed, 241 cases, 21 files | `operator-r2/04.log`, matching sidecar and recorder index 4 |

The separately reported helper typecheck is:

```text
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

Its empty stdout log and separate exit marker do not authenticate exact invocation inside the raw log. This gap is kept distinct from an observed compiler error: no such error is present.

Independently aggregating every raw `Ran ... for ...` and corresponding `Suite result` block produced:

| Raw hermetic selection | Suites | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: | ---: |
| All suites | 2691 | 28641 | 0 | 0 |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/` | 559 | 9560 | 0 | 0 |
| Weighted-named subset of that path | 103 | 2272 | 0 | 0 |
| `test/foundry/spec/vaults/detf/common/` | 30 | 372 | 0 | 0 |

Both required ordinary paths have actual nonzero suite results. A focused fallback is unnecessary. Fork aggregation separately produced 30 suites and 183 passes, with no missing current K test files. These conclusions use the raw logs, not their summary JSON alone.

## Pin preservation and generated artifacts

The earlier task-7 `dependent-acceptance.log` contains the identical actual/expected hashes and 162 pass / 1 fail. Its raw SHA-256 is `f19e6ed061a124ad15faa271fa839b82d64fad50dfa2a4bf94f2abd68d245869`. Its command receipt binds the following current, unchanged SHA-256 values:

| Source | SHA-256 |
| --- | --- |
| `scripts/recovery/dtf-migration/claimed-sy-witness.ts` | `d45bd8b41a5feef7dc7d86c68e8d085ed6babffadf5e13a6703c7d2a84feac5c` |
| `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts` | `3ef41ca2e5004fd43a721bea7e146604bc18501d6ff1acf4ebd299bd66ed0231` |
| `scripts/recovery/dtf-migration/rehearsal-claimed-sy-witness.ts` | `583558715dae13f2c405655ab18b5dd0a44b54fbd294de73472e3b8080b7c4d8` |

Read-only Git diffs also show no pin change. The witness test's dirty change is the configuration fixture migration from snapshotCapture to pricingSet, not a weakened assertion; the rehearsal certificate change follows that field rename.

The current artifact SHA-256 is `09187d4b4adcfe56a63bc0fc53501fb5d4d43598c3a43b671ad43aa8cd1400ff`. Independently hashing its deployed bytecode reproduces the failing actual hash. Metadata identifies `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer enabled, runs 1. Independently hashing the current Solidity source reproduces metadata source keccak256 `0x48206e00c432f4fe647b220d35eee53201f01f13a136ba22b0018c5e79195156`. This agrees with the retained build-artifact audit. It does not prove arbitrary cache freshness, but gives no basis to dismiss this failure as merely stale output.

No unrelated repair demonstrated in these records can turn the operator command green while preserving both current bytecode and the fixed pin: the sole failed test directly compares their unequal hashes. Producing genuinely reproducible, approved bytecode that matches the unchanged pin would be a possible investigation direction, but no such build recipe or repair is established here. Forging/replacing an artifact, skipping the assertion or retuning the pin is not a repair. Completing task 10 would not alter this equality test, and making this test pass would not supply task 10's missing receipts. Therefore no claim of an available permissible green shortcut is supported.

## Adversarial checks and limits

| Case | Result |
| --- | --- |
| misleading_success_output | No confirmation. Raw case blocks match global totals, but operator code 1 and missing lifecycle defeat the passing subset. Recorder completed false is preserved. Command-logging gaps and the claim's mistyped expected hash are explicitly reported. |
| stale_state | All 16405 regular-file entries in source-final match current hashes. All four symlink targets match their recorded strings; those existing LayerZero links are dangling and were not treated as regular source bytes. Before/final manifests have identical 16409 entries. All 63 indexed evidence files match current hashes. This is scoped content equality, not a clean-tree claim. |
| dirty_worktree | Git inspection shows extensive pre-existing tracked and untracked changes. No cleanup, staging or revert occurred. Final-tree comparisons use content hashes, not HEAD. Attribution of every historical edit is not certified. |
| generated_or_cached_artifacts | Raw build compiled 3237 files; hermetic then reports compilation skipped with unchanged sources. Actual test cases ran. Witness artifact and metadata match the recorded build audit and current source; the real hash mismatch remains. No cache was deleted and no generated success artifact was fabricated. |
| hung/flaky/cancel/interruptions | Not applicable to this verification: no suite or recorder was rerun. No new timeout, cancellation, flakiness or interruption-handling result is claimed. |

Raw Forge logs retain failed automatic submodule-bootstrap messages and compiler/lint warnings. They do not override the captured top-level code 0, nor prove successful dependency installation. Earlier hermetic/operator startup attempts are preserved and documented as failed toolchain-environment attempts, not passing tests.

No skipped cases appear in the aggregated Forge suites or operator total, and no exclusion beyond the prescribed hermetic filters appears in recorded argv. The inspected witness assertion is intact. This is not an exhaustive audit of every historical test edit. No public transaction is evidenced by these verification commands; the task-10 record explicitly reports zero transactions. No fresh public-chain state assertion is made.

The claim's unmet operator, task-10, task-12 and conjunctive-acceptance items agree with the observed failure and absent lifecycle records, subject to the pin transcription correction. This report additionally records the strict raw-log provenance gaps. Task 13 remains incomplete; implementation is not authorized by this verdict.
