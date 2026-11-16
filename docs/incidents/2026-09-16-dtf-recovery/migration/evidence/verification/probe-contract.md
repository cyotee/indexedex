# Independent verification probe contract

All commands run with cwd `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`.
Owned parent runtime root:
`/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/verification.30kbMI`.
Each invocation records its literal argv, environment path values, expected binary
observable and start time in its `.command.json` before the subprocess starts.
Its stdout/stderr and actual exit status are retained separately, including failure.
No public RPC mutation, producer edit, product compile, or allocation is authorized.

## Original invocations

For weighted, earlier-cp and other-sources:
`/opt/homebrew/bin/bun <absolute scripts/recovery/dtf-migration/phase01/LANE/probe.mjs> --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_alchemy --local-fork --output <absolute verification/LANE-original>`.

Expected capability PASS requires the producer's documented token/status AND
actual mined custody/rollback receipts at an authenticated pin; an exit alone
cannot close E1/E2. Output confinement failure is a harness failure, not source
incompatibility. Preserve that failure and do not change the producer.

Scope clarification from the executor's caller: E1 is judged on usable actual
source primitives and concrete caller/authority limitations. Absence of the
tasks 3-6 Migration contract and new-bond integration is not a task-1 blocker.
An ordinary NFT transferFrom primitive may establish source custody feasibility
with an EOA fixture; receiver integration remains later work. TokenStaking's
claimant-only reassignment requires separate analysis of whether the future
Migration caller can acquire that claimant's right in the same transaction.
Disabled harvest state, optional source-service failures and expected future
C0/allocation inputs are not automatically requirement incompatibilities.

Provenance:
`/opt/homebrew/bin/bun <absolute scripts/recovery/dtf-migration/phase01/provenance/reconcile.mjs> --input <absolute incident directory> --output <absolute verification/reconciliation.json>`.
Binary observable: exit 0, parseable output, raw integer results equal independent
recomputation. A second run must be byte-identical.

Attribution's original has no output parameter and hardcodes producer writes.
Invoke it with the verification TMPDIR and `--output <absolute verification/witness-original>`.
Its early runtime-root assertion must reject before any producer write. This
tests that it cannot perform the requested isolated rerun; it is not a fork run.

## Path-only executable copies

Copies under `verification/runners/` may change only worktree resolution,
evidence-output confinement, and owned-runtime-root acceptance/allocation.
Keep all RPC methods, addresses, arithmetic, assertions, transaction code, source
checks and success criteria unchanged. Record original/copy hashes and exact
replacement pairs. These are explicitly instrumented replays, not unchanged
producer invocations. Weighted and attribution PASS tokens are capabilities or a
counterexample; never E1/E2 completion.

Run network producers sequentially to avoid adding concurrent provider load.
The attribution witness must reproduce equal final token observations and unequal
credits 1666/2334 versus 1400/2600, six mined transfers, restored initial state,
and a closed owned endpoint. No deployed activation or migration verifier exists
in this witness: postactivation validity is an information-boundary argument,
not an integrated activation test.

## Independent and negative checks

Independent BigInt recomputation must reproduce original weighted contribution
joins, earlier direct/routed inputs, all historical diagnostic sums, remaining
principal, and rounding/duplication vectors without importing producer functions.
Reject malformed float, leading zero, exponent, invalid CSV and negative unsigned
quantities; distinguish blank from zero. A stale preexisting success file must
not be interpreted as a new successful run after failure. Test whether producer
behavior actually prevents that confusion and retain the outcome.

Capture the dirty Git status and hashes of tracked files, incident inputs,
producer scripts and evidence before execution. Final comparison must show no
outside-boundary content change by this verifier. Cleanup independently checks
each recorded child PID, TCP port and owned directory; a generic fetch exception
alone is not proof of port closure.

## Explicit transport retries

The first other-source and witness copies returned HTTP 429. Their logs and
results remain unchanged. A subsequent invocation may preload
`meter-public-fetch.mjs`: public JSON-RPC POST requests receive reserved slots
1,200 ms apart; local requests are unchanged. This is provider throughput
metering, not a receipt/readiness sleep or simulated success. No response,
method, block or assertion is changed. The metered other-source copy also sets
Anvil's native compute-unit limit to 10. These are transport-adapted replays,
explicitly distinct from path-only and unchanged producer runs.
