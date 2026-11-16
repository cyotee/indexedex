# Preserved implementation attempts

The first artifact-first build used a malformed shell exit expression after
the build pipeline. Forge itself reported no changed files and completed its
normal warnings, but the wrapper exited 1. `build.log` is retained; that
wrapper is not a passing gate. The subsequent artifact-first specifications
and forks used `set -o pipefail` and completed with exit 0, including their
own required build steps. No compiler process was killed or artifact removed.

An attempted independent fork-proof child was rejected by the session's
nesting limit before starting. All implementation and verification work was
performed in this session; no child result is claimed.

JSON diagnostics are unavailable because Biome is not installed. Some fresh
TypeScript diagnostics timed out; strict command-line typechecks are retained
separately. No dependency or configuration was installed or changed.

The first fresh cumulative18573 attempt stopped at `008-prepare.log`, after
real full/split source claims (including a genuine zero-output slice), genuine
environment deployment and funding/capture. The census query mistakenly used
the snapshot's EVM `block.number` as an RPC block height. The retained Anvil
log shows `fromBlock: 0x19257be`; the authentic snapshot receipt is at RPC
`0x67e5e2a`. That request crossed into historical upstream logs and failed
the unchanged provider's block-range restriction. No provider change was made.

The fix binds the certificate to the actual snapshot-capture transaction,
canonical RPC block and block hash, authenticates its matching event, and
starts the complete SY census at that receipt's real RPC height. The original
failed run, raw observer and cleanup remain under `runtime-01`/`rpc-01.ndjson`.
Its node PID3428 exited and its checkpoint was removed. It is not a passing
integration, and its actual source preparations are not operational awards.

The second fresh run and its stopped raw audit completed successfully for
the valid input/lifecycle path. Before final sealing, a read-only reproduction
found an additional rejection gap: a caller could strip `claimedOrigin` and
point at its nested original tuple. `downgrade-before.json` records actual
acceptance through both provenance and payload validation without RPC or
signing. The correction reconciles claimed-origin classification across every
referenced reviewed JSON document, including nested and copied tuples.
The same reproduction and the existing regression test now require rejection.
`runtime-02`, `rpc-02.ndjson`, `audit-01.json` and the preceding source manifest
remain unchanged historical attempt evidence, not the final source handoff.
The final complete operator invocation and fresh runtime are repeated only
because this source behavior changed; no unchanged raw-pull case is replayed.

The first owned claimed-economics probe typecheck exposed inference errors
in three local variables. Explicit concrete types corrected the probe; no
suppression, production fix or transaction replay was used for that typecheck.
