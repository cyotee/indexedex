# Prepared-range census A1 repair

**Implementation and focused/manual proof pass. Required combined validation
is blocked by an out-of-scope portable fixture adaptation. This is not a
completed green delivery or a readiness claim.**

The single requested combined run finished: **333 tests passed and 3 failed**.
Both exact strict TypeScript commands passed with empty stdout/stderr. No
process remains pending. The full suite was not rerun or presented as green.

The deterministic failure is
`bundle.test.ts:481-500`, "omitting old configured SY from a relocated complete
preparation rejects the census". Its transport owner,
`task-12/mixed-fixture.ts:234-236`, keys responses by the old suffix-derived
topic array. The new explicit query has no matching key, so the fixture returns
an empty response. This file is outside the four authorized modules and has
not been edited.

`attempt-15-portable-fixture-diagnosis` proves the distinction without changing
product or fixture source: the exact relocated omission is admitted with the
stale fixture key; assigning the existing three configuration rows to the new
query in memory makes the same production verifier reject it. The intended
source adjustment is to import `compensationEventTopics` in the task-12 fixture
and use `compensationEventTopics(migration, "configuration")` for that response
key. Explicit authorization is required before making this outside-scope edit.
Production selection was not weakened to match the stale fixture.

The other full-run failures were a 15-second portable relocation timeout and a
following `ENOENT` on an owned fixture bundle, consistent with timeout cleanup
fallout. The timed-out test passed in isolation under the same unchanged
15-second limit in `attempt-14-portable-timeout-diagnosis` (9,979.77 ms).
The retained prior integration timing was 9,979.08 ms. The timing cause is not
established; this isolated result does not erase the failed combined run. The
timeout-affected temporary root was checked and is absent.

The A1 root cause was reproduced before product edits. The old prepared
full-range selector included `ThresholdsConfigured` because its name ended in
`Configured`. Canonical receipt authentication succeeded, but no admitted
compensation row could represent initialization. Both public `verify` and
read-only `activate` failed at the reported
`configured original omitted from complete deployment census` error.
Attempt 01 records 10 existing tests passing and those two new positives failing.

The fix moves the already confirmed explicit compensation mapping into one
small shared export:

- `execution-domain.ts`: `compensationEventTopics(migration, scope)` resolves
  the existing typed category map through the source-bound ABI. Empty census
  requests all configuration topics plus independent issuance.
- `execution-state.ts`: prepared full-range verification requests only the
  configuration topics from that same export.
- `execution-state.test.ts`: adds initialized prepared verify/activation and
  negative cases; updates its existing mixed-record fixture key for the changed
  query shape.
- `execution-domain.test.ts`: unchanged, including its confirmed initialization,
  all-category omission, pricing binding and historical-domain coverage.

There is one production mapping, no initialization-specific exclusion, no
suffix-based range classifier, no new framework and no range cutoff change.
The prepared range remains deployment-through-latest and authenticates each
canonical receipt. Existing membership, full-input, current-state and issuance
history checks remain unchanged.

The dependency direction already existed: execution-state imports
execution-domain; domain loads state dynamically within authenticateHistory.
The shared export adds no new module dependency edge. `source-preservation.json`
records exact before/after hashes showing byte identity for:

1. Domain loading, source-bound pricing and deployment authentication.
2. Historical execution/preparation/journal/intent authentication.
3. Transaction-local configure, issuance and pricing receipt handling plus
   full-row checks.
4. Prepared range receipt identity, membership, current state and issuance
   history checks after the query.

Thus the independently confirmed ERC721/ERC20 issuance-event repair and the
receipt-local configure branch were not changed. The range query selection is
the only production behavior changed.

Focused proof is `attempt-03-adversarial`: **41 pass, zero fail**. It includes:

- Public prepared verify and read-only activation preflight with initialization
  plus valid expected compensation history.
- All ten actual compensation configuration categories omitted at deployment
  and at a later block (20 independent negative cases).
- Missing receipt, wrong receipt transaction, wrong receipt header, wrong range
  block identity, malformed range, changed full stored input, missing issuance
  history, duplicate preparation original and stale preparation boundary.

Sensitivity probes were restored byte-for-byte before manual/combined QA:

| Attempt | Temporary change | Observed failure |
| --- | --- | --- |
| 04 | Remove represented-origin rejection | All 20 omission cases fail |
| 05 | Move range start to deployment + 1 | All 10 deployment-block omission cases fail |
| 06 | Bypass canonical receipt acquisition | Four receipt/header identity cases fail |

Manual proof is `manual-prepared-IR6pIP/`. It drives the actual CLI in three
child processes: verify, read-only activate, and verify again. Exact child argv,
cwd, stdout, stderr and exit are retained in `cli-*.json`; each exited 0 with
empty stderr. Verify returned the expected independent recipient, unissued
state and bond ID 0. Read-only activate returned one selected operation and
`fullTask9: open`; it did not send or prove real activation. The remaining 29
manual scenarios are the 20 omissions and nine controlled corruptions above.
All 30 fixture contexts closed successfully.

Provenance is explicit: the authentic saved initialization receipt, source-bound
ABI, transaction and header are checked first. Its exact initialization
topics/data are replayed in a separately created synthetic
deployment/preparation/configuration context. Emitter, block, transaction,
indices, expected configuration and getter state are synthetic fixture data;
they are not claimed historical chain facts. No retained manifest or signed
domain is rebound. `original-evidence-bindings.json` preserves before/after
hashes and lengths of all 41 original evidence files, which are unchanged.
The new synthetic prepared/execution bytes are retained separately.

Affected prior manual proofs were replayed in
`manual-preservation-485KMt/`, without writing into any prior evidence directory:

- Empty census: three accepted initialization checks; all 22 singleton
  configuration/issuance negatives; malformed, stale-header and missing-ABI
  negatives; all 41 original evidence files unchanged.
- Historical/current census: complete B loads, verifies and resumes twice
  after Y; missing X, missing Y and empty-category manifests reject. All seven
  protected preparation/execution/journal/intent byte strings stay unchanged.
  Only the fixture range transport is adapted to the explicit query.

The issuance and setter manual receipts were retained rather than rerun:
their executed receipt-local and source-loading sections are byte-identical,
their dependency edges are unchanged, and their existing current tests pass
in the full run. This reuse decision and semantic fingerprints are recorded
in `source-preservation.json`.

The combined runner executes the exact commands preserved by
issuance-census-integration, from the assigned worktree:

```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

Actual expanded argv matches the preserved runs exactly (25, 103 and 18
arguments respectively). Every attempt records NUL-delimited argv, escaped
command, cwd, started/finished times, stdout, stderr, direct exit and source
fingerprints. Source hashes are stable within each run. The two strict
typechecks exited 0; the full test run exited 1. `combined.exit.txt` remains 1.

Malformed/stale/dirty/misleading-success probes are meaningful: the original
initialization positive is red on old code; negatives assert specific errors
after that positive succeeds; mutants lose the intended rejection; CLI success
requires exit 0, empty stderr and parsed read-only output; final manual PASS
is emitted after all assertions and cleanup. Dirty tracked/untracked state is
retained in attempt 13; scoped `git diff --check` exits 0 in attempt 12.
The full-run failures are explicitly retained rather than masked by diagnostics.

Self-review: responsibilities remain in the existing domain/state modules;
untrusted bytes still cross existing schemas; category coverage is typed and
exhaustive; no type escapes, retries, fallback source, single-use product helper,
parameter bloat, redundant setter verification, negative-form product names or
production logging were added. Test proof is failing-first and mutation-backed.
The domain module is 234 pure lines; the unchanged domain test is 242. The
pre-existing oversized state implementation/test remain 426/350 pure lines;
the production state edit reduces lines. Broad restructuring of frozen reviewed
guards was excluded from this precise repair.

All owned monitor processes have exited. HTTP fixtures/providers and temporary
roots closed through their existing finally paths, with manual cleanup receipts
retained. No public RPC, Anvil, Forge, installation, commit, delegation, readiness
marker or plan closure was performed. Native LSP freshness timed out, but both
requested strict compiler commands passed.

Remaining decision: authorize the narrow task-12 fixture adaptation, then rerun
the affected failed checks. This report does not assert a green full-suite gate
or authorize releasing task 10.
