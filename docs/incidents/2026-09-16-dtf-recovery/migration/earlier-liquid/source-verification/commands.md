# Independent ED source verification commands

Working directory for every command:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source`.
Only loopback18569 was used for transactions. Existing archive bootstrap and
configured alias were unchanged. No credential or resolved upstream URL was
printed.

## Fresh independent custody

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source; ./node_modules/.bin/tsc --noEmit --target es2022 --module esnext --moduleResolution bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source-verification/custody.ts && export PATH=/Users/cyotee/.foundry/bin:$PATH && /opt/homebrew/Cellar/bun/1.4.2/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source-verification/custody.ts'
```

Monitor `mon_SADBABJ4V42DHG4C`, session `bash_2`: exit0.
Strict typecheck and complete fresh signed custody sequence succeed.
The run publishes raw signed transactions, raw/parsed receipts, complete
callTracer trees and economic before/after observations under `run-01/`.
No ED conversion is triggered.

## Independent offline audit

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source; ./node_modules/.bin/tsc --noEmit --target es2022 --module esnext --moduleResolution bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source-verification/audit.ts && /opt/homebrew/Cellar/bun/1.4.2/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source-verification/audit.ts'
```

Monitor `mon_NZ27H0CXG733D7PD`, session `bash_4`: exit0.
Actual sealed bindings/membership, archive excerpts/runtime bodies,
compiler-source/full-helper runtime, signatures/receipts, exact pull deltas,
late inner debit/credit and rollback, and retained structural exit evidence
are checked. `audit.json` contains the resulting bindings.

No new Solidity was written or compiled. The sealed producer Solar artifact
is read, independently authenticated and deployed only to the owned local fork.
No inherited unrelated suite, production test or blocked conversion was
replayed. These evidence runners are intentionally worktree-rooted, not claimed
portable operators.

## Diagnostics and scope

TypeScript LSP `error` diagnostics for both `custody.ts` and `audit.ts`:
`No diagnostics found`. Final strict tsc invocations above also pass.

Initial ordinary Git status exited128:
`error: expected submodule path 'lib/crane' not to be a symbolic link`.
Read-only status/diff commands use `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0` and
`--ignore-submodules=all`; no link or Git state was repaired.

The first combined shutdown check ended1 because lsof and ps correctly found
no listener/process; it is not a failed product execution. Final per-command
cleanup outcomes are recorded separately in `cleanup.json`.

One evidence-patch tool invocation used `patch` instead of the adapter's
required `input` field. It returned `input is required` without writing.
The corrected apply_patch invocation succeeded; this is not a failed source
or runtime probe. JSON LSP reports unavailable Biome; no installation was
attempted, and JSON is directly parsed and hashed.
