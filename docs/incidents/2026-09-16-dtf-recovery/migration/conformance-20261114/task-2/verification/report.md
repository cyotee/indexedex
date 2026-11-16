# Independent task 2 verification

Verdict: **needs-fix**. Failure class: **harness**. Confidence: **high**.

The producer accurately reports blocked, acceptance_met=false. This is not completed recovery. Its bootstrap gate remains needs-fix, both required delivered programs are absent, and independent fixture invocations and the prescribed helper typecheck fail before exercising their contracts. No product behavior was changed or evaluated. Resolving bootstrap alone does not complete task 2.

## Scope and actual delivery inspection

Read CLAUDE.md, all three assistant topic rules, the complete assigned task 2 from the copied plan, task 13's helper compiler invocation, the producer's complete task-2-done.json, current ready.json, and both complete original retained helper programs. No implementation, original-source mutation, dependency change, network mode, delegation or Git write occurred.

Read-only commands, run from the assigned worktree:

```sh
GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 status --short --untracked-files=all
GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 diff -- docs/incidents/2026-09-16-dtf-recovery/migration
GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 rev-parse HEAD
```

All exited 0. The scoped tracked diff was empty (0 bytes). HEAD was c33f70683cbaabfedc2dbce1142fdd65660d4cf3. Initial full status:

```text
?? .omo/drafts/dtf-migration-conformance-remediation-20261114.md
?? .omo/drafts/hyperplan-dtf-conformance-insights-20261114.md
?? .omo/drafts/hyperplan-weighted-migration-insights-20261114.md
?? .omo/plans/dtf-migration-conformance-remediation-20261114.md
?? .omo/ulw-execute/dtf-conformance/bootstrap.md
?? .omo/ulw-execute/dtf-conformance/ready.json
?? .omo/ulw-execute/dtf-conformance/task-2-done.json
```

Direct filesystem reads returned ENOENT for each delivered helper and the task-2 evidence directory before verifier writes. There is no producer inventory, divergent-row disposition or raw acceptance output to inspect. The untracked claim was read completely; an empty tracked diff was not treated as proof of a clean worktree or successful delivery.

Raw SHA-256 bindings (computed from file buffers, without normalization):

| Input | Bytes | SHA-256 |
| --- | ---: | --- |
| .omo/ulw-execute/dtf-conformance/task-2-done.json | 4668 | 11a002c555380f1725930ec7f534dc617315013a0c56f8dbfb6ef4e4295cf7f8 |
| .omo/ulw-execute/dtf-conformance/ready.json | 4425 | e6043fc75e0b4f6dadc601339743a1492a41aaa77c6015e949329a19035a5a6d |
| .omo/plans/dtf-migration-conformance-remediation-20261114.md | 126320 | 31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683 |
| R/resumed-integration/record-verification.ts | 2914 | 8192d15ff2aa039ea4bb306393205ed3e846270c482abcfb0f46c753e7353ac7 |
| R/resumed-integration/verify-bounded-deployments.ts | 6762 | 56c8b9ad58e78f5293548c40d66c30ba426dbc2a47572762599d7836d0ced8ed |

R is /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/docs/incidents/2026-09-16-dtf-recovery/migration. Neither original has a delivered counterpart to compare. Thus the two required programs already disprove complete retained-byte delivery. This is not a complete census of all retained candidates, and no such census is claimed.

The original recorder supports only hermetic/fork/operator and records completed from actual command exit codes. The original bounded helper uses relative imports, authenticated fork checks and two distinct constructions. Originals were inspected, not substituted for the missing delivered programs or executed in their network modes.

## Independent fixture probes

Exact variable bindings used below:

```sh
W=/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1
D="$W/docs/incidents/2026-09-16-dtf-recovery/migration"
V="$D/conformance-20261114/task-2/verification"
cd "$W"
```

Created two owned fixture directories at V/fixtures/source and V/fixtures/destination. All regular files were created using apply_patch. Each listed string ended with LF:

| Relative fixture path | Contents | Bytes | Before SHA-256 |
| --- | --- | ---: | --- |
| source/identical.txt | byte preservation witness | 26 | 7c91980c917af362f8e1fcdf88b71e337993ce803fca56c5c633a72fe9a4f8be |
| destination/identical.txt | byte preservation witness | 26 | 7c91980c917af362f8e1fcdf88b71e337993ce803fca56c5c633a72fe9a4f8be |
| source/missing.txt | source-only witness | 20 | 216c0c0b4078a22eef0ccddfd64cbf395b1718b8e4ad06d683c26d50fec182b9 |
| source/tampered.txt | original witness | 17 | a843820c966a96bcd48e3a916f6ecbf6b0ae92be1764d7e9a40c025a5c7515a7 |
| destination/tampered.txt | tampered witness | 17 | de4dd657710b2a0d2e1cffb5fbe94bc0c17b5a2a68034b77c560652f247d16f0 |

Created V/outward-sentinel.txt containing "owned sentinel outside fixture roots" plus LF. Command:

```sh
ln -s ../../outward-sentinel.txt "$V/fixtures/source/outward-link"
```

Exit 0, empty stdout/stderr. The link leaves the fixture source root but remains inside verifier ownership. Its link text was inspected with readlink only; its target was not traversed through the link.

Executed:

```sh
bun "$D/resumed-integration/record-verification.ts" inventory "$V/happy-output" "$V/fixtures/source" "$V/fixtures/destination"
bun "$D/resumed-integration/record-verification.ts" delivery "$V/happy-output/inventory.json" "$V/delivery-output"
```

Each exited **1**, stdout empty, with identical stderr:

```text
error: Module not found "/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts"
```

All five fixture raw hashes were independently compared after these attempts and each matched its before value. The link text remained ../../outward-sentinel.txt. This proves the attempts preserved fixture bytes. It **does not prove** working inventory, delivery, missing-file rejection, tamper rejection or outward-symlink rejection. Neither mode loaded, neither named the fixture violations, and no inventory was generated. The required success and rejection contracts remain unverified. Fixture probes live under verification rather than the producer's inventory-negative directory to respect the verifier's narrower write authorization.

## Exact helper typecheck

Executed with TMPDIR="$V" and BUN_RUNTIME_TRANSPILER_CACHE_PATH="$V/runtime-cache":

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node "$D/resumed-integration/record-verification.ts" "$D/resumed-integration/verify-bounded-deployments.ts"
```

Exit **2**, stderr empty. Raw stdout:

```text
error TS6053: File '/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts' not found.
  The file is in the program because:
    Root file specified for compilation
error TS6053: File '/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts' not found.
  The file is in the program because:
    Root file specified for compilation
```

The compiler started; this is missing delivered source, not a claimed successful compilation or a dependency installation failure. No full suite or network mode was run.

## Adversarial classes and limits

- stale_state: reread the current gate during probing; it still says needs-fix. Bound current plan, claim and gate bytes above. Historical retained originals are not current delivered implementations. ready.json describes an untracked node_modules link, while current Git status does not list it; its old status list was not used as current cleanliness evidence. No independent reproduction of bootstrap's lib/crane failure was attempted.
- dirty_worktree: actual full untracked status above differs from a clean checkout. Scoped tracked diff is empty. No staging, resets, overwrites of user files or dependency changes were used to make checks pass. Unrelated bytes were not exhaustively fingerprinted; preservation is supported by the restricted writes, not an invented before/after audit.
- misleading_success_output: producer status is blocked and acceptance_met=false. Module-not-found and TS6053 are failures before contract execution. Fixture byte equality alone cannot convert them to passes. No aggregate counts, file existence or verdict-file creation establishes acceptance.
- byte preservation: required original programs exist with hashes above, delivered counterparts are absent. Recovery preservation fails the delivery boundary. Fixture bytes themselves stayed unchanged.
- missing/tampered/outward-symlink rejection: independently constructed concrete fixtures and invoked both modes, but all three behavioral checks are blocked by missing executable source. Nonzero startup errors do not establish rejection of the intended entries.
- generated artifacts: no producer inventory or delivery receipt exists; completeness and disposition coverage remain unverified.
- task 3 authenticated source facts: outside this assigned task 2. No new source policy, unsupported financial gate or source-authentication verdict is asserted.

## Cleanup and DoneClaim

Removed only owned resources: unlink of fixtures/source/outward-link (exit 0); apply_patch deletion of the five regular fixtures and sentinel; `rm -r "$V/runtime-cache"` (exit 0); `rmdir "$V/fixtures/source" "$V/fixtures/destination" "$V/fixtures"` (exit 0). The removal commands had empty stdout/stderr. No watcher, server, background process or shared cache was created. No producer file was edited.

Permanent changes are this report and the final .omo verdict. Manual QA artifacts are the full document/source inspection and recorded raw CLI failures above. No fixes were implemented. Remaining risk: the whole task 2 recovery, reconciliation and executable acceptance remain outstanding; dependent tasks must not consume the blocked claim as confirmed. The bootstrap diagnosis is reported by ready.json, not independently reproduced here.
