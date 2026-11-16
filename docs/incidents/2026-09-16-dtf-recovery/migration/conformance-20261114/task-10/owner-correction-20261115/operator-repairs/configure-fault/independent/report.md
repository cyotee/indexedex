# Independent configure interruption verification

Verdict: **confirmed**. Failure class: **none**. Confidence: **high for the scoped CLI repair**.

This confirms only execution.ts and execution.test.ts's configure interruption repair. It does not accept task 10, parent readiness, the combined operator/type gate or a fresh real lifecycle. The setter has its own earlier verdict. No settled test was rerun, source edited, install performed, Anvil resumed, transaction sent, RPC contacted or child delegated by this verifier.

## Failure and narrow repair

The task 10 blocking-repair scope admits this disjoint lane. The original predicate interrupted four named economic methods and excluded every finite configure operation. attempt-02-regression-red.log reproduces the failure through the real CLI: the child returned state complete with an authenticated configure completion and no SIGKILL, so the regression fails at the expected signal assertion. This is synthetic transport reproduction of real CLI behavior, not an EVM receipt or historical transaction claim.

execution.ts:268-272 now includes record.stage === configure and requires status 1 before the existing SIGKILL, after the canonical mined observation and before reconcile persists completion. execution.ts:141-143 still requires local mode and synthetic-local purpose. Rpc.guard additionally requires explicit local instance, fork, loopback endpoint and development signer. There is no arbitrary calldata method or broader public fault mechanism.

Reversing only the size comment and predicate in memory yields the original production hash 735ac6fd772b4ddbb1c57ad476145082d5654066c3ac68015e10672820edbd15. Removing only this repair's test additions yields original test hash b5b6865d86245b76d55475a0828c6a5e7dc0318c819f5a829463fbc621b14fdd. Both match attempt 01. The existing dirty-tree implementation was preserved; the whole HEAD diff is not assigned to this repair.

## Durability and recovery trace

execution.ts:261 persists the signed intent before the subscription and send. subscribeReceipt authenticates canonical receipts against block/header/log identity. The new fault occurs at lines 268-272, before reconcile at line 274. A killed child leaves the intent, immutable domain and run record, with neither receipt completion nor terminal success.

On resume, all prior intents are authenticated and reconciled before another nonce can be assigned (execution.ts:175-190). reconcile at lines 89-115 checks canonical transaction hash/signer/target/calldata/nonce/block/value, invokes the unchanged transaction-local captureCompletion checks, compares any saved completion and only writes a missing completion. The operation loop skips completed records at line 193, before preflight, nonce allocation and wallet signing. Consequently an already-mined A configuration recovers from its own receipt even if the latest book, quote or configuration has changed; it does not silently send A again against B.

Journal still enforces writer locks, immutable domains, unique nonce claims, exact intent/receipt bindings and durable create-only files. A dead SIGKILL writer can relinquish its lock only after ESRCH. A missing receipt plus an existing transaction is ambiguous and cannot resend; neither a completed receipt's disappearance nor invalid canonical data can become a success. Successful receipt status alone does not bypass full completion authentication on recovery.

## Retained evidence and provenance

All final product and evidence helper hashes match the claim. The manual source-fingerprints.json also matches current execution, domain, state, RPC, plan, journal and shared fixture bytes. Exact hashes and 43 raw evidence file fingerprints are in verification.json.

The original producer process transcript is /Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1dfd8/sessions/st_01a1dfd8/2026-11-15T15-33-41.800Z_b361903c-456d-428a-a73e-fb78808ca8ff.jsonl. I read its actual monitor launches and completion notices to bind exact commands, cwd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1, source hashes, raw output and exits. Launch record 8be87cfa proves the quoted attempt-02 command was bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution.test.ts -t 'mined independent configure'. The old header printed the filter as separate shell-expanded lines; that header alone is not argv evidence. Record 05c7c649 launches the full owned suite and record d215df28 launches the corrected manual run. Completion notices independently report their actual exits. Tee pipelines propagate PIPESTATUS[0]; the whitespace pass used a separate unmasked command.

| Evidence | Result and meaning |
| --- | --- |
| attempt-01-baseline.log | 22 pass, exit 0 before repair; not repair proof. |
| attempt-02-regression-red.log | Exit 1; configure completed instead of promised interruption. |
| attempt-04-configure-matrix.log | Seven configure cases pass after fixture setup repairs. |
| attempt-05-owned-suite.log | Exact bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution.test.ts: 38 pass, zero fail, exit 0, Bun 1.4.2. |
| attempt-09-manual.log | Exact bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/configure-fault/manual-fault.ts: exit 0. Actual child argv/code/signal/output and request transcripts retained under manual-attempt-ncqQ9Y. |
| attempt-07-test-junk.log | Exit 0, no findings. |
| attempt-11-whitespace.log | Exit 0, independent unmasked scoped diff check. |
| attempt-10-no-excuse.log | Exit 2, cannot resolve required TypeScript API. Not a clean typecheck. |

attempt-03's three errors were missing evidence fixture getters/ordinary NFT handling, not repaired production behavior. attempt-06's tuple-conversion failure was in the manual evidence script. Their original logs and manual-attempt-ucxw15/failure.json remain intact. No passing summary is used to erase them.

Seven positive fixture categories are independent, separate NFT contributions, ordinary NFT, weighted liquid, weighted SY, custody SE and claim vault. All exercise the production configure plan, real child-process signer/subscription/journal and two resumes retaining the fault flag. Other finite configure variants are included by the stage predicate but are not independently run by these seven cases; broader source-family lifecycle proof remains task 10.

## Independent manual record calculations

For each positive I independently recomputed the transaction hash from saved signed bytes, domain hash from interrupted journal domain, and completion intent hash from the exact intent. Both saved completions equal the canonical receipt and each other. Each crash has code 137/SIGKILL; each of the two resumed children has code 0 and one matching original receipt. The crash directory record contains exactly one intent and no completion or terminal success; the manual assertions count one persisted completion after repeated resumes.

| Case | Original hash | Nonce queries and send |
| --- | --- | --- |
| Independent | 0x1234d1495832267b0eed77c28e219f666416d23fd3d441f4324e6aa16d9fa750 | Zero-based request indices 43 and 44 query pending/latest; index 49 is the sole send. |
| Separate NFT contributions | 0x520f748d63c492eebf3b5de88798f5e0b5fcb10af477277e64821156ac063cfd | Indices 44 and 45 query pending/latest; index 50 is the sole send. |

The two nonce requests precede the original send. There are no later nonce queries or sends anywhere in either complete request transcript. They are initial pending/latest safety reads, not new allocation during recovery. The evidence adapter's signed counter counts accepted signed transaction objects; it is not separate instrumentation of wallet signing calls. Immutable signed intent bytes, one raw send and unchanged counts across two resumes support the actual claim without overinterpreting that counter.

The manual changes latest pricing/quote and replaces latest configurationId with h(999), while preserving receipt-block state. Completion authentication reads the saved receipt block, leaves the replacement unchanged and retains the original hash. This supports recovery independence from latest state; it is not same-block EVM overwrite proof.

Manual wrong-hash, malformed receipt and malformed intent cases each record original SIGKILL followed by exit 1 with AMBIGUOUS or INPUT, with only the initial send/two nonce reads. Simulation rejects with DOMAIN and zero sends/nonce queries. Automated cases additionally cover missing canonical receipt, reverted receipt, wrong canonical nonce, wrong receipt-block state, operational-purpose rejection and first-run reverted status without misleading interruption. Existing source/domain/foreign-intent/lock tests remain passing.

## Adversarial classes and limitations

- Reproduced failure, misleading success, stale state, malformed data, canonical identity, interrupted process and repeat-resume idempotence: applicable and covered at the real CLI boundary with synthetic local transport facts.
- Source/artifact identity and dirty tree: applicable; hashes match final evidence and in-memory baseline reversal. Existing rules and 22 authority roles are untouched by this disjoint repair.
- Resource cleanup: children were awaited, adapter.stop(true) and fixture.close are awaited; both manual fixture roots are absent. Producer failure cleanup records are retained. No resources were started by this verifier.
- UI/accessibility/responsive/browser and throughput/load: inapplicable to the scoped CLI predicate repair.
- Public RPC outage/wallet permissions, broader reorg, system power loss, chain rollback, actual Anvil/proxy configuration and other source variants: not proved by this repair and remain outside this verdict. Real process SIGKILL is proved; actual chain effects are synthetic fixtures.

No concrete in-scope defect found. Smallest required fix: none. New behavior fits the existing ordered transaction state machine without a helper, decoder, retry, fallback, logging framework, type assertion or test seam. Production boundary parsing, discriminated modes and domain/receipt invariants are unchanged; new negative variants switch exhaustively. Tests guard behavior, failed before repair, and assert persisted outputs, signals and replay counts rather than source prose. Production/test pure LOC 277/328 exceed the generic ceiling but carry explicit narrow-scope SIZE_OK reasons; structural rewrite is outside this repair. Transport is 206 and manual 109 pure LOC in the producer measurement.

Both strict whole-operator TypeScript commands and the full operator suite are the separately assigned combined-tree gate. This report does not claim them run or accepted. Later LSP freshness timeouts are not clean diagnostics. The unavailable audit is recorded exactly, not waived into a pass. Fresh real lifecycle remains required. Rejected witness-pin work, setter files, historical evidence and all old producer records were preserved.
