# Empty compensation census repair

This scoped repair admits mandatory deployment initialization while retaining
the complete deployment-to-latest compensation census. It does not establish
owner-bond execution, activation, shared-gate readiness or task-10 completion.

Only these product/test files changed:

- `scripts/recovery/dtf-migration/execution-domain.ts`
- `scripts/recovery/dtf-migration/execution-domain.test.ts`

All other new files are in this evidence directory, except the requested final
`.omo/ulw-execute/dtf-conformance/owner-correction-20261115/empty-census-repair-done.json`.
The newer source-bound pricing ABI acquisition remains intact. Its existing
stale-byte, rehashed-malformed-artifact and missing-event-binding tests pass.

The actual unset-owner manifest has `pricing: null` and
`preparedManifest: null`. The saved deployment transaction is
`0x4098d83a9911e1173fa3a091c227701fd2ff1488f35aa403b902fc3626e9c258`,
at block `108944989` / `0x67e5e5d`, with block hash
`0x1c9527ca7946ab25b4f5204a486dc5fff948f953d854cc537877dc864240f1af`.
The actual receipt contains 152 logs. The proxy
`0xa10fb7436b216df934cfafaca5fddcc7bb9c2902` emits
`ThresholdsConfigured(uint256,uint256)` at log index `0x1`.

The fixture reads the exact manifest and receipt named by
`operator-empty-census-blocker.json`, plus the matching
`journal-deploy/17918fb30b629655bba3525c0d075970ad103105dd38d80270271398bdf9d238.canonical-chain.json`.
The latter supplies the recorded transaction, receipt and header, rather than
reconstructed metadata. It also reads the original owner-bond journal domain
and asserts equality with the real `loadExecution` result. All source bindings
are validated by the production loader.

Before the fix, `verifyEmptyCensus` classified every event whose name ended in
`Configured` as compensation. It therefore selected the authentic mandatory
`ThresholdsConfigured` log and rejected a compensation-empty manifest.
Attempt 02 reproduces that exact error, with 32 tests passing and the positive
initialization test failing.

The corrected function maps every existing `configurationKinds` entry to its
explicit compensation event declared by the migration interface, then adds
`IndependentAllocationIssued`. The mapping is type-checked against the existing
category union and resolves topics from the source-bound migration ABI.
Missing required ABI events fail closed. It does not exclude one special event
by name, use a suffix heuristic, disable the census, introduce policy, change
its cutoff or add a source fallback. Deployment authentication still precedes
the query; the lower bound remains the deployment block and the upper bound
remains `latest`.

The test table covers all ten admitted configuration events and independent
issuance, each at the deployment block and seven blocks later. Each probe
contains exactly one omitted compensation event. Those extra logs are synthetic
test inputs, not claimed real transactions. Mandatory initialization is replayed
unchanged from the real local-rehearsal receipt.

Commands ran from
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`:

```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-domain.test.ts
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/remaining-claimed-sy.test.ts
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/empty-census/manual-empty-census.ts
```

| Attempt | Result |
| --- | --- |
| 01 baseline | Original 10 domain tests pass; exit 0 |
| 02 reproduction | 32 pass, 1 actual-initialization failure; exit 1 |
| 03 focused green | All 33 domain tests pass; exit 0 |
| 04 singleton mutation | Requiring two logs instead of one makes all 22 omission tests fail; exit 1 |
| 05 cutoff mutation | Moving the lower bound past deployment makes all 11 deployment-block omission tests fail; exit 1 |
| 06 manual | 28 outcomes satisfy their positive/negative expectations; exit 0 |
| 07 deployment-authentication mutation | Omitting `verifyDeployment` makes the stale-header manual assertion fail; exit 1 |
| 08 final focused | All mutations restored; 33 pass, 0 fail; exit 0 |
| 09 historical/current census | 81 pass, 0 fail across the three affected files; exit 0 |
| 10 final manual | All 28 outcomes satisfy expectations; exit 0 |
| 11 scoped diff | `git diff --check` exits 0; tracked/untracked dirty state retained |

Every attempt retains its exact command, cwd, exit, raw output and before/after
source hashes. The source hashes are stable within every attempt. The domain
hash after restoring mutations matches the first green implementation exactly.
Attempt 11's compound shell redirection captured the empty diff-check output in
`output.log`; its status output was recovered verbatim from the completed
monitor PTY in `terminal-transcript.txt`. No check was rerun to hide that capture
detail.

The affected test command preserves the prior historical A/current B invariant,
X/Y omission negatives, empty-current-category rejection, signed-domain
authentication and repeated resume. No prior tests were deleted, skipped or
weakened.

`manual-qStpyA/result.json` is the final manual proof. The program invokes the
actual owner-bond `preflightOperation`, which reaches the real empty-census
function, using the original loaded domain. It does not invoke a transaction
send or claim a completed owner bond. It demonstrates three accepted empty
preflights (initial, repeated and restored), 22 omitted-compensation rejections,
malformed census RPC rejection, stale deployment-header rejection, and missing
required issuance ABI rejection.

The transport is an explicitly synthetic, isolated loopback using the existing
HTTP fixture. Its deployment facts are the exact archived transaction/header/
receipt. Its range census is limited to those saved deployment logs plus
separately injected omission probes. With Anvil stopped, this is not a live
current-chain census or a fresh chain attestation.

The original domain hash remains
`be76538efae814c63f22d9c99fd6878734da1e3b76d135df3b3c7fdf02428289`.
`manual-qStpyA/source-bindings.json` records before/after hashes and lengths for
41 original files, including manifest, receipt, both journal domains, canonical
chain evidence and all referenced source artifacts. They are unchanged.
`rpc-requests.json` records the actual transport requests. There were zero
contract calls, nonce requests or sends.

Applicable adversarial classes:

- Malformed input: census RPC schema rejection; missing required event ABI;
  preserved existing stale and rehashed pricing artifact tests.
- Stale state: actual deployment-header mismatch rejects before census
  admission, with a sensitive mutation proving the dependency.
- Dirty worktree: pre-existing modified/untracked files were preserved; only
  the two owned product/test files changed, and mutation restoration is hashed.
- Misleading success: manual assertions must all complete and cleanup must
  succeed before the PASS line is emitted; mutant 07 exits 1 with no PASS.
- Repeated validation and timing: repeated empty preflights, unique port-0
  fixture listeners, awaited readiness, bounded monitored processes and
  deterministic saved facts.

All fixture providers, HTTP listeners and temporary directories were closed or
removed. Each manual run, including the intentional failed mutation, retains
its cleanup receipt. The original RPC alias is restored immediately after
provider construction; original manifest/domain bytes are never rewritten.
No Forge, Anvil, public RPC, installation, commit, plan checkbox, readiness
marker or shared integration gate was used.

Self-review: responsibilities stay within domain census validation; existing
file/RPC schema boundaries remain; category coverage uses an exhaustive typed
mapping; no type escapes, defensive retries, one-use product helpers, parameter
bloat, redundant setter verification, negative names or production logging
were added. The new tests have a pre-fix failure and independent mutation
failures. Both product/test files are below 250 pure lines (229 and 242);
they are in the warning band, so a future expansion should split by
responsibility. Evidence helper/manual files are 103 and 83 pure lines.

Limits: shared full-operator checks and typechecking are deferred to parent
integration after both writers finish. Native LSP attempts returned freshness
timeouts, so this lane makes no clean-diagnostics claim. The existing adjacent
prepared-record `verifyConfiguration` path in sibling-owned `execution-state.ts`
also used suffix selection when inspected; that path was not tested here
against the saved deployment initialization logs or changed by this lane.
This is an unverified source observation for the parent, not another claimed
reproduction or an extension of this repair.
