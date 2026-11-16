# Task 7 / F2-01 census correction

The historical/current census defect is reproduced and fixed in
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
This claim covers the assigned read-only operator invariant. It does not close
task 10 or claim an on-chain lifecycle.

The final focused command passed **65 tests, zero failures**, exit 0, on
Bun 1.4.2. Manual public CLI validation, verification and repeated read-only
resume passed. Incomplete current manifests containing only X, only Y, or
neither were rejected with `PROVENANCE` and exit 1. All six protected A/B
preparation/execution/journal/intent files retained their original bytes.
There were zero additional nonce requests, sends, intents or price re-quotes.

The review originally supplied a source hypothesis. Attempt 06 establishes the
actual reproduction: A authenticates X, X is configured, B retains X through
A's exact accepted references and adds Y, B loads successfully, then publishing
Y's canonical fixture configuration causes the unchanged B load to fail with
`claimed SY: previously configured SY origin omitted from complete census`.
The other 54 tests passed. Attempts 02-05 were fixture construction diagnostics,
not successful reproductions; their output is preserved.

`acceptedContext` recursively used the default current validation contract for
A. That reached `quoteOriginals` in evidence mode and then a
deployment-to-latest census inside `authenticateClaimedSy`. The source, saved
preparation and journal were valid, but the historical A row set could not
contain future Y.

The fix uses the existing validation layers:

| Owned file | Delivered change |
| --- | --- |
| `scripts/recovery/dtf-migration/claimed-sy.ts` | Explicit current/historical census scope; historical reads end at the authenticated preparation block, current reads end at latest. Census membership is also checked when the current SY category is empty. |
| `scripts/recovery/dtf-migration/quotes.ts` | Historical evidence acquisition authenticates saved evidence without obtaining a new quote; exhaustive acquisition-mode handling selects the census scope. |
| `scripts/recovery/dtf-migration/preparation.ts` | Passes an explicit recursive validation context and authenticates retained quote provenance in its historical context. Ordinary saved-manifest validation defaults to the complete current census. |
| `scripts/recovery/dtf-migration/execution-domain.ts` | Opens accepted configure/issuance manifests in historical context; exact preparation, execution, journal, signed intent and canonical completion checks remain. |
| `scripts/recovery/dtf-migration/preparation.fixture.ts` | Adds address-specific RPC reads/code and trace responses plus request capture. Preserves the existing execution-fixture export. |
| `scripts/recovery/dtf-migration/execution.fixture.ts` | Factors the existing execution fixture into its named owned file and adds isolated authentic-signature/source-code census fixtures. This file did not exist at lane start. |
| `scripts/recovery/dtf-migration/execution.test.ts` | Adds the growing-census regression, current omissions, rehashed historical-domain attack, source/member/facet/economic/receipt/history-census attacks, current-state rejection and repeated-resume immutability assertions. |

No other product paths changed. `preparation.test.ts` and
`remaining-claimed-sy.test.ts` were run unchanged. Sibling-owned pin and
required-field omission files, Solidity, bundle and rehearsal code were not
edited.

The chosen boundary is the historical manifest's authenticated preparation
block. Its later accepted configuration is separately authenticated through its
original signed operation and canonical transaction-specific receipt. This
keeps both temporal contracts: A need not invent future rows; B must include
every origin configured from deployment through current state. There is no
CLI skip-validation option, new provenance system, fresh-price quotation or
rewriting of A. Duplicate-member and duplicate-origin validation remains in
the existing input/payload layers.

The reproducible commands are:

```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/remaining-claimed-sy.test.ts
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/census/manual-census.ts
```

Every attempt directory has `command.txt`, `output.log`, `exit.txt`,
`before.sha256` and `after.sha256`. All recorded before/after source inventories
are identical within their respective attempts. `results.json` records the
complete attempt ledger and final source hashes.

| Evidence | Result |
| --- | --- |
| `attempt-01-baseline` | 54 pass, 0 fail, exit 0 |
| `attempt-06-reproduction` | 54 pass, 1 intended census failure, exit 1 |
| `attempt-07-root-fix` | Same 55 tests pass, exit 0 |
| `attempt-08-adversarial` | 65 pass, 0 fail, exit 0 |
| `attempt-09-mutant-current-bound` | Bounding current validation at preparation misses Y; omission test fails with missing expected rejection |
| `attempt-10-mutant-members` | Removing member authentication makes member, fixed-facet and economic negatives fail |
| `attempt-11-mutant-domain` | Removing original journal-domain hash equality makes the rehashed-intent negative fail |
| `attempt-12-mutant-receipt` | Replacing canonical receipt acquisition with unchecked receipt parsing makes the receipt negative fail |
| `attempt-13-mutant-scope` | Skipping historical census and empty-current census makes both corresponding negatives fail |
| `attempt-14-final-focused` | All mutations restored; 65 pass, 0 fail, exit 0 |
| `attempt-15-manual` | PASS, exit 0; child exits `[0,0,0,0,0,1,1,1]` |
| `attempt-16-diff-check` | Scoped `GIT_MASTER=1 git diff --check`, empty output, exit 0 |

Manual artifacts are under `manual-eqooQc/`. `result.json` contains exact child
argv, stdout, stderr, exits, before/after file hashes, A/B domain hashes, B's
actual retained/new row identities, the published configuration logs, and
public load/verify/resume outcomes. `original-0.json` through `original-5.json`
preserve original bytes; `B-prepared.json` preserves the current complete
manifest. `rpc-requests.json` preserves the transport transcript.

A's preparation SHA-256 remained
`54e82f95d618e3238331c4ed6bd2e7fd7c0a2e7eeadb6074886eb7783a552bf7`.
Its journal-domain hash remained
`a7f076932a66eec1a69537d0233e9b61fb0f13ddaeb29e1e072a3df9f7a2d6a6`;
B's remained
`01ad4d6bd6e599abff5a48ab9ce32a770ffa5fab494dfa1e9f78436b9f02d060`.

The CLI's verification result has an empty independent-recipient `rows` array
because this fixture contains SY rows only. The real verification function
still reads and checks both SY configurations, originals, credits and Q/C
state; the separate changed-current-X test proves it rejects unexpected state.
No empty-recipient result is used as evidence of a completed lifecycle.

Applicable adversarial classes were exercised: malformed/rehashed history,
future-current versus pinned-historical state, unexpected current replacement,
fixed source implementation and member/economic corruption, canonical receipt
tampering, repeated validation/resume, and misleading success output. CLI
success requires exit 0, empty stderr and parsed read-only output; rejection
requires exit 1, empty stdout and the specific census error. Dirty shared
worktree safety was handled through owned-path edits and per-attempt hashes.

Timing isolation uses a fresh port-0 listener, a unique RPC environment name,
temporary directories, awaited listening, bounded child exits, and advancing
fixture headers. This is not a real-chain reorg/concurrency test. Network
failure recovery, actual transaction sending, activation economics and full
on-chain lifecycle behavior belong to integration/task 10; they were not
fabricated here.

All owned fixture servers and temporary directories were closed/removed.
`manual-eqooQc/cleanup.json` records the manual cleanup. The temporary filter
diagnostic script was removed after retaining its raw attempt output. Public
transactions, financial inputs, installations, commits and plan checkbox edits:
none.

Self-review:

1. Responsibilities remain source authentication, quotation, preparation and
   execution-domain validation; the transport fixture was factored separately.
2. Untrusted file and RPC inputs still cross existing schema boundaries.
3. The new acquisition switch has an exhaustive `never` branch.
4. No type escape, suppression or weakened test was added.
5. No defensive retry, fallback or redundant domain validation was added.
6. No single-use product helper was introduced; fixture helpers serve repeated
   A/B construction and both automated/manual consumers.
7. The missing temporal boundary has a pre-fix red proof; negatives have
   independent mutation failures. Current-state guard mutation was not attempted
   because its owner is outside this lane.
8. The existing four-argument quote API still separates input, payload,
   resolver and acquisition. Validation context replaces the old ancestor
   parameter rather than adding more positional parameters.
9. Byte comparisons protect immutability across validation/resume; they do not
   redundantly verify a setter or deletion.
10. New names describe present concepts (`census`, `historical`, `current`).
11. No product logging was added. Evidence output follows the existing JSON CLI
    style, and manual PASS is emitted only after cleanup completes.

Residual qualifications: no full operator/Forge suite or shared typecheck was
run, as requested. Native TypeScript LSP repeatedly returned
`freshness_timeout` after 3000 ms; no clean-diagnostics claim is made. JSON LSP
reported missing Biome; no installation was attempted. Parent integration must
run after sibling edits settle.

The existing quote and preparation modules remain over the skill's 250-line
ceiling (293 and 303 pure lines). The explicit cause-only lane scope takes
precedence over a broader module split. Execution-domain, preparation fixture
and execution tests are in the 200-250 warning band (218, 228, 248); a future
expansion should split by validation/fixture responsibility. No further
expansion is part of this completed census fix.
