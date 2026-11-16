# Prepared fixture adaptation and affected QA

Only `task-12/mixed-fixture.ts` changed among the 97 captured source/tool/input
files. The fixture now imports and reuses
`compensationEventTopics(migration, "configuration")` for its existing range-query
response key. Its three response rows, omission construction, signed-history
construction and assertions remain unchanged. No classifier or production
verifier changed. The resulting fixture matches exactly the two authorized text
changes to the archived original.

Original fixture SHA-256:
`aa68ed246ee0e135860c1cf79b9712468cb05327dabc8496f9cf2adbbf9d37c4`.
Adapted fixture SHA-256:
`ef79cad27c4b6fd351f583c6c75d96560fb6b9d99ba3c887058ff1e1ef558bf8`.
The byte-identical original is retained in `mixed-fixture.before.txt`.

The prior A1 repair's `attempt-09-full-tests` remains a failed historical run:
333 pass, 3 fail, real exit 1. Its portable timeout, subsequent validation ENOENT
and omission assertion failure are preserved. The earlier isolated 9979.77-ms
pass does not clear that run. Its attempt-15 diagnosis showed that the same
verifier rejects the omission when the original three rows answer its explicit
query; the adapted fixture supplies that mapping without replacing validation.

The following new affected commands completed once in
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`:

```bash
env TASK12_EVIDENCE=<new-root>/01-focused bun test --timeout 15000 ./scripts/recovery/dtf-migration/bundle.test.ts -t 'complete mixed A-SY/B-configuration|default validate on a relocated retained-A|omitting old configured SY'
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
```

`<new-root>` above is explanatory shorthand. Each command's exact absolute cwd,
fully expanded NUL-delimited argv, shell-escaped command, UTC start/end, separate
raw stdout/stderr, before/after hashes and real exit are in its receipt directory;
`results.json` contains the exact expanded arrays. Both globs selected the actual
21 test files and 87 operator TypeScript files. Every selected test file was
observed in the raw full output.

| Receipt | Result |
| --- | --- |
| `01-focused` | 3 pass, 0 fail; 45 intentionally filtered; 22.20 seconds; exit 0 |
| `02-full-tests` | 336 pass, 0 fail across 21 files; 105.22 seconds; exit 0 |
| `03-operator-types` | All 87 operator files; empty stdout/stderr; exit 0 |
| `04-manual` | Complete relocated validate/verify accepted, original omitted-SY variant rejected; exit 0 |

The previously failing portable case took 10887.80 ms in the full run; relocated
default validation took 6141.39 ms and omitted-SY rejection 5020.32 ms. No failure
or timeout recurred. The timeout stayed at 15000 ms. No retry, skipped assertion,
alternate timeout, duplicate full run or general flake-free claim is involved.

The shell resolved Bun to `/opt/homebrew/bin/bun`, revision `1.4.2+50a8a8387`.
The actual compiler reported TypeScript `5.9.2`.

The already passing exact helper typecheck is retained from
`prepared-census/attempt-11-helper-types`, exit 0 with empty stdout/stderr.
`retained-helper-types.json` binds its argv and the 29 current reachable local
source files. The adapted fixture is outside that graph. Twenty-eight source
hashes match admitted older records. Historical records did not separately list
the task-11 `recovery.ts` dependency, so that earlier byte identity is not
retroactively asserted; its current before/after hash is captured. The owner
states helper inputs are unchanged. The helper typecheck was not rerun.

The existing focused test workflow saved `01-focused/portable-integrity.json`:
two fresh location domains each preserve all 27 transitive raw inputs and four
authenticated historical contexts. Signed historical domain hashes remain
original. The existing omission assertion saved the expected
`ExecutionError: configured original omitted from complete deployment census`
in `01-focused/tamper-rejections.log`.

The additional manual command is an exact recorded `bun --eval` driver calling
the existing production CLI `main`, using the same task-12 fixture and existing
bundle export/materialization. Its full code and outer argv are retained in
`04-manual/argv.nul`, `04-manual/command.txt` and the recorder. It makes no source
or response-map change.

Complete relocated `validate` and `verify` return through the production CLI.
The original omitted-SY construction, copied from the unchanged test, relocates
and rejects through production CLI `verify`. The expected negative is an actual
thrown CLI error, not a fabricated nonzero child-process exit; the enclosing
asserting driver exits 0. The exact three CLI argument arrays, returned/error
outcomes and complete raw output are retained.

The manual proof captures the explicit deployment-to-latest query, its same
three existing configuration rows and SHA-256
`09a1d6f304ed67f58acca3c84ddf7ab0e927b4c9c054aafbcaf1329d0badafd1`.
It asserts the response rows are unchanged before/after both variants and saves
all 27 original input bytes/hashes, checking each remains unchanged. The
transport is synthetic loopback. There are zero nonce requests or sends. This
is not fresh Anvil, public RPC, activation or real current-chain lifecycle proof.

All eight recorded commands saw the same source manifest before/after. The four
frozen domain/state source/test hashes still match the A1 producer's claim.
All 35 captured original failure/diagnosis/helper receipts and repair records
are unchanged, as are six repo artifact inputs captured in the relocation proof.
`source-before.json` and `source-after.json` provide these comparisons.

The monitor completed naturally with exit 0 and has no pending process. The
manual fixture closed and its temporary root is absent. No new `dtf-` temporary
directory remains; both unknown pre-existing checkpoint directories were
preserved. Cleanup used the existing fixture finally/afterEach paths, without
blanket deletion or killing unknown resources.

Missing Bash/Biome editor servers were not installed. The required strict
compiler result supplies the actual diagnostics. No broad audit, production
edit, assertion change, Forge, Anvil, public RPC, installation, commit,
delegation, readiness marker or plan closure occurred. Independent A1 acceptance
remains separate from this fixture adaptation's completed QA.
