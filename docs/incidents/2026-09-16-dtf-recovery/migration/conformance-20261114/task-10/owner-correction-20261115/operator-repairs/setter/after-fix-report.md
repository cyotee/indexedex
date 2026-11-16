# Setter receipt repair after producer authorization

The narrow repair is implemented and its focused checks pass. This is not
task-10 acceptance or proof of a fresh Anvil transaction.

The earlier `blocked-report.md`, raw before-state outputs, and original replay
script remain historical evidence. The previous claim was archived verbatim as
`setter-repair-blocked-before-producer-authorization.json` before replacement.

## Cause and change

The actual successful setter emits the pricing interface's event, which the
generated migration and allocation interface ABIs omit. The producer also
omitted the separate pricing artifact from its execution source list.

- `scripts/recovery/dtf-migration/rehearsal-data.ts:72` now binds the actual
  generated pricing interface artifact as `pricing-abi` in new manifests.
  Comparing with the captured starting source shows exactly this one additive
  line; all 22 authority inputs and every other source remain unchanged.
- `execution-domain.ts:61-62` loads that optional artifact with the existing
  source binding validation and `readBoundFile` reader, including bundle
  resolution. It neither looks beside an artifact nor invents an ABI.
- `execution-state.ts:51-65` requires the binding for setter verification and
  integrates its Interface into the existing receipt decoder. Re-encoding a
  decoded pricing event must exactly reproduce its topics and data. This
  rejects extra topics or data that a permissive ABI decode could ignore.
  The existing exact proxy emitter and exactly one expected-book event checks
  remain in force. Other receipt authentication, ordering, transaction/block
  checks, and unknown-event handling remain in place.

The optional loading preserves admitted operations whose verification does not
depend on the pricing event. The old fixtures intentionally omit this binding;
their existing configuration/history/issuance tests still pass.

No edits were made to `execution.ts`, `execution.test.ts`, generated artifacts,
the witness hash pin, old runtime files, plan checkboxes, or parent readiness
markers.

## Evidence and results

`after-fix-evidence.json` records exact argv/cwd, observed exits, raw stdout and
stderr paths and hashes, final source hashes and sizes, diagnostic results,
historical integrity checks, and cleanup.

| Evidence | Observed result |
| --- | --- |
| Original saved receipt before repair | Production rejection reproduced, exit 1, retained as `manual-before.*`. |
| New synthetic positive before repair | Exact generated pricing event rejected by production, exit 1, `synthetic-before.*`. |
| Focused after-fix tests | Exit 0; 18 tests passed, `focused-after.*`. |
| Manual after-fix replay | Exit 0; saved historical domain still rejects, new synthetic bound context accepts, 12 independent corruptions reject, `manual-after.*`. |
| Removed binding/strict-encoding guards mutation | Exit 1; binding requirement and extra-topic/unexpected-data regressions failed, `guard-mutation.*`. |
| Restored final focused tests | Exit 0; 18 tests passed, `focused-final.*`. |
| Test junk audit on the two changed test files | Exit 0; no findings, `test-audit.*`. |
| File-scoped TypeScript audit | Exit 2; required TypeScript API cannot be resolved from caller project, `typescript-audit.*`. No install performed. |

The exact focused argv was:

```text
bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-domain.test.ts ./scripts/recovery/dtf-migration/execution-state.test.ts
```

The exact requested manual argv was:

```text
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/setter/manual-receipt.ts
```

The temporary mutation was observed in the actual production file before its
run. Restoring it reproduced SHA-256
`58881534f693274494b8cdb4e87027208fe409024fbc9d228dd0d0f54f80ae67`,
identical to the passing pre-mutation implementation. No mutant remains.

## Historical and synthetic boundaries

The manual channel loads the exact saved manifest, journal, signed intent,
canonical transaction, receipt, header, and logs. Their original bytes remain
unchanged, with before/after SHA-256 values in the evidence record. The real
saved event and trace return still diagnose the original expected book:
`0xe7f20b629b1814a326fbcf0d71509cf6fa97fd347db8a00eeae32ded0fbfd531`.

Production verification of that original domain now explicitly rejects with
`missing bound pricing event ABI`. It is never made to pass by adding a source.
The diagnostic standalone decode uses the real generated interface and is
labeled as diagnostic rather than source-bound historical acceptance.

Positive verification uses `setter-context.ts`, built on the existing
`executionFixture` infrastructure. It creates a new synthetic manifest,
copies and fingerprints the real generated pricing artifact, and creates its
own new fixture signature and intent domain. Its synthetic expected book is
`0xe8e8e19b841d980ed2fdc2b3ae7d731c9325c956a451a717ceeef97fa589919c`.
Its mocked canonical wire transport drives the production receipt and completion
functions. This is no EVM transaction and no replacement for the parent's later
fresh Anvil proof.

## Probe accounting

- Wrong book, emitter, topic, and missing event each reject independently.
- Missing indexed book, extra topic, unexpected data, and duplicate event each
  reject independently.
- Wrong transaction identity, block identity, transaction index, and log order
  reject through the unchanged canonical receipt authentication.
- Unknown proxy events remain ignored; the accepted event list stays exact.
- A new context without `pricing-abi` rejects setter verification even when
  its supplied event bytes came from the generated artifact.
- Altered bound artifact bytes reject on their recorded binding. Updating the
  surrounding source hash and size to match malformed `{}` still rejects ABI
  parsing. The existing rehashed historical-intent-domain rejection test passes.
- Existing stale journal, same-block replacement, historical configuration,
  and immutable A-issuance/current B-configuration tests pass unchanged.
- Misleading success is controlled: successful receipt status and a standalone
  event decode do not cause an unbound old domain to pass. Baseline green tests
  were not labeled as repair proof.
- The raw dirty-worktree snapshot from the initial investigation remains
  retained. Starting file snapshots and the one-line producer comparison delimit
  this task's changes within that dirty tree. No unrelated work was reverted.

UI/accessibility/responsive/browser probes are inapplicable because this repair
changes no rendered surface. Public-network, wallet-permission, deployment,
restart, and chain rollback probes are inapplicable to this isolated offline
receipt repair; no node, wallet transaction, or public RPC was used. Load and
throughput probes are inapplicable to the fixed artifact/receipt interpretation
change. Canonical ordering and malformed-input probes are covered directly.

## Review and remaining verification

The producer owns manifest construction; the domain loader owns bound ABI
loading; the existing state module owns completion interpretation. No parallel
decoder, production helper, new authority, type assertion, `any`, suppression,
fallback, retry, or logging framework was introduced. The reusable evidence
fixture serves domain tests, state tests, and manual QA. All external manifest,
artifact, intent, and receipt data use existing parsers or local Zod schemas.
No tagged variant behavior changed. The transport rejects every unsupported
method. New helper and override signatures stay at two parameters or fewer.
There are no redundant setters/getters, destructive checks, or negative-form
names in the change.

Tests protect observable completion acceptance and canonical rejection. The
before-state failure proves the missing ABI regression; the deliberate guard
mutation proves the malformed encoding and missing-binding negatives. Existing
fixtures do not supply this separately bound event, which is why these new
cases are needed. No production seam was added for tests.

Pure nonblank/non-comment line counts are 219 for the domain loader, 222 for its
tests, 416 for state, 290 for state tests, and 424 for rehearsal data. The latter
three files already exceeded the generic size ceiling before this task. The
explicit narrow repair and file ownership constraints take precedence over a
broader structural refactor. The evidence scripts are 108 and 75 lines.

Native file diagnostics reported no errors for the domain loader, state,
rehearsal data, and manual script. Freshness timed out for the two test files and
the shared synthetic fixture, so those diagnostic results are not claimed clean.
Full operator/type checks remain deferred as instructed while the sibling repair
has separate ownership. The unavailable audit dependency was not installed.

All monitored processes exited; temporary fixture servers, providers, and
directories were closed or removed by their existing cleanup paths. Evidence
remains retained. No Forge, install, commit, public RPC, Anvil, or transaction was
run. Independent verification and the fresh parent-owned task-10 rehearsal remain
separate gates.
