# Task 3 independent verification

Verdict: **needs-fix**. Failure class: **harness**. Confidence: **high**.
The producer explicitly reports blocked and acceptance_met:false. This is an
incomplete evidence delivery, not a demonstrated product defect. Tasks 6 and 9
must not consume it as completed authenticated source work.

## Scope and identity

All commands used cwd
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
No producer, dependency, archive, primary checkout or retained worktree file was
modified. No delegation, installation, RPC, public transaction or Git write ran.
Read CLAUDE.md, all four applicable assistant rule files, the complete task 3
assignment and plan aliases, producer DoneClaim and dependency receipts.

Plan SHA-256:
`31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683`.
`GIT_MASTER=1 git -C "$W" rev-parse HEAD` exited 0:
`c33f70683cbaabfedc2dbce1142fdd65660d4cf3`.

## Actual diff and document inspection

Both commands exited 0 with empty stdout/stderr:

```sh
GIT_MASTER=1 git -C "$W" diff -- docs/incidents/2026-09-16-dtf-recovery/migration/source-manifest.json docs/incidents/2026-09-16-dtf-recovery/migration/source-route-matrix.md docs/incidents/2026-09-16-dtf-recovery/migration/recovery-route-disposition.md test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacyLpExit.t.sol
GIT_MASTER=1 git -C "$W" diff --cached -- docs/incidents/2026-09-16-dtf-recovery/migration/source-manifest.json docs/incidents/2026-09-16-dtf-recovery/migration/source-route-matrix.md docs/incidents/2026-09-16-dtf-recovery/migration/recovery-route-disposition.md test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacyLpExit.t.sol
```

`GIT_MASTER=1 git -C "$W" status --short --untracked-files=all` exited 0.
The three document paths and task-3-done.json were untracked. The complete output
was retained in the evaluator; its 9,938,608 bytes were too large for a useful
inline listing. Scoped entries were separately extracted and inspected. Empty
tracked diff therefore does not establish unchanged documents or a clean tree.
No producer before-document snapshot or patch exists in its receipt: it claims
only the blocked DoneClaim write. All three complete delivered documents and both
complete permitted fork files were inspected, rather than running a prose test.
An authenticated before/after remediation comparison cannot be established.

Raw file SHA-256 bindings:

| File, relative to migration documentation unless otherwise noted | SHA-256 |
| --- | --- |
| source-manifest.json | 55117479ecb52b3e334a988a53a62ec73c11de4b808bd2ccf5d2d07d783126bc |
| source-route-matrix.md | a81ac2729daa2103d8ca3ecd35ceb0badba19ab376dbfee82b371722ff4efff4 |
| recovery-route-disposition.md | 9279cc9cf3d5adcdbdfef56ef7ce376f0d080179a30a6c468128b86b5b3b2ae4 |
| K/MigrationLegacySources.t.sol | 68e150aad609dc51a93720418e1550015447f7b12197c30bc7753754f5ff5eac |
| K/MigrationLegacyLpExit.t.sol | aceb6d00010b66661cd2fefef5b9f8ee012ce654244ddc7f2ba4ea0bb388aae4 |

K is the plan's fork migration test directory. Hashes were computed from full
raw bytes with `new Bun.CryptoHasher("sha256").update(bytes).digest("hex")`.

## Happy boundary: authenticated facts versus incomplete indexes

The manifest records chain 4663, block 108944663 and header hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Its weighted-nft, weighted-receipt and earlier-receipt runtimeCodeHash fields
remain null. Each source object has category/address/units/surrender/recovery/
conditions/runtimeCodeHash only. The route matrix still provides high-level
routes, not exact delegated selectors/facets, ABI schemas, per-route unit
equations and linked surrender/rollback witnesses. No authenticated deployed
initialization/acquisition conclusion for earlier IDs 0, 1 and 2 is delivered.
The current `MigrationLegacyNftLib.sol` preview guard `tokenId_ < 3` and the
reserved-ID rejection loop in MigrationLegacySources.t.sol cannot prove those
historical roles; the plan expressly excludes that inference.

Independently authenticated two existing archive runtime identities without
network access or following node_modules:

```js
const archive = JSON.parse(await fs.readFile(absoluteArchivePath, "utf8"));
await Bun.$`cast keccak ${archive.runtimeBytecode.onchainBytecode}`
  .cwd(W).nothrow().quiet();
```

`cast` resolved to `/opt/homebrew/bin/cast`. Exact argument is the unmodified
`runtimeBytecode.onchainBytecode` field of each named archive below. Each command
exited 0, stderr empty, with the following stdout:

| Archive under b2-public-exit-probe-20261113 | Raw archive SHA-256 | cast output |
| --- | --- | --- |
| source-0x81fb72511016b42437fe1ac2d5bdb0ba82f14a35.json | 4d81f7bb447b176e85081631fa2678ccf7849bd5da0c69d0af8533e80542e78f | 0xca224a1792b0b9339c1c5c999c4d5e99bd33f25f8387da864d6eabb4d1d6b398 |
| source-0x1b7a7bc9044642c4e42e64f805f6400d75ad2c16.json | 834f55f3211fcf78b42e04517117d2111599f213bd9c546cfe17b1020f44797e | 0xe5f44175a8c16c705c2c9e5e68b2c3efe842ce694c5e585d2211947802b10d84 |

The earlier archive reports chainId 4663, runtimeMatch match; the weighted one
reports chainId 4663, runtimeMatch exact_match. These are archived verification
metadata, not fresh independent chain attestations.

Earlier flattened source lines 7632-7639 enforce owner-only liquidity when
restricted; lines 14414-14416 apply that guard; lines 14724-14751 guard all three
withdrawal methods. Weighted archived
`contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol:18-26`
permits removal by the current fee recipient or owner when restricted.
Thus the W-P exception must not be generalized to E-P.

MigrationLegacyLpExit.t.sol pins the header, resolves the earlier withdrawal
facet, compares the above runtime hash, and asserts NotOwner before/after
fee-recipient change and one-year advance with holdings/supply unchanged.
It also asserts InvalidRoute for parent intake after local enablement.
Its current file hash matches the corresponding final-source-20261113.json
entry. This supports reusing that source-bound historical test definition;
it does not supply a new task-3 passing process record.

Permanent E-P custody additionally requires parent claimLiquidity, NFT
forwarding and collector-route exclusion bindings. The disposition names
source line ranges and a historical monitor identifier, but task 3 supplies no
new complete raw evidence index for those bindings. Owner guard evidence alone
cannot close every possible forwarding route.

## Failure boundaries and adversarial classes

**stale_state: detected.** Direct current reads still show ready.status
needs-fix and task-2-verdict.verdict needs-fix. Their raw hashes are respectively
`e6043fc75e0b4f6dadc601339743a1492a41aaa77c6015e949329a19035a5a6d`
and `a80cdb9cf9042725c6a4d9763956e701ce5b858a1972e075e2b1eae64398a58a`.
However, lstat/readdir now find lib/crane as a populated ordinary directory and
both helper paths have appeared. Claims of an empty Crane directory or missing
helper files are historical observations, not current reproduced blockers.
The current recorder's complete text accepts only hermetic/fork/operator;
inventory/delivery behavior is still absent. No claim is made that its typecheck
still has the earlier missing-file failure.

**dirty_worktree: detected.** Full actual status included extensive untracked
recovery material. The scoped documents are untracked. No clean-state assertion,
staging, removal or unrelated-content modification occurred. This verifier does
not claim an exhaustive unrelated-file byte audit.

**misleading_success_output: rejected.** DoneClaim presence, manifest status
final-independent-review-pending, monitor identifiers and aggregate counts do
not establish acceptance. The producer receipt is blocked, acceptance_met:false,
commands_executed:[]; raw SHA-256
`6f2380d5ba28ea6fe7175fb1ee2ef371a44f3ea9d19f0807303596bdfab9c380`.
The inspected b2 results.json retains an actual exit-1 TransferFromFailed
attempt; se-results.json retains a dust slippage failure and separately
qualified later successes. Those historical failures are not evidence of
universal permanent inability. Current disposition explicitly supersedes
earlier blanket conclusions; both historical and current records stay intact.

**runtime-integrity negative: incomplete.** An in-memory deliberately wrong
expected hash (32 zero bytes) was compared to the actual earlier archive runtime
hash above and produced false. Archive bytes were never changed. This confirms
the mismatch, not the required inventory helper rejection: no implemented
inventory mode was available in the inspected delivered recorder. No fake
passing fixture test was substituted.

**source-wallet/invalid-ID/unauthorized-exit negatives: unrun in task 3.**
Complete source inspection found wrong-wallet, nonexistent-ID and rollback
assertions in the permitted fork files, including supply/custody checks. Test
definitions alone do not prove execution. Producer supplies no source-negative.log
or source-observations.json; both existence probes returned false.
Existing historical results were inspected without rerunning unchanged full
suites. No current real-source suite result is claimed.

## Real gates and unsupported assumptions

Dependency task 2 is explicitly non-confirmed. Required route/facet/unit/receipt
evidence and reserved-ID facts are incomplete. These are actual delivery gates.
No financial dataset or no-exposure finding was invented.

Missing warm caches and the earlier bootstrap layout failure concern executable
compilation; they do not make read-only archive/document inspection technically
impossible. The producer's statement that no source inspection could proceed is
broader than the evidence establishes. This verifier performed bounded read-only
inspection, but did not repair task 2 or complete task 3 on its behalf.

## Unrun checks, changes and cleanup

No Forge build/test, strict helper typecheck, fixture inventory invocation or
RPC was run. The required wrong-hash inventory-helper rejection and complete
real-source negative execution remain unverified. Task-2 fixture/typecheck
reports were read as reports, not relabeled as independent task-3 executions.
The outward node_modules symlink was inspected with readlink only; no target
code was loaded. No outward dependency link was followed.

Only this report and the final task-3-verdict.json are verifier writes.
No temporary files, fixture directories, caches or background processes were
created, so cleanup required no deletion. Remaining risk is incomplete source,
custody and conservation authentication, not an established contract exploit.
No implementation completion or dependent-task approval is granted.

Final preservation observation: all five scoped source/document hashes and all
three producer/gate receipt hashes above stayed unchanged. The recorder changed
concurrently from SHA-256
`8192d15ff2aa039ea4bb306393205ed3e846270c482abcfb0f46c753e7353ac7`
to `a5e7d7f84785066a2d42685aa2893c43e8fc84287b984b9067d71393df4581b9`.
The recorder inspection and missing-mode assessment above apply to the first
hash only. The new recorder was not reviewed or executed; it may address that
specific deficiency. This does not change the non-confirmed task-2 receipt or
the blocked task-3 receipt, null source hashes and absent task-3 execution
evidence. Task-2 re-verification belongs to its owner. No concurrent change was
reverted, and no claim of recorder byte preservation is made.
