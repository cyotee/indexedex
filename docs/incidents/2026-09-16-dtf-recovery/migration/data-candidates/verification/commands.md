# Independent phase27 command and exit record

All shell commands ran from the candidate worktree unless specified. No retries of types or the operator suite occurred.

## Source state command (bash_1; exit 0)

```sh
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates' && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager status --short --untracked-files=all --ignore-submodules=all && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager rev-parse HEAD && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager branch --show-current && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager diff --ignore-submodules=all 0856a5c56e5d09b81c669f59b613efef79133e19 -- scripts/recovery/dtf-migration docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md
```

```text
status: completed exit_code: 0
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/binding-audit.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/manifest.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/report.md
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/seal.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/source-manifest.json
0856a5c56e5d09b81c669f59b613efef79133e19
work/dtf-migration-phase-27-data-candidates
```

## Strict types and exactly one operator invocation (bash_2; exit 0)

```sh
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates'
printf 'VERIFIER_TOOL_VERSIONS\n'
bun --version
node --version
printf 'VERIFIER_TYPES_START\n'
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
types_rc=$?
printf 'VERIFIER_TYPES_EXIT=%s\n' "$types_rc"
printf 'VERIFIER_OPERATOR_TESTS_START\n'
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
tests_rc=$?
printf 'VERIFIER_OPERATOR_TESTS_EXIT=%s\n' "$tests_rc"
if [ "$types_rc" -eq 0 ] && [ "$tests_rc" -eq 0 ]; then printf 'VERIFIER_OFFLINE_CHECKS_COMPLETE\n'; else exit 1; fi
```

Observed runtime versions: Bun 1.4.2 (50a8a8387), Node v26.11.1. Types marker VERIFIER_TYPES_EXIT=0. Test marker VERIFIER_OPERATOR_TESTS_EXIT=0. Final VERIFIER_OFFLINE_CHECKS_COMPLETE observed. Final terminal screen is retained as operator-final-screen.txt, not misrepresented as a complete raw transcript. The first log display was inspector-truncated after 10,000 characters; the final screen preserved the full final summary. No tests were repeated to replace that display.

## Full tracked/staged diff (bash_3; exit 0)

```sh
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates' && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager diff --ignore-submodules=all 0856a5c56e5d09b81c669f59b613efef79133e19 && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager diff --cached --ignore-submodules=all
```

No stdout; both diffs empty.

## CLI help and stopped-document boundary (bash_4; exit 0)

```sh
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates'
printf 'VERIFIER_CLI_HELP_START\n'
bun scripts/recovery/dtf-migration/cli.ts --help
help_rc=$?
printf 'VERIFIER_CLI_HELP_EXIT=%s\n' "$help_rc"
printf 'VERIFIER_BLOCKER_PREPARE_START\n'
bun scripts/recovery/dtf-migration/cli.ts prepare --input '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates/docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/manifest.json' --output '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates/docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/rejected-prepare-output'
prepare_rc=$?
printf 'VERIFIER_BLOCKER_PREPARE_EXIT=%s\n' "$prepare_rc"
printf 'VERIFIER_BLOCKER_VALIDATE_START\n'
bun scripts/recovery/dtf-migration/cli.ts validate --manifest '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates/docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/manifest.json'
validate_rc=$?
printf 'VERIFIER_BLOCKER_VALIDATE_EXIT=%s\n' "$validate_rc"
if [ "$help_rc" -eq 0 ] && [ "$prepare_rc" -eq 1 ] && [ "$validate_rc" -eq 1 ]; then printf 'VERIFIER_CLI_BOUNDARY_COMPLETE\n'; else exit 1; fi
```

Complete returned output is cli-boundary.log. Help exit 0; prepare and validate each expected exit 1 with INPUT schema errors. This tests the actual blocked manifest, not a nonexistent candidate document. No stage/execute/rehearse command ran.

## In-process verification

Bun.file(...).arrayBuffer() plus node:crypto SHA-256 verified all 36 declarations before any raw-table parsing. Path resolution uses node:path.resolve against the explicit original input root. The completed pass found 34 matches and two mismatches. A second completed identity pass after checks compared the same 33 raw/manifest/producer paths and all 53 operator TypeScript paths; all were unchanged. Every producer manifest/seal link and all 12 producer source identities matched. Exact records are in the JSON evidence.

## Failed and unavailable attempts

The initial multi-read displays were truncated; the brief/router/Bun rules and stopped producer handoff were reopened in bounded reads. The first machine JSON parse attempted to consume an elided tool.read result and threw `JSON Parse error: Unrecognized token '…'`; it did not reach the binding loop. The next step parsed the already-read original declaration bytes, not the elided rendering, and independently completed every binding. An initial lookup used nonexistent .github/ASSISTANT_TESTING.md; ASSISTANT_RULES.md points to .github/ASSISTANT_TESTS.md, subsequently read. Worktree-local and root migration/portable-operator evidence paths did not exist; lookup widened to the explicit phase26 path for the established type/test command, not an alternate candidate. Biome is absent; apply_patch reports that JSON LSP diagnostic limitation. Nothing was installed and no source/tests were changed. No substantive failed shell check was overwritten or rerun; expected schema rejection exits remain recorded.

## Final pre-seal state (bash_5; exit 0)

```sh
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates' && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager status --short --untracked-files=all --ignore-submodules=all && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager rev-parse HEAD && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager diff --exit-code --ignore-submodules=all 0856a5c56e5d09b81c669f59b613efef79133e19 && GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager diff --cached --exit-code --ignore-submodules=all
```

```text
status: completed exit_code: 0
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/binding-audit.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/manifest.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/report.md
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/seal.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation/source-manifest.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/binding-audit.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/commands.md
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/coverage.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/operator-final-screen.txt
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/producer-audit.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/report.md
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/source-manifest.json
?? docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification/unchanged-inputs.json
0856a5c56e5d09b81c669f59b613efef79133e19
```

The final status snapshot precedes cleanup/manifest/seal creation and the report wording correction. Only original implementation evidence and owned verification files are untracked; cli-boundary.log is retained but ignored by repository log patterns. Both tracked/staged exit-code diffs are clean and HEAD remains the requested parent. All five JSON evidence documents parse successfully. cleanup.json records the actual completed sessions and absence of the rejected output directory.
