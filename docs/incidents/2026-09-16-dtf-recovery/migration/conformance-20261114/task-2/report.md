Task 2 restores all retained migration evidence and the other migration outputs named by the existing execution records. It does not certify current source eligibility, financial allocations or the historical tests as newly executed. The final delivery outcome is recorded in `delivery/delivery.json`; the producer DoneClaim records the actual exit and stdout. Acceptance requires that receipt to have `completed: true` and zero failures.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
All paths below are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-2/` unless stated otherwise.

The first readiness read returned `needs-fix`. The lead subsequently clarified that identity and node_modules were verified, and that the unresolved Crane dependency blocks Solidity compilation only. Recovery and Bun/TypeScript verification proceeded under that explicit clarification. Forge readiness remains false. This task neither compiled Solidity nor changed `lib/crane`, installed dependencies, replayed the refused historical trace, changed providers or sent network transactions.

`recovery-inputs.json` binds the retained R directory plus 30 other existing migration directories named by historical execution records. `recovery.json` contains 72,629 source-qualified rows: 68,705 restored entries, 33 identical entries, 23 semantic historical differences, four archived symlinks and 3,864 archived primary execution records. Every row has its source, destination, delivered path, size, raw SHA-256 where applicable, actual checkout HEAD or content qualification, ownership evidence and disposition. Directories have no byte hash. No source is asserted clean merely because its HEAD was recorded. The initial destination and primary migration directory each contained only the current runbook and quote evidence; both matched the retained versions and their bytes remain unchanged.

All 23 historical content conflicts are preserved without overwriting current files. Twenty-one are historical runbooks; the other two are the phase-01 source manifest and source-route matrix. None is an EOF-only difference. `recovery-differences.json` and `manual-qa.json` enumerate every conflict and its archive. Four historical absolute symlinks from portable-operator negative fixtures are preserved as exact link-text bytes under `retained-originals/symlinks/`, with explicit updated destinations; they were neither followed nor recreated into the reference trees. No ownership row is unresolved.

The required `migration/resumed-integration/verify-bounded-deployments.ts` is delivered byte for byte with SHA-256 `56c8b9ad58e78f5293548c40d66c30ba426dbc2a47572762599d7836d0ced8ed`. Its relative imports compile. The recorder at the same directory now supports inventory and delivery, and its complete original hermetic/fork/operator verification body remains intact. The original recorder, SHA-256 `8192d15ff2aa039ea4bb306393205ed3e846270c482abcfb0f46c753e7353ac7`, is archived at `retained-originals/phase30-helper/record-verification.ts`. `supersessions.json` binds that source to the delivered recorder, SHA-256 `c9e602dc42b9ff224f6e48c412747c7d1a1f777f4faa483263973f56cdeb34d6`.

Before the extension, the original helper typecheck exited 0 and the original recorder rejected inventory with exit 1 and its original hermetic/fork/operator usage error. Those results remain in `verification/baseline-types.log` and `verification/baseline-inventory.log`, with exact command sidecars. No original failure was rewritten as passing.

The prescribed checks use these exact bindings:

```sh
W=/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1
D="$W/docs/incidents/2026-09-16-dtf-recovery/migration"
E="$D/conformance-20261114"
R=/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/docs/incidents/2026-09-16-dtf-recovery/migration
cd "$W"
bun "$D/resumed-integration/record-verification.ts" inventory "$E/task-2/inventory" "$R" "$D"
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node "$D/resumed-integration/record-verification.ts" "$D/resumed-integration/verify-bounded-deployments.ts"
bun "$E/task-2/fixture-qa.ts" -r2
bun "$D/resumed-integration/record-verification.ts" delivery "$E/task-2/inventory/inventory.json" "$E/task-2/delivery"
```

The final inventory exited 0: 13,613 retained entries, 72,860 destination entries and one intentional semantic difference, the recorder extension. All 13,613 original retained entries still match the initial source enumeration. Every divergent row was inspected. The source-manifest/matrix, recovery-route-disposition, final-source, final-hermetic-r2, final-fork, final-operator, bounded-remediation, recovery-receipts, all four b1 iterations, b2-public-exit-probe, remaining-SY and deployment-gas-resumed families are present. The final delivery appends evidence created after inventory, hashes the prior inventory as ordinary data and exempts only its own inventory/receipt from recursive self-hashing.

The exact helper typecheck exited 0. The auxiliary recovery, command recorder and fixture QA programs also passed the same strict options. Native diagnostics found no errors and, after removal of an unused import and type, no remaining recorder hints. One Native diagnostic request for the auxiliary command runner timed out waiting for freshness; the actual TypeScript compiler check passed and this is not represented as a successful Native check. `diagnostics.json` retains that limit. The first passing extended recorder and inventory are retained as `retained-originals/recorder-first-extension.ts` and `inventory-attempt-1/`. The final canonical inventory and final QA bind the corrected bytes; historical output path strings in the first inventory remain historical rather than rewritten.

The required negative probe created source-only `missing.bin`, byte-tampered `different.bin` and an outward symlink in two owned fixture directories. Delivery exited 1, emitted `completed: false` and named all three entries. Before/after inode, size, mtime and raw hash snapshots prove both fixture trees were unchanged during inventory/delivery. The source link was then preserved as inert link text and removed as owned cleanup. `inventory-negative/` preserves the first probe and `inventory-negative-r2/` the final-byte repeat. Each has exact commands, exits and raw logs. Both nine-command vectors matched:

| Probe | Exit |
| --- | --- |
| Negative inventory | 0 |
| Negative delivery, all three required failures | 1 |
| Malformed manifest, no output directory created | 1 |
| Symlink root, no traversal/output directory | 1 |
| Happy binary fixture inventory | 0 |
| Happy fixture delivery with new generated artifact and independent raw hashes | 0 |
| Source changed after inventory | 1 |
| EOF-only difference inventory | 0 |
| Unresolved EOF-only difference delivery | 1 |

`misleading-success/` adds an independent probe: a destination log says `VERIFICATION_COMPLETE`, `completed: true` and `0 fail`, but delivery still exits 1 for missing `required.bin`, with `completed: false`. The first extended source for this probe is archived; its only subsequent production changes remove unused declarations. `adversarial-results.json` records stale-state, dirty-worktree, misleading-output, malformed-input, symlink, generated-artifact and deterministic-fixture results, plus concrete reasons the other classes do not apply. The new validators do not run, copy, delete, stage or commit evidence.

`commands.json` and the referenced command sidecars retain actual argv, cwd, runtime versions, raw logs, exit/signal and transitive source-content bindings. Read-only Git diff-check, status and diff-stat commands each exited 0. The tracked diff is empty because restored evidence is untracked, including ignored raw logs that Git's default status does not enumerate. The filesystem inventories include them. No file was staged or committed. Existing untracked planning/state files were retained; existing independent `verification/report.md` describes the earlier blocked attempt and was preserved rather than edited. `retained-originals/initial-task-2-blocked.json` preserves the original producer claim.

`cleanup.json` records the exact disposable Bun cache entries removed from the task-owned temporary directory. The temporary directory is empty; it remains an owned empty command-evidence directory. Fixture bytes, failures, stdout, sidecars, reviewer outputs and historical journals remain delivered evidence. No shared cache or dependency was deleted. Monitored commands completed naturally; no job was cancelled for silence.

The task-2 inventory explicitly observes concurrent task-1 evidence without certifying a changing task-1 file. Final delivery after the later tasks must inventory their completed evidence and all later source changes. Task 2 does not claim those tasks, current on-chain authentication, network verification modes or Forge readiness. The overall conformance gaps require their assigned later tasks; retained historical manifests are provenance, not authority to revert current dependencies or product decisions.
