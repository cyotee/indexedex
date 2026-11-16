# Task 10 operator repairs combined QA

The assigned combined validation passed: 280 tests across 21 files and both
required strict TypeScript commands exited 0. This is QA evidence for the two
operator repairs. Independent verification remains separate, the rehearsal
remains paused, and no task-10 or whole-plan acceptance is claimed.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Branch: `work/dtf-conformance-20261115-wave-1`.
HEAD: `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`.
Bun: `/opt/homebrew/bin/bun`, `1.4.2+50a8a8387`.
TypeScript: `5.9.2`, invoked through Bun. Platform/version probes have their own
raw stdout, stderr, exact argv, cwd and real exit sidecars.

## Commands and results

This is an affected rerun after task 7, task 16 and the two completed repairs.
Each command below ran once, with Bash expanding the actual globs.

```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

| Receipt prefix | Observed result |
| --- | --- |
| `01-tests` | Exit 0; 280 pass, 0 fail, all 21 selected files observed; 92.23 seconds |
| `02-operator-types` | Exit 0; all 87 operator TS files selected; empty stdout/stderr |
| `03-helper-types` | Exit 0; both delivered helpers selected; empty stdout/stderr |

`run-checks.sh` retains NUL-delimited expanded argv, shell-escaped command text,
cwd, UTC start/end, separate full stdout/stderr and actual child exit for every
command. `results.json` contains the expanded required argv and raw receipt
hashes. No overlapping narrower green subset, custom audit API or retry ran.
The earlier unavailable audit APIs are historical lane limitations, not failures
of these required compiler commands.

Monitor `mon_1S046DDKK7RF0R8F`, session `bash_1`, delivered completion for all
commands and `REPAIR_QA_COMPLETE exit=0`; the watcher exited 0. No child is pending.
The full output includes the new source-bound setter and malformed ABI cases,
seven configure crash/resume cases, seven corrupted-recovery cases, reverted
first-run rejection and synthetic-local enforcement, alongside existing
historical/current census, provenance, custody preparation and portable tests.

## Original history and retained manual channels

The exact admitted claims are `setter-repair-done.json` and
`configure-fault-done.json` under the owner-correction execution directory.
The current task-10 plan paragraph admits these two blocking repairs, preserves
historical signed domains, requires new producer-bound execution and keeps the
rehearsal paused until integration and independent confirmation.

`manual-bindings.json` records inspected manual command/result/source bindings.
Neither manual proof was rerun because no affecting byte change was found.
No new Anvil proof was created.

The four original failed-run files retain their exact recorded SHA-256 values:

| Original file | SHA-256 |
| --- | --- |
| Pricing execution manifest | `399d926f7d61aff65d74e79f11d7ead47e06369eb483c3065aef6ae866c5aa44` |
| Signed journal domain | `d6afa20561144bdd2057e8846b5e76009fdba03bd86083eeb047386aae60db36` |
| Persisted intent | `9117eb335e45c0d323c5dd5cf35ff38706f39717e328d776ef5d74e2b9e0cdca` |
| Canonical-chain receipt record | `c6b1e9c210ccce97c27d1fb051f2b70198af57302b367cc6952416aee8645666` |

All 35 source references in that original manifest still match their bound
hashes and lengths. The original signed domain was not rebound or repaired.

The setter channel is exactly `setter/manual-after.{stdout,stderr,exit}` and the
`manual-after` argv/cwd/raw-file bindings in `setter/after-fix-evidence.json`.
Its exit is 0 and stderr is empty. Raw output distinguishes the saved receipt's
diagnostic generated decode from production acceptance: original unbound
history still rejects with `missing bound pricing event ABI`. The positive is
a new synthetic signed context with a bound generated `pricing-abi`, a different
transaction and its own domain. Twelve independently corrupted receipts reject.
The current generated pricing artifact matches the recorded hash
`bc27f132877882a81b5d89f7ecb2637eb4b04fa685ad42430930e595cd181bbd`.

The configure channel is exactly `configure-fault/attempt-09-manual.log` and
`configure-fault/manual-attempt-ncqQ9Y/`. The parent command exited 0. Each
positive's actual child sequence is code 137 / SIGKILL, then two code-0 resumes
with no signal. The raw child logs equal their command records. Interrupted
journals contain an intent and no completed receipt. Both resumes return the
same retained canonical receipt and the exact intent hash. One completion file
is recorded per operation.

Independent configure retains transaction
`0x1234d1495832267b0eed77c28e219f666416d23fd3d441f4324e6aa16d9fa750`;
separate NFT contribution configure retains
`0x520f748d63c492eebf3b5de88798f5e0b5fcb10af477277e64821156ac063cfd`.
Both use nonce 7. Counts remain one send, two initial nonce reads and one
accepted signed object across both resumes. The latter count is not independent
instrumentation of wallet signing calls. The latest book, quote and configuration
are deliberately stale; authenticated receipt-block state still recovers the
original operation without replacing latest state.

Wrong transaction hash, malformed receipt and malformed intent recoveries have
exit 1, no signal and the intended AMBIGUOUS or INPUT error. Unsupported
simulation has exit 1 / DOMAIN before any nonce request or send. Those deliberate
negative outcomes are expected proof results, not failed required commands.
All these receipt facts come from synthetic loopback transport driving the real
production CLI, signing, subscription and journal; they are not EVM lifecycle
or fresh Anvil evidence.

## Source freshness and workspace boundaries

Both manual programs have 28 reachable local imports; all match the recorded
repair hashes or retained unchanged task-7/task-16 source baselines. No import
is missing. The later mtime on `execution-state.ts` comes from a temporary lane
guard mutation restored byte-for-byte; its digest matches both manual records.

The CLI has 62 local imports. Fifty-seven match the available combined source
records. Four separate rehearsal modules differ from the older task-7 baseline,
and `rehearsal-nft-contributions.ts` is new relative to that baseline. Their
mtimes precede both lane manual proofs. No complete lane-era digest exists in
the admitted proof census for those five dormant CLI imports; this is not
presented as proof that they changed after the lanes. Configure/resume dispatch
calls execution rather than rehearsal. The current full tests and strict
compiler checks cover the integrated tree.

Before/after manifests cover 107 current source, proof, artifact, compiler,
dependency/configuration and recorder files. None changed during this run;
the operator file set also had no additions or removals. A separate 252-file
protected inventory, including original failed-run records, retained lane
evidence and prior task-7 integration evidence, has no changed bytes.

Git checks were restricted to the seven repair-owned paths. Before/after
tracked status and raw binary diff are identical; staged diffs are empty.
Both narrow `git diff --check` calls exit 0 with empty output. These diagnostics
do not cover untracked files; current source hashes, compiler checks and actual
tests cover the two untracked domain/state test files. No huge untracked tree
was dumped. No unrelated dirty work was edited or reverted.

## Actual failure classes and cleanup

| Trigger | Disposition |
| --- | --- |
| Stale state | Unbound original setter history still rejects; positive acceptance requires the new bound context. Mined configure recovery authenticates original receipt state despite stale latest values. |
| Dirty worktree | Narrow tracked diagnostics remain identical; captured sources and protected evidence remain unchanged. No broad cleanup or staging occurred. |
| Misleading success | Receipt status and standalone decode do not admit unbound history. Raw process signals, intent hashes, canonical receipts, counts and intended errors were inspected rather than accepting a success marker. |
| Interruption | Actual CLI child SIGKILL after observed mining and before completion is retained in both positive manual cases and exercised again through the required full suite. Resume is idempotent. No power-loss, reorg or real-chain campaign is inferred. |
| Long commands | The single 92.23-second test run completed naturally under its requested 15-second per-test budget. No timeout, polling, duplicate run or busy-process kill occurred. |
| Timing/flakes | No test failed or required retry. A single affected run does not establish a flake rate. |
| Malformed inputs | Setter corruption, invalid ABI binding, malformed receipt/intent and wrong canonical facts reject through their intended boundaries. |

`cleanup.json` records natural completion with no remaining QA process or new
dtf-prefixed temp directory. The prior `dtf-prepare-test-6ABTvq` and
`dtf-prepare-test-sSyY0e` checkpoint directories remain untouched. No owned
resource required deletion. No Anvil start/restart, Forge, install, delegation,
commit, product/test edit, public action or parent readiness write occurred.

The only executable QA artifact is a 52-line recorder with one responsibility:
retain actual command receipts. Automatic editor notices about absent Bash and
Biome language servers caused no installation or clean-LSP claim. Full
diagnostics for this gate are the two actual strict compiler exits above.

All assigned required checks passed. Historical recursive third-party module
hashes and the five dormant CLI imports' lane-era digests remain explicit
provenance limits. Independent repair acceptance and the paused real rehearsal
remain outside this QA claim.
