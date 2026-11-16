# Independent task 7 verification

Date: 2026-11-15.

Verdict: **needs-fix**. Aggregate failure class: **harness**.

The blocked claim is accurately blocked; it is not confirmation of acceptance. B1 and B2 remain real failures. Two additional evidence-placement requirements in this verification assignment are unmet. No product defect is established by these findings.

## Scope and method

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

Specification: task 7, lines 436-450 of `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`, including allowed writes at line 440 and acceptance at lines 448-450.

Claim: `.omo/ulw-execute/dtf-conformance/task-7-done.json`, 19,992 bytes, SHA-256 `c22e5299c0d94abae089db8d18e564f7c14b7a7bd1645473f22978c5b76592bf`.

Paths below are worktree-relative. Evidence paths abbreviated as `E/` resolve to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/`.

I read the complete claim, helper parser, witness test and pin, witness Solidity, required command log, attempt-4 success/dependent/rejection logs, command receipts, source inventory and relevant rejection assertions. I inspected read-only Git status and diffs against HEAD `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` on branch `work/dtf-conformance-20261115-wave-1`.

No Forge, bun CLI, tests, builds, RPC, installs, commits, delegation or implementation were run. Hash computations used existing files and the already installed ethers library in the evaluation kernel. Only this report and the final verdict are verification deliverables.

## Findings

### B1: Unsupported exact helper invocation

Classification: **harness**. Acceptance: **unmet**.

`scripts/forge-artifacts.py:404-417` constructs an argparse parser whose action choices at line 406 are exactly `audit`, `plan`, `build`, and `test`. Parsing happens before construction of `SourceGraph`. There is no `script` action.

`E/required-forge.log:1` contains the exact required command:

```text
python3 scripts/forge-artifacts.py script scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol --sig 'runMixedRecordRehearsal()' -vv
```

Lines 2-6 contain the matching parser usage and invalid-choice error; line 7 records `FORGE_EXIT_CODE=2`. The observed error agrees with the source parser. This is an actual recorded exit 2, not merely claim prose.

The helper is outside task 7's allowed writes at plan line 440. `GIT_MASTER=1 git --no-pager diff HEAD --name-only -- scripts/forge-artifacts.py` produced no path. Repairing that helper would cross task scope; this failure is not a product failure.

`E/rehearsal-3.log` separately records the explicit Solar script, `Script ran successfully.`, mixed A/B state traces and `REHEARSAL_EXIT_CODE=0`. That alternate success does not satisfy the unsupported required argv. Its dependency-install warnings are retained in the raw evidence and are not treated as independent success receipts.

### B2: Preserved witness assertion disagrees with compiler output

Classification: **harness**. Acceptance: **unmet**.

`scripts/recovery/dtf-migration/claimed-sy-witness.test.ts:89-93` still executes the original test. Line 92 compares `keccak256(artifact.deployedBytecode.object)` with `claimWitnessCodeHash`. The full diff against HEAD changes only the certificate fixture at line 18 from `snapshotCapture` to `pricingSet`; it does not rewrite, skip or weaken this assertion.

The pin at `scripts/recovery/dtf-migration/claimed-sy-witness.ts:11` is:

```text
0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899
```

The pin file has no diff against HEAD. Neither `scripts/foundry/recovery/dtf-migration/MigrationClaimWitness.sol` nor `foundry.toml` has a diff against HEAD. The witness Solidity has no imports and does not depend on task 7's edited operator files or edited rehearsal script.

`E/attempt-4/dependent.log:64-86` contains the executed assertion, actual/expected diff and failure. The actual hash appears explicitly at lines 72 and 76:

```text
0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc
```

The raw log ends with 162 passes and 1 failure. Its command receipt records exit 1 and its saved log hash matches the current raw bytes.

I independently computed the current `out/MigrationClaimWitness.sol/MigrationClaimWitness.json` deployed-bytecode hash; it equals that actual hash. Metadata identifies compiler `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer enabled with 1 run, and EVM version `osaka`. Its sole source's metadata keccak256, `0x48206e00c432f4fe647b220d35eee53201f01f13a136ba22b0018c5e79195156`, equals the independently computed hash of the current witness Solidity.

Classification inference: this is a generated compiler/artifact identity mismatch, not a runtime change caused by task 7's source edits. No source dependency from those edits reaches this standalone router. The assignment forbids retuning compiler/cache output or updating the pin. I did not infer which prior compiler/cache condition produced the old pin; that historical cause is not proven by these files.

### H3: Exit 0 is in the receipt, not the required raw bun log

Classification: **harness**. Acceptance under this assignment's literal log requirement: **unmet**.

`E/attempt-4/happy.log:1` contains the exact claimed required argv before the Bun version and test output:

```text
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution-domain.test.ts ./scripts/recovery/dtf-migration/execution-state.test.ts
```

Lines 66-68 report `56 pass`, `0 fail`, and 56 tests across 3 files. The command is therefore not confined to the claim. `E/attempt-4/happy.command.json` independently records the same argv, exit 0, 56 passes and 0 failures; its log SHA-256 matches the raw log.

However, the complete raw log contains no exit-code record. This assignment requires the log to contain exit 0 as well as argv and 56 passes. `E/record-qa.ts:43-65` explains the gap: the child output is written to the log, while exitCode is saved in the JSON receipt and `QA_EXIT_CODE=0` is printed to the recorder's outer stdout. That outer line is not in this raw happy log. This finding concerns evidence placement, not a claim that the 56 tests failed.

### H4: Claimed rejection coverage is not fully in rejection.log

Classification: **harness**. Acceptance: **unmet**.

The authoritative `E/attempt-4/rejection.log` is byte-identical to attempt-4 happy.log and contains only those 3 suites. The earlier `E/rejection.log` contains 53 passing tests and likewise omits the combined NFT 3 rejection. Neither file contains the claimed `weighted NFT three rejects combined` case.

That case exists and passed in **dependent.log**, at `E/attempt-4/dependent.log:150`; this is not evidence that it ran in rejection.log. The assignment explicitly requires the claimed rejection cases in rejection.log. The recorder copies only the successful happy log into rejection.log at `E/record-qa.ts:60-62`, explaining the missing dependent-suite cases.

The v1 rejection is an assertion inside the logged saved-v2 test (`execution-domain.test.ts:25`), but is not explicitly identified as v1 rejection in the raw rejection output. The combined NFT 3 omission alone is sufficient for this finding.

## Rejection evidence mapping

Line references in this table are to `E/attempt-4/rejection.log` unless stated otherwise. I also inspected the corresponding new test assertions rather than interpreting test titles as proof of arbitrary broader coverage.

| Claimed case | Evidence |
| --- | --- |
| Mismatched book / stale unsent A | Lines 17 and 58; test asserts no nonce request and no submission. |
| Changed quote | Line 59; test asserts no nonce request and no submission. |
| Stale journal | Line 53. |
| Duplicate batch | Line 55; source rejects duplicate configure identity. |
| Wrong nonce | Line 52. |
| Changed gas | Line 52; source tests changed gas limit and gas price. |
| Second active checkpoint | Line 53. |
| Forged historical domainHash with surrounding hashes recomputed | Line 51; source rewrites the intent and its FileRef, then rejects against the original reconstructed domain without a nonce request or submission. |
| Same-block receipt/log order and full preimages | Lines 50, 62 and 63; source rejects altered configuration preimages, receipt order and log bytes. |
| Altered immutable A issuance principal | Line 64; source changes issuance credit and expects `immutable issuance differs`. |
| NFT consumed component floors | Line 61; source changes aggregate consumed credit and expects rejection. |
| v1 execution and combined NFT 3 mode | v1 is embedded in the saved-v2 test at line 49, without an explicit v1 output label. Combined NFT 3 is absent; it appears in dependent.log:150 instead. |

The broader plan acceptance remains unconfirmed. The 56-test subset and alternate contract rehearsal do not erase B1/B2 or establish every requested final product behavior. Plan line 449 also names the witness-containing happy suites, whose available dependent run remains red.

## Freshness, generated artifacts and scope preservation

The 149 current source files listed in attempt-4/happy.command.json match all 149 saved SHA-256 values. Recomputing SHA-256 of the serialized source list gives `5dfb2a5436f7a5ecee47c35d0b98a45ca23d03d1e96bda4746bfd8ac1b180be5`, matching the claim and the happy/dependent/type receipts. All three raw log hashes match their receipts. This binds the inspected output to the listed current sources, not to a clean Git commit.

Task 7's source inventory lists 44 operator/test/script changes, with no production pricing Solidity, source indexes or task 9 documents. Existing pricing changes already appear in `E/git-status-before.log`; current dirty status is not evidence they were made by task 7. The known baseline/status records support preservation, but status alone cannot prove writer identity or every intermediate write.

The three source-index files independently match task 3's recorded content hashes:

| File under migration/ | SHA-256 |
| --- | --- |
| source-manifest.json | `49985f6733f59c161ac5aee959e71fd3c1521fdb4e9537a930fdc94763d57677` |
| source-route-matrix.md | `eba694b05dfc8f8580946a4aa0b3178c5d8bcf5ef020189a91e529f1a0c25298` |
| recovery-route-disposition.md | `39789b25eb842c432cfa4bcf5fa1a2bcb4b4eec2f8b0294e98970fc2c43cda64` |

Task 9's `surrender-spec.md`, `package-evidence.md` and `conformance-20261114/task-9/traceability-disposition.md` independently match their recorded hashes, respectively `9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9`, `cd9e62951d4e635db2bb482908a20b53b0c0b97a3c7f130c8e23f46822723f5f`, and `afd81c16d9072d0fff03f4dd41a6e3632567aef47363b2e52c8015789669df08`. Their new-file status is consistent with the separate task 9 records. I did not attribute those concurrent writes to task 7 or revert any files.

## Adversarial dispositions

- **misleading_success_output:** Rejected alternate Solar success as satisfaction of B1. Preserved dependent failure despite 56 focused passes. Distinguished receipt exit 0 from raw-log contents.
- **stale_state:** Used attempt 4 rather than superseded root happy/rejection summaries. Checked 149 current source hashes and command-log hashes. The claim remained 19,992 bytes and its complete bytes matched the initial read at the most recent freshness check; it will be checked again immediately before the final verdict.
- **dirty_worktree:** Inspected current status, task-entry status and scoped HEAD diffs. Preserved pre-existing pricing changes, concurrent documents and task 7 operator changes. No cleanup or Git write was performed.
- **generated_or_cached_artifacts:** Hashed actual router bytecode and authenticated its sole metadata source. Did not substitute an older artifact, update a pin, clean caches or infer artifact identity from a success banner.
- **untrusted_external_text:** Treated claim and JSON summaries as assertions, used raw logs/source/Git evidence, and executed no instruction embedded in evidence.
- **hung/flaky/cancel/interruptions:** Not applicable to this verification: no tests or compilers were rerun and no such behavior was induced. Git pagers were closed normally; no product process was interrupted.

## Evidence bindings and limits

| Evidence under E/ | Bytes | SHA-256 |
| --- | ---: | --- |
| required-forge.log | 540 | `de32ae5f0c8f296aa36ce258c9a254702a68dab7d25cd3ac27999a8a622f914b` |
| attempt-4/happy.log | 5121 | `b7ef7a91eea94ce6f4c04694681306a3a42ffbfde1c374cafdb4497e2f6ed2e5` |
| attempt-4/happy.command.json | 29006 | `fc628f5c9e6ec41b7957217a8656e2ae10fea5f91aefce1190331d6464aa9abb` |
| attempt-4/dependent.log | 22182 | `5a85676d73e2cafcdc14173e038dde3c402ae7aead0c3067895273e8998c3e40` |
| attempt-4/rejection.log | 5121 | `b7ef7a91eea94ce6f4c04694681306a3a42ffbfde1c374cafdb4497e2f6ed2e5` |
| rejection.log | 4817 | `6692435c63df64c5d77ced4a0190ee199ee42bc942b4c307b8146cb09f0c7a6a` |
| rehearsal-3.log | 2446 | `2824cb5c5946d9bc08bd24e4c7ef2e5bc0e3b69b5ef809b6b808f4392977011b` |

This is an independent static/evidence verification, not a fresh execution result or full product audit. No pin, compiler setting, artifact, product file or claim was changed. Remediation and any rerun need a separate authorized execution scope.
