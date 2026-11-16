# Combined reopened task 7 QA

All three requested checks passed in the settled conformance worktree. This
report certifies the assigned QA portion only. It does not close a plan box,
replace the independent verifier, or establish task 10 EVM lifecycle proof.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Branch: `work/dtf-conformance-20261115-wave-1`.
HEAD: `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`.
Runtime: `/opt/homebrew/bin/bun`, version `1.4.2+50a8a8387`.
Compiler: installed TypeScript `5.9.2`, invoked through Bun.
Installed package manifests report ethers `6.17.0` and Zod `3.25.74`.
The environment probe logs retain the platform, exact commands and real exits.

## Required commands

Each command ran exactly once, in this order, with ordinary Bash glob
expansion. `run-checks.sh` records the actual expanded arguments as NUL-delimited
bytes, shell-escaped command text, cwd, UTC start/end, separate complete stdout
and stderr, and the child exit. `results.json` also contains the expanded argv.
No narrower overlapping operator subset was run.

```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

| Receipt prefix | Actual result |
| --- | --- |
| `01-tests` | Exit 0; 251 pass, 0 fail, 21 files; reported 86.33 seconds |
| `02-operator-types` | Exit 0; 86 selected TypeScript files; empty stdout/stderr |
| `03-helper-types` | Exit 0; both named helpers; empty stdout/stderr |

The six named task 7 suites are present in both expanded argv and raw runner
output: preparation, execution, nft-contributions, remaining-claimed-sy,
claimed-sy-state and claimed-sy-witness. All 21 selected test files appear in the
runner output. The older 193-pass main-checkout result is not used.

The monitor `mon_VFTABKR9PRK11ZDC`, session `bash_1`, delivered each result and
`QA_COMPLETE exit=0`, followed by watcher completion with exit 0. There is no
pending process. No required command failed or required a retry.

## Retained real CLI and lane proofs

`manual-bindings.json` binds original evidence by path, SHA-256 and byte count.
`manual-outcomes.json` records inspection of the raw outcomes. No manual proof
was recreated or rerun.

The census proof is exactly `census/attempt-15-manual/{command.txt,output.log,exit.txt}`
and `census/manual-eqooQc/`, relative to the parent of this integration directory.
The parent command exited 0. All eight raw `child-N.json` records match the
children embedded in `result.json`, including argv, stdout, stderr and exit.
Their exits are `[0,0,0,0,0,1,1,1]`, with no signals.

The successful children validate original A, validate complete B, verify B, and
resume B twice. The three rejected incomplete manifests retain only X, only Y,
or neither. Each has empty stdout, exit 1 and the exact `PROVENANCE` census
omission error on stderr. The six protected A/B preparation, execution, journal
and intent byte captures match both recorded before/after hashes. B retains X
and loads Y. Its payload hash stays unchanged after publishing Y. The raw 2,358
RPC requests contain no transaction-count request and no raw-transaction send.
The result reports zero new intents and zero price re-quotes.

The verify result has `rows:[]` and `totalSupply:"0"` because this fixture has SY
rows rather than independent recipients. It is not a funding or bond lifecycle
success. The source and regression suite check SY configuration state, and
`fullTask9:"open"` remains visible in the raw CLI results.

The pin proof is the exact source `pin/manual-trace.ts` and its retained command,
raw output and exit in `pin/verification.md`. Exit 0 accompanies books
`[17,100,300,400,5,80,90]` to `[7,90,270,370,8,77,90]`, conservation checks,
`WITNESS_SHAPE` for reordered observations and `TRACE_FAILED` for a caught inner
failure. No artifact or replacement router pin is loaded. This is an offline
trace parser/economics proof.

The omission proof uses `omissions/manual-omissions.command.json`,
`manual-omissions.json`, and both retained `manual-omissions.run.log` and
`manual-omissions.rerun.log`. Both stdout JSON payloads exactly equal the result
artifact before their `MANUAL_PASS` suffix. Four priced controls pass. All 28
omissions have exactly the intended `category.0.original.field` issue,
`invalid_type` / `Required`, no pricing issue, and a passing restored control.
The retained focused log has 15 pass, 0 fail and an exit-0 command sidecar. The
pre-fix reconstruction shows that restoring the field still failed on missing
pricing. These are schema checks, not contract execution.

## Source freshness and dirty workspace

All 67 distinct local imports reached from the three manual programs and the
real CLI match their expected source hashes after lane integration. The
comparison uses the retained task-13 source census for unchanged modules and
the three lane records for their final files. The import graph has no missing
relative import. All six original ABI artifact references still match their
exact hashes and sizes.

`source-before.json` and `source-after.json` cover 104 operator, helper, proof,
dependency/configuration, artifact and recorder files. None changed during the
run. The recorded pre-existing lane evidence also remained byte-identical.
This is a source-bound QA result, not a clean-worktree claim.

Both raw tracked binary diffs are identical, SHA-256
`adf2deb89ecbcb0474cfa3394ec1f75c6d52b7d162fcc9e073b64ef621c42f53`.
Both staged diffs are empty. Before and after `git diff --check` exited 0 with
empty stdout/stderr. Complete dirty/untracked status outputs are retained;
there are no removed status lines or additions outside integration. This does
not claim an exhaustive byte census of unrelated untracked files.

The archived `source-identities.json` is fingerprinted in `results.json`.
Its runtime bytes are checked by the census fixture against fixed route
runtime hashes. The admitted manual receipt has no separate historical raw
JSON hash for that archive. Likewise, third-party manifests and the unchanged
lockfile are recorded, but historical recursive hashes of node_modules are not
available. These limits do not turn the 67 local-source matches into a claim
that every third-party byte was historically pinned.

## Failure classes and cleanup

| Actual trigger | Disposition |
| --- | --- |
| Stale state | Census proof preserves immutable A after Y while current incomplete B rejects. Current suite also rejects stale unsent A, forged history and changed retained state. |
| Dirty worktree | Shared dirty state was preserved; tracked diffs match and status changes are confined to integration evidence. |
| Malformed input | Lane proofs isolate all 28 missing originals; pin proof rejects malformed/caught-failure traces; census proof rejects incomplete current census. |
| Misleading success | Raw child outputs, exact intended errors, protected hashes and actual process exits were inspected. PASS markers, empty recipient rows and fullTask9 open are not lifecycle completion. |
| Long commands | The single operator run completed naturally in 86.33 seconds. No Forge, polling, timeout kill or duplicate run occurred. |
| Timing/flaky behavior | No failure, timeout or retry occurred. The single run does not estimate a flake rate. Census fixtures use unique loopback listeners; the longest displayed case took 10.41 seconds under the requested 15-second per-test budget. |
| Interruption | Existing tests exercise durable signed intents, partial unpublished records, concurrent writers, active-checkpoint relocation and same-block completion. Retained CLI resumes are read-only; no actual economic operation was interrupted in this QA assignment. |

`cleanup.json` records natural recorder completion. No new dtf-prefixed temp
directory remained. The prior `dtf-prepare-test-6ABTvq` and
`dtf-prepare-test-sSyY0e` directories remain untouched; their worker ownership
is unknown. No artifact/cache cleanup, process kill, installation, delegation,
commit, public transaction, product/test edit or plan-checkbox edit occurred.

Automatic editor diagnostics report missing bash-language-server and Biome.
No LSP installation or clean-LSP claim is made. Both requested strict compiler
checks passed with their actual exits and empty diagnostics.

The only new executable evidence is a 42-line command recorder whose single
responsibility is retaining command receipts. It adds no product API, runtime
fallback, test seam or retry. Broad refactoring of the existing oversized
preparation and quote modules is outside this QA assignment.

All assigned required checks and evidence interpretation are met. Whole-plan,
task-10 EVM lifecycle and task-13 full-tree Forge/freshness conclusions remain
outside this claim. The independent verifier must assess the final DoneClaim.
