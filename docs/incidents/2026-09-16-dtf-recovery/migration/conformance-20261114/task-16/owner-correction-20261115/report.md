# Task 16: offline funding-evidence transport

The transport defect is fixed. This is an executor claim for task 16, not independent verification, donor approval, an allocation, or a task 10 lifecycle result.

## Cause and contract

The existing authority input admitted exactly 22 sources and no additional field. `walkReferences` treated a bare `{path, sha256, bytes}` reference as a JSON historical document. Putting the retained transfer CSV in the bundle without a reference would fail `complete()`. The real CLI reproduced the authority-input rejection before any export in attempt 04; the new regression reproduced it in attempt 05. The unchanged 38-case suite passed in attempt 01. This was a transport contract defect, not evidence of global DTF scarcity.

The authority v1 input now optionally admits `rehearsalFundingEvidence`. It extends the existing strict `source` schema, including its path, SHA-256, size, and provenance, with:

| Field | Required value |
| --- | --- |
| `id` | `rehearsal-funding-transfers` |
| `purpose` | `synthetic-local` |
| `format` | `transfer-csv` |

All seven source/evidence fields are required when the optional reference is present. The 22 authority roles retain their length, distinct role identities, and source contract. Previously admitted inputs omit the field and continue to work; the legacy and extended cases both relocate twice in the bundle suite.

The existing traversal recognizes only this strict raw-evidence shape, loads its bytes, and applies the existing byte verifier. Existing content-addressed export, reference lookup, read, complete-membership check, and materialization carry the file. The loader and materializer return its contained path and the same metadata separately from the authority sources. There is no filesystem fallback, extra unreferenced object, JSON parse fallback, or new provenance service. Bare historical FileRefs still require JSON. The source, preparation-input, and accepted-configuration schemas reject using the tagged raw evidence in their roles.

The three production edits are `bundle-files.ts`, `bundle.ts`, and `bundle-materialize.ts`; regression coverage extends the existing `bundle.test.ts`. No schema, CLI, rehearsal, lifecycle, or Solidity source was changed by this task.

## Evidence

All paths below are relative to this directory. Every numbered attempt has its exact argv, cwd, executable identity, runtime version, source fingerprints, raw stdout/stderr, and actual exit/signal.

| Attempt | Result |
| --- | --- |
| 01 baseline tests | 38 passed, zero failed; exit 0 |
| 02 native setup | Copied the original 22 authority sources from the retained task 10 bundle and the retained task 2 CSV; exit 0 |
| 03 initial status | Recorded existing dirty/untracked work; exit 0 |
| 04 baseline export | Expected INPUT rejection of `rehearsalFundingEvidence`; exit 1, no success stdout |
| 05 red regression | New two-location funding test failed at the same boundary; exit 1 |
| 06 transport tests | All 10 new cases passed; exit 0 |
| 07 guard mutation | Removing the new ID/purpose restrictions caused both rejection tests to fail with missing expected rejection; exit 1. Production bytes were restored exactly. |
| 08 prescribed bundle tests | 48 passed, zero failed; exit 0 |
| 09 prescribed operator types | Shell expanded all 86 TypeScript paths; exit 0, empty stdout/stderr |
| 10 public export | Actual requested `bundle-export` invocation; exit 0, `offline-integrity-only` stdout |
| 11 helper types | Exit 2: the evidence helpers used Bun globals without installed Bun type definitions. No product error. |
| 12 helper types | Helpers changed to Node-compatible metadata/path APIs without installing dependencies; strict check exit 0 |
| 13 manual transport | Two fresh locations, 46 exact byte comparisons, 25 controlled rejection results; exit 0 |
| 14 randomized transport | Seed 16115, all 10 new tests passed in a different order; exit 0 |

`manual/origins.json` binds every copied authority to the original retained bundle and source identity. `manual/transport-results.json` records each comparison and rejection. Both relocated bundles contain the original 22 authority role bytes and the complete raw CSV, with native copies renamed out of reach before either load. The original retained CSV remains SHA-256 `c840d060c5c7119a1f4777730d726fc0e0390e87ed3190ea0b4b841e99417939`, size 4535122 bytes. The blocker records 2522 DTF transfer rows; this task transports that lead without selecting a candidate or validating a financial dataset.

The manual run rejected byte tampering, absent declared and physical evidence, extra physical and declared-but-unreferenced items, forged hash and role identity, wrong purpose and size, every omitted required evidence field, raw-evidence use as an accepted-configuration reference, CSV use as JSON history, stale bundle binding, and incomplete exports. Every corruption failed before output materialization. No RPC or signer was constructed by the offline QA; unit fixtures recorded no nonce or send calls.

The helper compiler failure and all earlier donor-blocker records remain intact. The native copies are retained as `manual/native.unavailable`; this is deliberate QA evidence, not an active native fallback. Completed exports, relocations, and negative cases remain as evidence.

## QA classes and cleanup

| Ultraqa class | Disposition and evidence |
| --- | --- |
| Malformed input | PASS. Manual omissions identify the exact failing evidence field; ID, purpose, digest, and size corruptions reject. |
| Prompt injection | Inapplicable. Transport treats source text as bytes; it has no model, instruction interpreter, command construction from source text, or execution of source content. |
| Cancel/resume | PASS for the file-transport contract. Root-only and data-written partial exports fail to load; re-export to either existing root rejects with EEXIST. This does not claim transactional resume or crash durability. |
| Stale state | PASS. Both relocations work without native copies; stale expected manifest identity and changed contained bytes reject. |
| Dirty worktree | PASS. Initial dirty-file hashes and task-only diffs preserve prior work. Only the four scoped source files changed; prior evidence and plan remain untouched. |
| Hung or long commands | Inapplicable to new transport behavior. No network wait, service, Forge build, or long external command was added. Local tests had the required 15000 ms per-test bound and monitored real process exits. |
| Flaky tests | PASS for exercised isolation/order cases. Existing fixture cleanup is reused; all 10 new cases pass with fixed randomized seed 16115. No probabilistic flake-rate guarantee. |
| Misleading success output | PASS. Actual exit codes and raw streams are recorded. Baseline export has no success stdout; successful export explicitly says offline integrity. Rejection assertions fail under the guard mutation. No lifecycle success is inferred. |
| Repeated interruptions | PASS for modeled filesystem states. Each partial-export state rejects two reuse attempts. Only owned partial directories and their retry input are removed. No actual process-kill injection is claimed. |

`manual/cleanup.json` records removal of both partial-export directories and the temporary retry input. Test fixtures close their own servers and remove their unique roots. The observed current-suite temporary root disappeared, and the randomized run left no newly listed fixture roots. All command monitors completed; no task-owned node, signer, service, port, or background command remains. Unrelated pre-existing temporary directories are left alone.

## Review

1. Responsibility: bundle files own authenticated file transport, the bundle module owns template handling, and materialization owns fresh local output. Each production file is below 200 pure lines.
2. Boundary purity: the new source shape is parsed with the existing Zod source schema plus literal restrictions; raw file integrity stays with the existing byte verifier.
3. Variants: the new corruption dispatch is an exhaustive switch. Kind comparisons elsewhere are test assertions, not production variant dispatch.
4. Escape hatches: no casts, non-null assertions, suppressions, or untyped domain values were added. The source lookup has an explicit schema-derived type.
5. Defensive layers: no fallback, retry, duplicate validator, or error-swallowing layer was added.
6. Helpers: the production change adds no helper. The new test fixture serves multiple cases; the evidence recorder and rejection helper have multiple uses.
7. Tests: the public transport boundary owns these regressions. Removing reference support loses the CSV, removing ID/purpose checks accepts wrong use, and existing byte/membership guards reject the transported raw source corruptions. Existing tests did not cover optional authority evidence. No production test-only seam was introduced.
8. Parameters: all added functions/helpers have at most three arguments.
9. Redundant verification: byte comparisons and absent rejected output are explicit acceptance/security assertions. Cleanup does not recreate or re-query deleted partial exports.
10. Naming: new domain names describe positive identities and purposes.
11. Logging: production logging is unchanged. Evidence-only command output records results, not financial conclusions.

The existing test file is 554 pure lines after this addition. The programming skill's generic split rule was not applied because the owner explicitly limited test ownership to the existing `bundle.test.ts` and forbade unrelated cleanup. No SIZE_OK suppression was inserted. The prescribed strict compiler passed. LSP diagnostics were clean for the final test annotation and initial final production bytes; later mutation/restoration notifications sometimes timed out, so no fresh whole-tree LSP-clean claim is made.

## Exact remaining task 10 integration

1. At `scripts/recovery/dtf-migration/rehearse.ts:65-66`, after loading the authority bundle and before starting the node or funding work, require the declared `authorities.rehearsalFundingEvidence` for the new portable funding path. Its absence on an old bundle is compatible transport, not permission to invent a source or silently reuse the NFT 3 funding path.
2. Read its contained bytes through existing `readReference(authorities.rehearsalFundingEvidence, authorities.reference)` in `provenance.ts`. Parse the CSV through the existing `parseCandidateCsv` in `candidate-input.ts:84`. Preserve row provenance and deterministically enumerate candidates from DTF transfer rows. Do not interpret this raw CSV as a preparation manifest or append it to the 22 authority-role array.
3. Recheck balances, token identity, the canonical block 108944663/hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, and all source/eligibility exclusions at the pinned fork. The earlier blocker observations are leads only; a hash is integrity, not donor eligibility. Task 10 owns deterministic selection and the actual local transfer.
4. Replace the setup block at `rehearse.ts:114-125` that currently claims and liquidates NFT 3 principal to obtain 10000 DTF. That lifecycle change is intentionally outside task 16. Continue passing only `authorities.sources` to `bootstrapManifest` at `rehearse.ts:147`; carry funding evidence separately in the rehearsal's setup receipts.
5. Run the complete remaining task 10 lifecycle and negative scenarios with fresh evidence. This task ran no rehearsal, selected no donor, issued no award, performed no chain allocation, and sent no transaction. Task 7's existing independent verdict is retained, not replaced.
