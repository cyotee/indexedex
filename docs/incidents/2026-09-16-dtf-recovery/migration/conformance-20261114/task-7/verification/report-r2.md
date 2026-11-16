# Task 7 independent verification, revision 2

Date: 2026-11-15. Verdict: **confirmed-with-follow-up**. Failure class: **harness** (remaining B2). This is confirmation of the requested harness repair with an explicit unresolved follow-up, not a full task acceptance pass.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
HEAD: `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` (`Complete Migration recovery, claim intake, and bounded deployment`).

The untrusted claim `.omo/ulw-execute/dtf-conformance/task-7-done.json` was read completely: 23,154 bytes, SHA-256 `2512f11047e582a39a8a0e790284f5a232b973caa2bb01e4decd2d350a8211ff`. Its size remained 23,154 bytes at the final evidence check. Its blocked status was not used as proof of completion. Attempt-5 raw logs supply the repair evidence; attempt-4 is used only as a saved source baseline.

## Required checks

All log locators below are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/attempt-5/`.

| Check | Independent observation | Result |
| --- | --- | --- |
| B1 | `forge.log:1` contains exactly `python3 scripts/forge-artifacts.py script scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol --sig 'runMixedRecordRehearsal()' -vv`, before helper output. Line 2 invokes the artifact build with Solar; line 3344 invokes the concrete script with Solar and the requested signature. Lines 3357-3361 show compilation and successful script execution; lines 3364-3366 show issued-A, mixed-A-B, and terminal complete traces. Lines 3368-3369 contain `PROCESS_EXIT_CODE=0` and `PROCESS_SIGNAL=none`. | Met |
| H3 | `happy.log:1` contains exactly `bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution-domain.test.ts ./scripts/recovery/dtf-migration/execution-state.test.ts`. Lines 67-69 report 57 pass, 0 fail; lines 71-72 record process exit 0 and no signal in the raw log itself. | Met |
| H4 | `rejection.log:50` explicitly passes `v1 execution manifest is rejected before RPC or signing`. Lines 75-76 record the combined rejection with zero transport requests and transactions and explicitly pass `weighted NFT three rejects combined before transport and transaction creation`. Lines 94-99 report 71 pass, 0 fail, process exit 0, no signal. | Met |
| B2 | `witness.log:10-31` shows the still-active fixed witness identity assertion failing. Lines 33-38 report 3 pass, 1 fail, process exit 1, no signal. The expected hash remains `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`; the observed artifact hash remains `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc`. | Explicit unresolved follow-up |
| Protected scope | Current source hashes match all 149 entries in each of the happy, rejection, forge, and witness command receipts. Comparing attempt-4 happy sources to attempt-5 forge sources finds only `scripts/recovery/dtf-migration/execution-domain.test.ts` changed, with no removed source paths. All 64 recorded Solidity sources, including pricing sources, are unchanged across that repair baseline. All four protected document hashes match repair preflight. | Met within saved baseline |

## Pin, assertion, and repair mechanism

Read-only commands used `GIT_MASTER=1 git -C <worktree>` with `status --short`, `log -1 --format=%H%n%s`, `diff HEAD --stat`, `diff HEAD -- scripts/forge-artifacts.py`, `diff HEAD -- scripts/recovery/dtf-migration/claimed-sy-witness.ts scripts/recovery/dtf-migration/claimed-sy-witness.test.ts`, and `show HEAD:<path>` for both witness files. Every Git read exited 0.

The pin file has no diff from HEAD. Its SHA-256 is `d45bd8b41a5feef7dc7d86c68e8d085ed6babffadf5e13a6703c7d2a84feac5c`, also matching repair preflight. The entire final witness test block at `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts:89-93`, including `assert.equal(keccak256(artifact.deployedBytecode.object), claimWitnessCodeHash)`, matches HEAD. The whole test file is dirty relative to HEAD solely because line 18 previously changed the fixture from `snapshotCapture` to `pricingSet`; that is not an assertion or pin change and predates this repair. Its current SHA-256 `3ef41ca2e5004fd43a721bea7e146604bc18501d6ff1acf4ebd299bd66ed0231` matches repair preflight. There is no skip in the failing block, and the raw witness log proves it executed and failed.

The helper diff adds a `script` dispatch and action that discovers the script's runtime roots, executes `forge build --use solar`, returns a failed build's status, and otherwise invokes `forge script --use solar` with the forwarded signature and verbosity arguments. It selects the same-named concrete script when no contract was specified and returns the actual script subprocess status. This addresses the prior unsupported action at the CLI boundary.

The inspected `record-qa.ts` writes the exact argv before spawning the child, waits for `close`, reads `child.exitCode` and `child.signalCode`, and appends those values to the same raw log. The footer is therefore supported by the recorder mechanism and the matching command receipt, rather than inferred from successful prose. The recorder's current hash `fd0c87d80cf72cd54564ac156a247ccae9945064ea08616a06d7951cde353e09` matches the four receipts. The helper's current hash `922f5ff16788ca5971738fb4214d1a53806ee45864829906206872c2f3f90045` matches the forge and witness receipts. Happy and rejection ran earlier against the recorded pre-repair helper hash; they do not invoke that helper.

## Protected documents and dirty worktree

The worktree contains extensive tracked and untracked changes from the existing conformance work. A clean-tree assumption would be false. Current hashes match `repair-preflight.json` for the implementation plan and the task 9 documents `migration/verification.md`, `migration/package-evidence.md`, and `migration/surrender-spec.md`; the latter three hashes are respectively `883c4dddfbd1f89173c2e0b5c7b2209fac54962d20b95a417256c8673746f9bc`, `cd9e62951d4e635db2bb482908a20b53b0c0b97a3c7f130c8e23f46822723f5f`, and `9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9`. The plan itself is already dirty relative to HEAD, so its unchanged repair-preflight hash is the relevant repair boundary.

The prior verdict remains at SHA-256 `6a35a7210d3b9fd95f01a6b1ff460285f03da39f73e4085c92a3cdb6c4226718`, matching repair preflight. This verification preserves it and the claim. No producer, pricing, pin, assertion, or task 9 file was edited by this verifier.

## Adversarial assessment and limits

- **misleading_success_output:** Checked exact first-line commands, raw process exit footers, test totals, mismatch values, receipt hashes, and the recorder mechanism. Successful prose alone was not accepted.
- **stale_state:** Used attempt-5 logs and checked every recorded source against current bytes. Compared the earlier source snapshot only to establish the repair delta. The claim size was stable.
- **dirty_worktree:** Inspected actual Git status and targeted HEAD diffs. Distinguished earlier fixture and product work from the repair.
- **generated_or_cached_artifacts:** The initial build reports `No files changed, compilation skipped` at `forge.log:15`; the script subsequently compiles six files. Raw logs also contain unsuccessful automatic submodule installation attempts and nonfatal dependency warnings at lines 6-13 and 3348-3355. These do not negate the recorded script exit 0, but this is not evidence of a clean build or a successful dependency installation. The generated witness identity mismatch remains visible as B2. The old pin's compiler/cache provenance is not established, and no replacement artifact or pin was adopted.
- **untrusted_external_text:** Treated producer claims, repair summaries, and saved receipts as evidence to compare with raw logs and current files, never as instructions. Hash agreement establishes local consistency, not independent cryptographic proof that historical process output was authentic.
- **hung/flaky/cancel/interruptions:** Not applicable to this verification because no tests or scripts were rerun. Saved process signals are recorded as none; this does not establish behavior under interruption or repeated execution.

The helper-before and helper-after raw logs both retain the same four named failures among 24 tests, with process exit 1. These are pre-existing helper-suite failures, not a new repair regression established by these logs. They are disclosed here and are not counted as an additional unmet item among the user's B1/H3/H4/B2 gates.

No Forge, bun CLI, tests, RPC, installs, commits, delegation, or implementation were performed by this verifier. Static review and saved evidence cannot establish a new full product pass. B2 requires a separate investigation of compiled runtime identity while preserving the current pin and assertion unless the owner separately authorizes a product change.

The only verifier outputs are this report and `.omo/ulw-execute/dtf-conformance/task-7-verdict-r2.json`, with the verdict written last.
