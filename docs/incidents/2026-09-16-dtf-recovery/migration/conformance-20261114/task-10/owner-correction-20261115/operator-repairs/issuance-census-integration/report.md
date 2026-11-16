# Issuance and empty-census combined QA

The assigned affected combined checks passed: 305 tests across 21 files, both
exact strict TypeScript commands, and one justified issuance manual replay all
exited 0. This is QA evidence only. Independent combined acceptance remains
pending. No readiness marker, plan closure or task-10 lifecycle completion is
asserted.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Branch: `work/dtf-conformance-20261115-wave-1`.
HEAD: `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`.
Bun: `/opt/homebrew/bin/bun`, `1.4.2+50a8a8387`.
TypeScript: `5.9.2`, invoked through Bun.

## Exact checks

These required commands ran once, in order, with Bash expanding both globs:

```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

| Receipt prefix | Actual result |
| --- | --- |
| `01-tests` | Exit 0; 305 pass, 0 fail, all 21 selected test files observed; 92.31 seconds |
| `02-operator-types` | Exit 0; all 87 operator files selected; empty stdout/stderr |
| `03-helper-types` | Exit 0; both delivered helpers selected; empty stdout/stderr |
| `manual-issuance-current/04-manual` | Exit 0; empty stderr; saved actual facts, synthetic positive and intended negatives verified |

The additional exact manual argv was:

```bash
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/issuance/manual-issuance.ts
```

Every command has NUL-delimited expanded argv, shell-escaped command text, cwd,
UTC start/end, full separate raw stdout/stderr and the real exit. The recorder
uses noclobber output and creates a fresh manual output directory. No old output
was overwritten. `results.json` binds raw receipt hashes and expanded argv.
No narrower overlapping subset, retry or unavailable custom audit API ran.

Monitor `mon_3PQEANVD0SJ92DSV`, session `bash_1`, delivered all results and
`ISSUANCE_CENSUS_COMPLETE exit=0`, then completed with exit 0. No process remains
pending. Editor notices about missing Bash/Biome servers caused no installation
or clean-LSP claim; the actual strict compiler exits are this gate's diagnostics.

## Issuance replay decision and outcome

The issuance claim and confirmed independent verdict were read and preserved.
The issuance program calls `issuanceContext`, which reaches `loadExecution` and
saved preparation validation through the changed domain module. The retained
issuance ledger pins its state/test inputs and artifacts, but not the complete
prior executed domain implementation. Exact executed-code equivalence could
not be established from those bindings, so the existing manual proof ran once
against this settled tree into the new `manual-issuance-current/` directory.

The new `verifyEmptyCensus` body is not directly called by that prepared issuance
positive. The rerun resolves the unpinned imported-loader provenance limit; it
does not assert that the census branch itself affected issuance. The decision,
executed path and source comparisons are in `retained-manual-bindings.json`.

The replay authenticates saved actual receipt/event facts for transaction
`0xa41931626451a9242220fcb3c253b9275e8d697beb1a7fd860afcc6fd2ebdc68`,
with receipt SHA-256
`1e05a886203d090dfa235589da6a98c5c130b5e00afc7be5d9c636b80eabebd9`.
Its actual ERC721 Transfer and MigrationPositionCreated events agree on token
ID 3 and recipient; the actual creation principal is 736. The generated ERC20
decoder collision still reports BUFFER_OVERRUN as the expected diagnostic.
These saved actual facts exactly match the earlier manual output.

Successful production completion is separately labeled
`new-synthetic-source-bound-context`. Its current domain hash is
`05a5f37dc7c2851134b5a0a9066b1adb8fe73e3c4a89d59785e5bb4589d873b4`.
Its fixture signatures, addresses, quantities and getter replies are synthetic.
It accepts the required generated event shape, rejects all 25 independently
corrupted copies, rejects a status-zero receipt despite complete events, and
rejects a stale principal getter despite a valid receipt.

The script does not supply complete historical getter state or rebind the
original signed domain. Its synthetic positive is not a fresh Anvil transaction.
`manual-issuance-current/result.json` interprets the unchanged raw stdout and
binds it to the before/after code manifests.

## Retained empty-census proof

The exact settled proof is `empty-census/attempt-10-final-manual/` and
`empty-census/manual-qStpyA/`. The recorded command exited 0. Its before/after
domain, test, context and manual-program hashes match the current sources.
The 41 original manifest, deployment receipt, canonical chain, journal and
source bindings remain byte-identical. This manual proof was retained rather
than rerun without an affecting change.

All 28 raw outcomes were inspected: three accepted empty preflights, 22 rejected
single compensation omissions across eleven event kinds at deployment and
seven blocks later, malformed census RPC rejection, stale deployment-header
rejection, and missing required issuance-event ABI rejection.

The exact saved deployment transaction is
`0x4098d83a9911e1173fa3a091c227701fd2ff1488f35aa403b902fc3626e9c258`,
block `108944989`, with 152 receipt logs. The proxy's real mandatory
ThresholdsConfigured log is retained unchanged. The original domain hash stays
`be76538efae814c63f22d9c99fd6878734da1e3b76d135df3b3c7fdf02428289`.
Its pricing and prepared-manifest fields are null.

The transport is synthetic loopback replaying the exact archived deployment
transaction/header/receipt. The omission probes are separately injected
synthetic logs. The raw 136 RPC requests contain no contract call, nonce request
or send. This demonstrates census preflight, not paid owner-bond execution,
activation, a live current-chain census or fresh Anvil proof.

## Freshness and preservation

Both manual programs have 28 reachable local imports; every current hash
matches the applicable current lane records or unchanged previous baseline.
The changed domain imported by the earlier issuance proof is explicitly handled
by the new replay, rather than treating the earlier state-only gate as current.

Before/after manifests cover 113 current source, proof, artifact, compiler,
dependency/configuration and recorder files. None changed during the run, and
the operator file set stayed at 87 files. The older combined gate also differs
in several rehearsal modules, as listed in the source comparisons; their current
bytes are captured and checked here without starting the rehearsal.

All 456 captured existing evidence files, claims, verdicts and immutable
historical inputs remain unchanged. There are 45 successful historical record
checks, including the issuance originals and 41 census bindings, plus 36 matching
source references from the original issuance domain. No historical source,
manifest, receipt, journal or intent was replaced.

Narrow git status and raw binary diff for the four repair-owned paths are
identical before/after; staged diffs are empty. Both narrow tracked
`git diff --check` calls exited 0 with empty output. These checks do not include
untracked tests, which instead have source fingerprints, actual test results
and strict compiler evidence. No huge untracked tree was dumped or cleaned.

## Actual classes and remaining limits

| Trigger | Evidence disposition |
| --- | --- |
| Current input identity | Actual issuance and unset census chain/proxy/purpose/domain identities are recorded separately from the new synthetic issuance context. Original hashes remain exact. |
| Dirty worktree | Narrow tracked state and all captured sources/protected evidence are unchanged; no staging, rollback or unrelated edits. |
| Malformed input | Required child-event corruptions, invalid encoding/count/order, malformed census payload and missing event ABI reject through the intended boundaries. |
| Stale state | Stale principal getter, canonical receipt contradictions and stale deployment header reject. Prior historical/current census and stale-journal tests remain passing. |
| Misleading success | Actual status 1 and standalone decoding are not labeled full historical completion. Status-zero events reject. Synthetic completion and saved actual facts remain distinct. |
| Interruption | Required full tests include mined configure crashes, idempotent resume, invalid recovery and active-journal protections. This is not a new Anvil interruption or power-loss/reorg campaign. |
| Long/timing behavior | One 92.31-second full test run completed naturally. No timeout, polling, duplicate run or retry occurred; no flake-rate claim. |
| Cleanup | All recorder children completed. The issuance fixture closed its provider/server and removed its temp directory. No new dtf-prefixed temp directory remains. |

The producer's neighboring suffix selection in `verifyConfiguration` remains
explicitly unverified. This QA does not reproduce, modify, admit as a failure,
or certify that neighboring path. The independent reviewer owns that assessment;
passing shared tests do not turn the observation into a pass.

The prior unknown checkpoint directories `dtf-prepare-test-6ABTvq` and
`dtf-prepare-test-sSyY0e` remain untouched. No product/test edits, installs,
commits, delegation, Forge, Anvil, public transactions, readiness marker or
plan checkbox changes occurred. Historical recursive third-party module bytes
are not exhaustively pinned; current tool/dependency/configuration fingerprints
are retained. Independent combined acceptance remains a separate decision.
