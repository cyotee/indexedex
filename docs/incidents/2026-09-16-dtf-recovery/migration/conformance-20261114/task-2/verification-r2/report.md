# Task 2 independent verification, second pass

**Verdict: confirmed. Confidence: high. Verification surface: harness. No implementation fixes.**

This verdict applies to the final producer claim with SHA-256 `46590145e455f3befb2ad026170a4a79a0b42aaa5d5418e3b9567182572cc50a`, not its earlier blocked claim. The historical first report remains byte-identical at `../verification/report.md`. The first verdict is archived byte-identically as `task-2-verdict-r1.json`, SHA-256 `a80cdb9cf9042725c6a4d9763956e701ce5b858a1972e075e2b1eae64398a58a`.

## Inspected delivery and provenance

Read the current DoneClaim, complete task 2 in the approved copied plan, both delivered helpers, original retained helpers, recovery implementation, root/ownership inputs, supersession, manifests, all exceptional dispositions, and cited raw results with their command sidecars. The copied plan and repository rules were read during the first pass. This pass performed no product, financial, source-admission or Forge readiness review.

`byte-audit.json` is an independently generated per-entry audit, produced by `audit.mjs` without importing producer verification logic. It performs lstat-based boundary checks and streaming raw SHA-256, never traversing symlinks. Every one of 72,629 recovery rows was compared with its actual source and delivered bytes or its explicit source-qualified replacement. It independently enumerated all 31 retained roots, primary migration evidence, and primary execution records and found no unaccounted source entries. Directory rows were checked as directories, not inferred from file counts.

All 23 semantic conflicts were individually checked: 21 historical runbooks and the phase-01 manifest and matrix. Their source-qualified archives match the historical raw bytes; their current destinations match the recorded destination hashes. Independently stripping only trailing CR/LF still left each classified semantic, not EOF-only. Four historical symlinks match their archived link-text bytes; they were neither followed nor recreated. Every row has ownership evidence and a disposition. No unresolved or foreign ownership row was found.

`additional-evidence.json` records these 23 independent classification checks and all 31 actual Git HEAD queries; each revision matched its recorded binding. All ownership-reference files were independently hashed and matched their archived execution-record copies. Every listed source root has an actual path reference in its cited records. An independent scan of all 3,864 archived execution-record files discovered 30 named migration roots in addition to the explicitly assigned retained root, with no omitted candidate root.

The delivered bounded helper is byte-identical to the retained original. The recorder extension retains the original verification body and relative imports; its original full bytes are archived. Exact final bindings matched:

| File | SHA-256 |
| --- | --- |
| resumed-integration/record-verification.ts | c9e602dc42b9ff224f6e48c412747c7d1a1f777f4faa483263973f56cdeb34d6 |
| resumed-integration/verify-bounded-deployments.ts | 56c8b9ad58e78f5293548c40d66c30ba426dbc2a47572762599d7836d0ced8ed |
| task-2/recovery.json | 95536e259a87e21c9d3c02be208e64c766c4a48deb02054a7a797a36037a49f7 |
| task-2/delivery/inventory.json | 7a40a2f63aa90f0c891da152d8d01c8d7db946381afef375c09b02288028ce21 |
| task-2/delivery/delivery.json | 7cb251140f049b2f1d843b621d1a48781ff131b8806beb7a30f05d2ecee44ee4 |

Required families are represented by checked raw entries: source manifest/matrix, route disposition, final-source, final-hermetic-r2/final-fork/final-operator, bounded-remediation, recovery-receipts, b1 iterations 1-4, b2-public-exit-probe, remaining-SY and deployment-gas-resumed. Their presence alone was not used as proof: the per-entry source/destination comparisons above establish preservation. Historical failures, sidecars and reviewer records remain evidence rather than newly passing test results.

## Independent real CLI probes

Exact bindings for the commands:

```sh
W=/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1
D="$W/docs/incidents/2026-09-16-dtf-recovery/migration"
E="$D/conformance-20261114"
V="$E/task-2/verification-r2"
cd "$W"
```

All commands used the worktree above, `TMPDIR="$V"` and `BUN_RUNTIME_TRANSPILER_CACHE_PATH=0`. `probes.json` contains complete argv, stdout, stderr, exit codes and per-command before/after raw hashes, sizes, inode and mtime snapshots.

| Actual command suffix after `bun "$D/resumed-integration/record-verification.ts"` | Exit | Independently inspected result |
| --- | ---: | --- |
| `inventory "$V/happy-inventory" "$V/fixtures/source" "$V/fixtures/destination"` | 0 | Identical 32-byte raw fixture, no divergence. |
| `delivery "$V/happy-inventory/inventory.json" "$V/happy-delivery"` | 0 | Exact retained bytes; newly added generated.json appears with independently matched raw hash. |
| `delivery "$V/happy-inventory/inventory.json" "$V/stale-delivery"` | 1 | Names changed source bytes as stale and newly unrecorded source files. |
| `inventory "$V/negative-inventory" "$V/fixtures/source" "$V/fixtures/destination"` | 0 | Names missing, symlink and semantic rows. Inventory reports differences; it does not claim delivery success. |
| `delivery "$V/negative-inventory/inventory.json" "$V/negative-delivery"` | 1 | Names missing.txt, tampered.txt, changed preserved.txt and outward-link; completed=false. |
| `inventory "$V/outward-root-output" "$V/fixtures/source/outward-link" "$V/fixtures/destination"` | 1 | Rejects the exact symlink boundary before traversal. |

The fixture was independent of producer fixtures. It included source-only bytes, a tampered destination, and `outward-link -> ../../outside-fixture.txt`, whose owned target lies outside the fixture root. A planted destination log containing `VERIFICATION_COMPLETE`, `completed:true` and `0 fail` did not conceal missing bytes. Every command left both fixture inputs unchanged. Nonzero exits were accepted as the intended negative results only after inspecting the exact named failures.

The exact task-13 helper typecheck ran independently:

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node "$D/resumed-integration/record-verification.ts" "$D/resumed-integration/verify-bounded-deployments.ts"
```

Exit **0**, empty stdout and stderr. The producer's final compiler sidecar also bound 87 source files, each independently matched before QA and rehashed afterward. Historical sidecars with earlier helper hashes remain historical, not substituted final-source checks.

After owned fixture cleanup, the real delivered tree was independently checked:

```sh
bun "$D/resumed-integration/record-verification.ts" delivery "$E/task-2/delivery/inventory.json" "$V/real-delivery"
```

Actual monitored exit **0**, output `DELIVERY_COMPLETE entries=72904 failures=0`. `real-delivery/delivery.json` was inspected: completed=true and no failures. This checks existing bytes and dispositions, not just the completion line. Its additive entries include verifier evidence and expressly observed concurrent task-1 records; this task does not certify task 1. Evidence written after that scan is additive reviewer output for later final delivery, not retroactively claimed to be inside the producer's original receipt.

## Prerequisites, drift and adversarial classes

Actual read-only Git HEAD, branch, status, diff-stat and diff-check commands all exited 0. The worktree is the named branch at `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`. It is dirty: concurrent task-1 plan changes and untracked recovery files were reported, preserved and never staged. The empty producer tracked diff did not establish cleanliness or artifact completeness.

The node_modules link targets the existing primary node_modules, and the compiler entry is available; actual TypeScript execution above confirms the required Bun/TS capability. lib/crane is a directory rather than an outward symlink. No shared dependency was changed. The older Crane readiness issue is not a Bun/TS recovery prerequisite. Forge readiness remains outside this certification; no Solidity build or network mode was run.

`stability.mjs` ran after the probes and real delivery. It rehashed all protected retained and delivered bytes, the current claim and manifest bindings, historical report/verdict, and compiler source bindings. It also rescanned source roots for newly introduced non-directory entries. Actual monitored exit **0**; `stability.json` reports 145,319 protected entries, 126,460 files, four links, and zero failures. Thus no protected source hash drift occurred during the pass. The result is based on individual comparisons recorded against `byte-audit.json` and `initial-bindings.json`.

- stale_state: changed source is rejected; the final claim and source hashes remained unchanged across this pass.
- dirty_worktree: actual status and raw filesystem inventories were used; no cleanup of unrelated work or tracked-diff shortcut.
- misleading_success_output: planted successful prose could not override missing-byte failures; raw producer logs and sidecar exits were inspected separately.
- byte integrity and symlink boundaries: happy byte preservation, explicit missing/tampered rejection and outward-root rejection passed at the actual CLI.
- ownership and generated artifacts: every original candidate is accounted for; supersession binds the archived original and replacement; generated artifact hashes were independently checked.

## Changes, cleanup and limits

Only verification-r2 evidence and the final canonical verdict were written. The old verdict was archived before replacement; the first report was not changed. All owned temporary fixture files, sentinel, outward link and empty fixture directories were removed. unlink and rmdir exited 0; regular-file removals used apply_patch. No shared cache, dependency, archived original, live journal or producer file was altered. Completed monitor commands exited naturally.

The retained verification evidence programs have 136 and 81 nonblank, noncomment lines and own the independent byte audit and stability check respectively. They execute no archived instructions and introduce no producer seam. Their actual runs passed. Fresh LSP diagnostics for the stability evidence script timed out; no LSP success is claimed. No installs were performed.

This confirms task 2 artifact recovery and helper acceptance only. It does not certify task 3 source authentication, later conformance behavior, Solidity/Forge readiness, historical suites as newly executed, financial allocations or public operations. Original hermetic/fork/operator and bounded-deployment network modes were inspected and preserved, not executed.
